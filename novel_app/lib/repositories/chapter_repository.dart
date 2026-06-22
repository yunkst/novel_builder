import 'dart:collection';
import 'package:sqflite/sqflite.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';
import '../core/interfaces/repositories/i_chapter_repository.dart';

/// 章节数据仓库
///
/// 负责章节内容缓存、章节列表管理和用户自定义章节的数据库操作
class ChapterRepository extends BaseRepository implements IChapterRepository {
  /// 构造函数 - 通过依赖注入接收数据库连接
  ChapterRepository({required super.dbConnection});

  // 内存状态管理
  // 使用 LinkedHashSet 实现 LRU 淘汰：新访问的条目移到末尾，淘汰时从头部移除
  final LinkedHashSet<String> _cachedInMemory = LinkedHashSet<String>();
  static const int _maxMemoryCacheSize = 1000;

  /// 检查章节是否已缓存（内存优先）
  @override
  Future<bool> isChapterCached(String chapterUrl) async {
    if (_cachedInMemory.contains(chapterUrl)) {
      return true;
    }

    final content = await getCachedChapter(chapterUrl);
    if (content != null && content.isNotEmpty) {
      _addCachedInMemory(chapterUrl);
      return true;
    }

    return false;
  }

  /// 批量检查缓存状态，返回未缓存的章节URL列表
  @override
  Future<List<String>> filterUncachedChapters(List<String> chapterUrls) async {
    final uncached = <String>[];

    for (final url in chapterUrls) {
      if (!await isChapterCached(url)) {
        uncached.add(url);
      }
    }

    return uncached;
  }

