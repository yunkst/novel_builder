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
  final Set<String> _cachedInMemory = <String>{};
  final Set<String> _preloading = <String>{};
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

  /// 标记章节正在预加载
  @override
  void markAsPreloading(String chapterUrl) {
    _preloading.add(chapterUrl);
  }

  /// 检查章节是否正在预加载
  @override
  bool isPreloading(String chapterUrl) {
    return _preloading.contains(chapterUrl);
  }

  /// 清理内存状态
  @override
  void clearMemoryState() {
    _cachedInMemory.clear();
    _preloading.clear();
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
      _preloading.remove(chapter.url);

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
    return await db.update(
      'chapter_cache',
      {
        'content': content,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
  }

  /// 删除章节缓存
  @override
  Future<int> deleteChapterCache(String chapterUrl) async {
    final db = await database;
    return await db.delete(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
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
  @override
  Future<int> deleteCachedChapters(String novelUrl) async {
    final db = await database;
    return await db.delete(
      'chapter_cache',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );
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
  @override
  Future<void> cacheNovelChapters(
      String novelUrl, List<Chapter> chapters) async {
    final db = await database;

    for (var i = 0; i < chapters.length; i++) {
      await db.rawInsert('''
        INSERT INTO novel_chapters (novelUrl, chapterUrl, title, chapterIndex, isUserInserted)
        VALUES (?, ?, ?, ?, 0)
        ON CONFLICT(novelUrl, chapterUrl) DO UPDATE SET
          title = excluded.title,
          chapterIndex = excluded.chapterIndex
      ''', [novelUrl, chapters[i].url, chapters[i].title, i]);
    }

    await _reorderChapters(novelUrl);
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

    await db.insert(
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

    await db.insert(
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

    return chapterIndex;
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
  }

  void _addCachedInMemory(String chapterUrl) {
    if (_cachedInMemory.length >= _maxMemoryCacheSize) {
      _cachedInMemory.clear();
      LoggerService.instance.i(
        '内存缓存已满，已清空 ($_maxMemoryCacheSize条)',
        category: LogCategory.cache,
        tags: ['memory', 'cleanup'],
      );
    }
    _cachedInMemory.add(chapterUrl);
  }

  /// 标记章节为已读
  ///
  /// [novelUrl] 小说URL
  /// [chapterUrl] 章节URL
  @override
  Future<void> markChapterAsRead(String novelUrl, String chapterUrl) async {
    final db = await database;

    await db.update(
      'novel_chapters',
      {'readAt': DateTime.now().millisecondsSinceEpoch},
      where: 'novelUrl = ? AND chapterUrl = ?',
      whereArgs: [novelUrl, chapterUrl],
    );
  }

  /// 获取已缓存的章节数量
  ///
  /// [novelUrl] 小说URL
  /// 返回已缓存的章节数量
  @override
  Future<int> getCachedChaptersCount(String novelUrl) async {
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
            chapterIndex: row['chapterIndex'] as int,
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
}