  /// 批量查询章节缓存状态
  @override
  Future<Map<String, bool>> getChaptersCacheStatus(
      List<String> chapterUrls) async {
    if (chapterUrls.isEmpty) return {};

    try {
      final db = await database;
      final placeholders = List.filled(chapterUrls.length, '?').join(',');

      final results = await db.rawQuery('''
        SELECT chapterUrl, 1 as isCached
        FROM chapter_cache
        WHERE chapterUrl IN ($placeholders)
      ''', chapterUrls);

      final Map<String, bool> statusMap = {};

      for (final row in results) {
        final chapterUrl = row['chapterUrl'] as String;
        statusMap[chapterUrl] = true;
        _addCachedInMemory(chapterUrl);
      }

      for (final url in chapterUrls) {
        statusMap.putIfAbsent(url, () => false);
      }

      return statusMap;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '批量查询章节缓存状态失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'cache', 'batch_query_failed'],
      );
      return {};
    }
  }

  /// 清理内存状态
  @override
  void clearMemoryState() {
    _cachedInMemory.clear();
    LoggerService.instance.i(
      'ChapterRepository内存状态已清理',
      category: LogCategory.database,
      tags: ['memory', 'cleanup'],
    );
  }

  /// 缓存章节内容
  @override
  Future<int> cacheChapter(
      String novelUrl, Chapter chapter, String content) async {
    try {
      final db = await database;
      final result = await db.insert(
        'chapter_cache',
        {
          'novelUrl': novelUrl,
          'chapterUrl': chapter.url,
          'title': chapter.title,
          'content': content,
          'chapterIndex': chapter.chapterIndex,
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
          'isAccompanied': chapter.isAccompanied ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _addCachedInMemory(chapter.url);

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '缓存章节内容失败: ${chapter.title} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'cache', 'failed'],
      );
      rethrow;
    }
  }

  /// 更新章节内容
  @override
  Future<int> updateChapterContent(String chapterUrl, String content) async {
    final db = await database;
    final affected = await db.update(
      'chapter_cache',
      {
        'content': content,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
    LoggerService.instance.i(
      '更新章节内容: $chapterUrl (len=${content.length})',
      category: LogCategory.database,
      tags: ['chapter', 'update_content'],
    );
    return affected;
  }

  /// 删除章节缓存
  ///
  /// 同时清理内存缓存，防止"幻读"
  @override
  Future<int> deleteChapterCache(String chapterUrl) async {
    _removeFromMemoryCache(chapterUrl);
    final db = await database;
    final affected = await db.delete(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
    LoggerService.instance.d(
      '删除章节缓存: $chapterUrl (affected=$affected)',
      category: LogCategory.database,
      tags: ['chapter', 'cache', 'delete'],
    );
    return affected;
  }

  /// 获取缓存的章节内容
  @override
  Future<String?> getCachedChapter(String chapterUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    if (maps.isNotEmpty) {
      final content = maps.first['content'] as String;

      // 直接清理无效媒体标记（避免循环依赖）
      final cleanedContent = await _cleanInvalidMarkups(content);
      return cleanedContent;
    }
    return null;
  }

  /// 清理章节内容中的无效媒体标记
  ///
  /// [content] 原始章节内容
  /// 返回清理后的内容
  Future<String> _cleanInvalidMarkups(String content) async {
    // 匹配所有媒体标记：插图、视频
    final pattern = RegExp(r'!\[(.*?)\]\{(.*?)\}');
    final matches = pattern.allMatches(content);

    if (matches.isEmpty) {
      return content;
    }

    String cleanedContent = content;
    final db = await database;

    for (final match in matches.toList().reversed) {
      final mediaId = match.group(2)?.trim() ?? '';
      final fullMatch = match.group(0)!;

      // 检查是否为插图标记
      if (fullMatch.startsWith('![')) {
        // 查询插图是否存在
        final result = await db.query(
          'scene_illustrations',
          where: 'id = ?',
          whereArgs: [mediaId],
          limit: 1,
        );

        if (result.isEmpty) {
          // 插图不存在，移除标记
          cleanedContent = cleanedContent.replaceFirst(fullMatch, '');
          LoggerService.instance.w(
            '移除无效插图标记: $mediaId',
            category: LogCategory.cache,
            tags: ['invalid_markup', 'illustration'],
          );
        }
      }
    }

    return cleanedContent;
  }

  /// 获取小说的所有缓存章节
  @override
  Future<List<Chapter>> getCachedChapters(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    return List.generate(maps.length, (i) {
      return Chapter(
        title: maps[i]['title'],
        url: maps[i]['chapterUrl'],
        content: maps[i]['content'],
        isCached: true,
        chapterIndex: maps[i]['chapterIndex'],
      );
    });
  }

  /// 删除小说的所有缓存章节
  ///
  /// 同时清理内存缓存中该小说的所有条目，防止"幻读"
  @override
  Future<int> deleteCachedChapters(String novelUrl) async {
    try {
      // 先查询该小说的所有章节URL，用于清理内存缓存
      final db = await database;
      final urls = await db.query(
        'chapter_cache',
        columns: ['chapterUrl'],
        where: 'novelUrl = ?',
        whereArgs: [novelUrl],
      );
      for (final row in urls) {
        _removeFromMemoryCache(row['chapterUrl'] as String);
      }

      final deleted = await db.delete(
        'chapter_cache',
        where: 'novelUrl = ?',
        whereArgs: [novelUrl],
      );
      LoggerService.instance.i(
        '删除小说所有缓存章节: novelUrl=$novelUrl count=$deleted',
        category: LogCategory.database,
        tags: ['chapter', 'cache', 'delete_all'],
      );
      return deleted;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除小说所有缓存章节失败: novelUrl=$novelUrl - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'cache', 'delete_all', 'failed'],
      );
      rethrow;
    }
  }

  /// 检查章节是否已伴读
  @override
  Future<bool> isChapterAccompanied(String novelUrl, String chapterUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      columns: ['isAccompanied'],
      where: 'novelUrl = ? AND chapterUrl = ?',
      whereArgs: [novelUrl, chapterUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['isAccompanied'] == 1;
    }
    return false;
  }

  /// 标记章节为已伴读
  @override
  Future<void> markChapterAsAccompanied(
      String novelUrl, String chapterUrl) async {
    final db = await database;
    await db.update(
      'chapter_cache',
      {'isAccompanied': 1},
      where: 'novelUrl = ? AND chapterUrl = ?',
      whereArgs: [novelUrl, chapterUrl],
    );
    LoggerService.instance.i(
      '章节已标记为伴读: $chapterUrl',
      category: LogCategory.database,
      tags: ['ai_accompaniment', 'mark'],
    );
  }

  /// 重置章节伴读标记
  @override
  Future<void> resetChapterAccompaniedFlag(
      String novelUrl, String chapterUrl) async {
    final db = await database;
    await db.update(
      'chapter_cache',
      {'isAccompanied': 0},
      where: 'novelUrl = ? AND chapterUrl = ?',
      whereArgs: [novelUrl, chapterUrl],
    );
    LoggerService.instance.i(
      '章节伴读标记已重置: $chapterUrl',
      category: LogCategory.database,
      tags: ['ai_accompaniment', 'reset'],
    );
  }

  /// 缓存小说章节列表
  ///
  /// 批量导入章节列表元数据到 novel_chapters 表。
  /// - 如果章节有 chapterIndex，使用章节自身的索引
  /// - 如果没有，使用列表顺序作为备用索引
  @override
  Future<void> cacheNovelChapters(
      String novelUrl, List<Chapter> chapters) async {
    final db = await database;

    for (var i = 0; i < chapters.length; i++) {
      // 优先使用章节自身的 chapterIndex，否则使用列表顺序
      final chapterIndex = chapters[i].chapterIndex ?? i;
      await db.rawInsert('''
        INSERT INTO novel_chapters (novelUrl, chapterUrl, title, chapterIndex, isUserInserted)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(novelUrl, chapterUrl) DO UPDATE SET
          title = excluded.title,
          chapterIndex = excluded.chapterIndex
      ''', [novelUrl, chapters[i].url, chapters[i].title, chapterIndex, chapters[i].isUserInserted ? 1 : 0]);
    }

    await _reorderChapters(novelUrl);
    LoggerService.instance.i(
      '缓存章节列表: novelUrl=$novelUrl count=${chapters.length}',
      category: LogCategory.database,
      tags: ['chapter', 'cache_list'],
    );
  }

  /// 获取缓存的章节列表
  @override
  Future<List<Chapter>> getCachedNovelChapters(String novelUrl) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        nc.id, nc.novelUrl, nc.chapterUrl, nc.title,
        nc.chapterIndex, nc.isUserInserted, nc.insertedAt,
        nc.readAt,
        cc.content, cc.isAccompanied
      FROM novel_chapters nc
      LEFT JOIN chapter_cache cc ON nc.chapterUrl = cc.chapterUrl
      WHERE nc.novelUrl = ?
      ORDER BY nc.chapterIndex ASC
    ''', [novelUrl]);

    return List.generate(maps.length, (i) {
      return Chapter(
        id: maps[i]['id'] as int?,
        title: maps[i]['title'],
        url: maps[i]['chapterUrl'],
        content: maps[i]['content'] ?? '',
        isCached: maps[i]['content'] != null,
        chapterIndex: maps[i]['chapterIndex'],
        isUserInserted: maps[i]['isUserInserted'] == 1,
        readAt: maps[i]['readAt'] as int?,
        isAccompanied: (maps[i]['isAccompanied'] ?? 0) == 1,
      );
    });
  }

  /// 重新排序章节索引
  Future<void> _reorderChapters(String novelUrl) async {
    final db = await database;
    final chapters = await db.query(
      'novel_chapters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    final batch = db.batch();
    for (var i = 0; i < chapters.length; i++) {
      batch.update(
        'novel_chapters',
        {'chapterIndex': i},
        where: 'id = ?',
        whereArgs: [chapters[i]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 判断是否为本地章节
  static bool isLocalChapter(String chapterUrl) {
    return chapterUrl.startsWith('custom://') ||
        chapterUrl.startsWith('user_chapter_');
  }

  /// 创建用户自定义章节
  ///
  /// 使用事务保证两表写入的原子性，同时更新内存缓存
  @override
  Future<int> createCustomChapter(String novelUrl, String title, String content,
      [int? index]) async {
    final db = await database;

    // 如果提供了index,使用提供的index;否则使用最大索引+1
    late final int chapterIndex;
    if (index != null) {
      chapterIndex = index;
    } else {
      final result = await db.rawQuery(
        'SELECT MAX(chapterIndex) as maxIndex FROM novel_chapters WHERE novelUrl = ?',
        [novelUrl],
      );
      chapterIndex =
          result.isNotEmpty ? (result.first['maxIndex'] as int? ?? 0) : 0;
    }

    final chapterUrl =
        'custom://chapter/${DateTime.now().millisecondsSinceEpoch}';

    late final int ncId;
    try {
      // 使用事务保证两表写入的原子性
      await db.transaction((txn) async {
        ncId = await txn.insert(
          'novel_chapters',
          {
            'novelUrl': novelUrl,
            'chapterUrl': chapterUrl,
            'title': title,
            'chapterIndex': chapterIndex,
            'isUserInserted': 1,
            'insertedAt': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.insert(
          'chapter_cache',
          {
            'novelUrl': novelUrl,
            'chapterUrl': chapterUrl,
            'title': title,
            'content': content,
            'chapterIndex': chapterIndex,
            'cachedAt': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '创建自定义章节失败: novelUrl=$novelUrl title=$title - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'custom', 'create', 'failed'],
      );
      rethrow;
    }

    // 写入成功后同步更新内存缓存
    _addCachedInMemory(chapterUrl);
    LoggerService.instance.i(
      '创建自定义章节: $chapterUrl (index=$chapterIndex)',
      category: LogCategory.database,
      tags: ['chapter', 'custom', 'create', 'success'],
    );

    return ncId;
  }

  /// 将指定小说中 chapterIndex >= [fromIndex] 的所有章节的 chapterIndex +1
  ///
  /// 用于 create_custom_chapter 在指定位置插入新章节时，
  /// 为新章节腾出 chapterIndex 空间，确保 list_chapters 排序正确。
  /// 同时更新 novel_chapters 和 chapter_cache 两张表。
  @override
  Future<void> shiftChapterIndicesFrom(String novelUrl, int fromIndex) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        // novel_chapters 表
        await txn.rawUpdate(
          'UPDATE novel_chapters SET chapterIndex = chapterIndex + 1 '
          'WHERE novelUrl = ? AND chapterIndex >= ?',
          [novelUrl, fromIndex],
        );
        // chapter_cache 表
        await txn.rawUpdate(
          'UPDATE chapter_cache SET chapterIndex = chapterIndex + 1 '
          'WHERE novelUrl = ? AND chapterIndex >= ?',
          [novelUrl, fromIndex],
        );
      });
      LoggerService.instance.i(
        '调整章节索引: novelUrl=$novelUrl fromIndex=$fromIndex',
        category: LogCategory.database,
        tags: ['chapter', 'shift_index', 'success'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '调整章节索引失败: novelUrl=$novelUrl fromIndex=$fromIndex - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'shift_index', 'failed'],
      );
      rethrow;
    }
  }

  /// 更新用户创建的章节内容
  @override
  Future<void> updateCustomChapter(
      String chapterUrl, String title, String content) async {
    final db = await database;

    await db.update(
      'novel_chapters',
      {'title': title},
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    await db.update(
      'chapter_cache',
      {
        'content': content,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    LoggerService.instance.i(
      '更新自定义章节: $chapterUrl',
      category: LogCategory.database,
      tags: ['chapter', 'custom', 'update', 'success'],
    );
  }

  /// 删除用户创建的章节
  @override
  Future<void> deleteCustomChapter(String chapterUrl) async {
    final db = await database;

    await db.delete(
      'novel_chapters',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    await db.delete(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    _removeFromMemoryCache(chapterUrl);
    LoggerService.instance.i(
      '删除自定义章节: $chapterUrl',
      category: LogCategory.database,
      tags: ['chapter', 'custom', 'delete', 'success'],
    );
  }

  /// 将章节URL添加到内存缓存（LRU淘汰策略）
  ///
  /// 使用 LinkedHashSet 实现 LRU：
  /// - 已存在的条目会被移除后重新添加（移到末尾，表示最近访问）
  /// - 超过容量时从头部移除最久未访问的条目
  void _addCachedInMemory(String chapterUrl) {
    // 如果已存在，先移除（LinkedHashSet 不会改变已存在元素的顺序）
    _cachedInMemory.remove(chapterUrl);

    // 超过容量时，淘汰最久未访问的条目（头部）
    if (_cachedInMemory.length >= _maxMemoryCacheSize) {
      final oldest = _cachedInMemory.first;
      _cachedInMemory.remove(oldest);
      LoggerService.instance.d(
        'LRU淘汰内存缓存条目: $oldest (当前${_cachedInMemory.length}条)',
        category: LogCategory.cache,
        tags: ['memory', 'lru-evict'],
      );
    }

    _cachedInMemory.add(chapterUrl);
  }

  /// 从内存缓存中移除章节URL
  void _removeFromMemoryCache(String chapterUrl) {
    _cachedInMemory.remove(chapterUrl);
  }

  /// 标记章节为已读
  ///
  /// [novelUrl] 小说URL
  /// [chapterUrl] 章节URL
  @override
  Future<void> markChapterAsRead(String novelUrl, String chapterUrl) async {
    try {
      final db = await database;

      await db.update(
        'novel_chapters',
        {'readAt': DateTime.now().millisecondsSinceEpoch},
        where: 'novelUrl = ? AND chapterUrl = ?',
        whereArgs: [novelUrl, chapterUrl],
      );
    } catch (e, stackTrace) {
      // 高频操作失败必须可见（每次翻页都触发）
      LoggerService.instance.e(
        '标记已读失败: novelUrl=$novelUrl chapterUrl=$chapterUrl - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'mark_read', 'failed'],
      );
      rethrow;
    }
  }

  /// 获取已缓存的章节数量（实际有内容的章节）
  ///
  /// [novelUrl] 小说URL
  /// 返回 chapter_cache 表中已缓存的章节数量
  @override
  Future<int> getCachedChaptersCount(String novelUrl) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter_cache WHERE novelUrl = ?',
      [novelUrl],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取小说的总章节数
  ///
  /// [novelUrl] 小说URL
  /// 返回 novel_chapters 表中的章节总数
  @override
  Future<int> getTotalChaptersCount(String novelUrl) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM novel_chapters WHERE novelUrl = ?',
      [novelUrl],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 更新章节顺序
  ///
  /// [novelUrl] 小说URL
  /// [chapters] 要排序的章节列表
  ///
  /// 批量更新章节的索引值，用于章节重排序功能
  @override
  Future<void> updateChaptersOrder(
      String novelUrl, List<Chapter> chapters) async {
    final db = await database;

    // 使用事务批量更新章节索引
    await db.transaction((txn) async {
      for (var i = 0; i < chapters.length; i++) {
        await txn.update(
          'novel_chapters',
          {'chapterIndex': i},
          where: 'novelUrl = ? AND chapterUrl = ?',
          whereArgs: [novelUrl, chapters[i].url],
        );
      }
    });

    LoggerService.instance.i(
      '章节顺序更新成功: ${chapters.length}个章节',
      category: LogCategory.cache,
      tags: ['chapter', 'reorder', 'success'],
    );
  }

  /// 搜索缓存章节内容
  ///
  /// [keyword] 搜索关键词
  /// [novelUrl] 可选的小说URL，用于限制搜索范围
  /// 返回匹配的章节搜索结果列表
  @override
  Future<List<ChapterSearchResult>> searchInCachedContent(
    String keyword, {
    String? novelUrl,
  }) async {
    try {
      final db = await database;

      // 构建 SQL 查询
      String sql = '''
        SELECT
          cc.novelUrl,
          b.title as novelTitle,
          b.author as novelAuthor,
          cc.chapterUrl,
          cc.title as chapterTitle,
          cc.chapterIndex,
          cc.content,
          cc.cachedAt
        FROM chapter_cache cc
        LEFT JOIN bookshelf b ON cc.novelUrl = b.url
        WHERE cc.content LIKE ?
      ''';

      List<dynamic> args = ['%$keyword%'];

      // 如果提供了小说URL，添加过滤条件
      if (novelUrl != null && novelUrl.isNotEmpty) {
        sql += ' AND cc.novelUrl = ?';
        args.add(novelUrl);
      }

      sql += ' ORDER BY cc.novelUrl, cc.chapterIndex ASC';

      final results = await db.rawQuery(sql, args);

      // 构建搜索结果列表
      final searchResults = <ChapterSearchResult>[];

      for (final row in results) {
        final content = row['content'] as String;
        final keywordLower = keyword.toLowerCase();
        final contentLower = content.toLowerCase();

        // 查找所有匹配位置
        final matchPositions = <MatchPosition>[];
        int index = 0;

        while (true) {
          final pos = contentLower.indexOf(keywordLower, index);
          if (pos == -1) break;

          matchPositions.add(MatchPosition(
            start: pos,
            end: pos + keyword.length,
            matchedText: content.substring(pos, pos + keyword.length),
          ));

          index = pos + keyword.length;
        }

        if (matchPositions.isNotEmpty) {
          searchResults.add(ChapterSearchResult(
            novelUrl: row['novelUrl'] as String,
            novelTitle: row['novelTitle'] as String? ?? '未知小说',
            novelAuthor: row['novelAuthor'] as String? ?? '未知作者',
            chapterUrl: row['chapterUrl'] as String,
            chapterTitle: row['chapterTitle'] as String,
            chapterIndex: row['chapterIndex'] as int? ?? -1,
            content: content,
            searchKeywords: [keyword],
            matchPositions: matchPositions,
            cachedAt: DateTime.fromMillisecondsSinceEpoch(
              row['cachedAt'] as int,
            ),
          ));
        }
      }

      LoggerService.instance.i(
        '搜索缓存内容完成: 关键词="$keyword", 结果数=${searchResults.length}',
        category: LogCategory.database,
        tags: ['search', 'chapter_content'],
      );

      return searchResults;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '搜索缓存内容失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['search', 'failed'],
      );
      rethrow;
    }
  }

  // ========== ID-based 查询方法（Agent 工具用） ==========

  /// 根据 ID 查询章节（JOIN 两表获取完整信息）
  @override
  Future<Chapter?> getChapterById(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        nc.id, nc.novelUrl, nc.chapterUrl, nc.title,
        nc.chapterIndex, nc.isUserInserted, nc.readAt,
        cc.content, cc.isAccompanied
      FROM novel_chapters nc
      LEFT JOIN chapter_cache cc ON nc.chapterUrl = cc.chapterUrl
      WHERE nc.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return Chapter(
      id: maps.first['id'] as int?,
      title: maps.first['title'] as String,
      url: maps.first['chapterUrl'] as String,
      content: maps.first['content'] as String?,
      isCached: maps.first['content'] != null,
      chapterIndex: maps.first['chapterIndex'] as int?,
      isUserInserted: (maps.first['isUserInserted'] as int?) == 1,
      readAt: maps.first['readAt'] as int?,
      isAccompanied: (maps.first['isAccompanied'] ?? 0) == 1,
    );
  }

  /// 根据 ID 获取章节 URL（内部 ID→URL 解析用）
  @override
  Future<String?> getChapterUrlById(int id) async {
    final db = await database;
    final maps = await db.query(
      'novel_chapters',
      columns: ['chapterUrl'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return maps.first['chapterUrl'] as String;
  }

  /// 根据 ID 检查章节是否存在
  @override
  Future<bool> chapterExistsById(int id) async {
    final db = await database;
    final maps = await db.query(
      'novel_chapters',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }

  /// 根据 ID 更新章节内容（解析 URL 后委托 updateChapterContent）
  @override
  Future<int> updateChapterContentById(int id, String content) async {
    final chapterUrl = await getChapterUrlById(id);
    if (chapterUrl == null) return 0;
    return updateChapterContent(chapterUrl, content);
  }

  /// 根据 URL 获取章节 ID（搜索结果用）
  @override
  Future<int?> getChapterIdByUrl(String url) async {
    final db = await database;
    final maps = await db.query(
      'novel_chapters',
      columns: ['id'],
      where: 'chapterUrl = ?',
      whereArgs: [url],
    );
    if (maps.isEmpty) return null;
    return maps.first['id'] as int;
  }
}
