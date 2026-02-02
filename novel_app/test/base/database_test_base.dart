import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/models/ai_companion_response.dart';
import 'package:novel_app/models/scene_illustration.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/repositories/character_repository.dart';
import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/repositories/chapter_repository.dart';
import 'package:novel_app/repositories/character_relation_repository.dart';
import 'package:novel_app/repositories/illustration_repository.dart';
import 'package:novel_app/repositories/outline_repository.dart';
import 'package:novel_app/repositories/chat_scene_repository.dart';
import 'package:novel_app/repositories/bookshelf_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../test_bootstrap.dart';
import '../utils/test_data_factory.dart';

/// 数据库测试基类
///
/// 提供数据库测试的通用初始化和清理逻辑
/// 所有需要使用数据库的测试都应该使用此类
///
/// ## 重要修复 (2025-01-30)
/// - 使用独立的内存数据库,避免测试之间的锁定冲突
/// - 每个测试实例都有独立的数据库连接
/// - 清理操作使用事务包装,确保原子性
///
/// 使用示例：
/// ```dart
/// late DatabaseTestBase base;
/// setUp(() async {
///   base = DatabaseTestBase();
///   await base.setUp();
/// });
/// tearDown(() async {
///   await base.tearDown();
/// });
/// ```
class DatabaseTestBase {
  /// 数据库服务实例
  late DatabaseService databaseService;

  /// 测试专用的内存数据库实例
  Database? _testDatabase;

  /// 设置测试环境
  ///
  /// 子类可以覆盖此方法添加自定义初始化逻辑
  Future<void> setUp() async {
    // 初始化测试环境
    initDatabaseTests();

    // 创建独立的内存数据库（关键修复！）
    _testDatabase = await createInMemoryDatabase();

    // 创建数据库服务实例，但我们需要注入测试数据库
    // 由于DatabaseService是单例，我们需要使用测试专用实例
    databaseService = _TestDatabaseService(_testDatabase!);

    // 清理测试数据（确保数据库是干净的）
    await cleanTestData();
  }

  /// 清理测试数据
  ///
  /// 在每个测试前调用，确保测试隔离
  /// 使用事务包装所有删除操作，确保原子性
  Future<void> cleanTestData() async {
    if (_testDatabase == null) return;

    // 使用事务包装所有清理操作（关键修复！）
    await _testDatabase!.transaction((txn) async {
      // 清理所有测试相关的表
      final tables = [
        'bookshelf',
        'chapter_cache',
        'novel_chapters',
        'characters',
        'scene_illustrations',
        'character_relationships',
        'ai_accompaniment_settings',
        'ai_companion_responses',
        'chapter_ai_accompaniment',
      ];

      for (final table in tables) {
        try {
          await txn.delete(table);
        } catch (e) {
          // 表不存在或其他错误，忽略
          debugPrint('清理表 $table 时出错: $e');
        }
      }
    });
  }

  /// 清理测试环境
  ///
  /// 在测试完成后调用
  Future<void> tearDown() async {
    try {
      // 清理所有测试数据
      await cleanTestData();

      // 关闭测试数据库连接（关键修复！）
      await _testDatabase?.close();
      _testDatabase = null;
    } catch (e) {
      debugPrint('清理测试环境时出错: $e');
    }
  }

  /// 创建测试小说数据
  Future<Map<String, dynamic>> createTestNovel({
    String url = 'https://test.com/novel/1',
    String title = '测试小说',
    String author = '测试作者',
  }) async {
    final novel = Novel(
      url: url,
      title: title,
      author: author,
      coverUrl: null,
      description: '测试描述',
      backgroundSetting: '测试背景',
    );

    await databaseService.addToBookshelf(novel);

    return novel.toMap();
  }

  /// 创建测试章节数据
  Future<Map<String, dynamic>> createTestChapter({
    required String novelUrl,
    String url = 'https://test.com/chapter/1',
    String title = '第一章',
    int chapterIndex = 0,
    bool isUserInserted = false,
  }) async {
    final chapter = {
      'novelUrl': novelUrl,
      'chapterUrl': url, // 修复：使用chapterUrl而不是url
      'title': title,
      'chapterIndex': chapterIndex,
      'isUserInserted': isUserInserted ? 1 : 0,
    };

    await databaseService.database.then((db) async {
      await db.insert('novel_chapters', chapter);
    });

    return chapter;
  }

  /// ========== 新增功能 ==========

  /// 验证表中数据行数
  ///
  /// 使用示例：
  /// ```dart
  /// await expectTableCount('bookshelf', 1);
  /// ```
  Future<void> expectTableCount(String table, int expected) async {
    final db = await databaseService.database;

    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $table',
      );

      final count = result.first['count'] as int;
      if (count != expected) {
        throw TestFailure(
          '表 $table 的行数不符合预期\n'
          '期望: $expected\n'
          '实际: $count',
        );
      }

      debugPrint('✅ 表 $table 行数验证通过: $count');
    } catch (e) {
      if (e is TestFailure) {
        rethrow;
      }
      throw TestFailure('验证表 $table 行数时出错: $e');
    }
  }

  /// 创建并添加小说到书架
  ///
  /// 使用 TestDataFactory 创建小说并添加到数据库
  Future<Novel> createAndAddNovel({
    String url = 'https://test.com/novel/1',
    String title = '测试小说',
    String author = '测试作者',
  }) async {
    return TestDataFactory.createAndAddNovel(
      dbService: databaseService,
      url: url,
      title: title,
      author: author,
    );
  }

  /// 创建并缓存章节数据
  ///
  /// 使用 TestDataFactory 创建章节并缓存内容
  Future<List<Chapter>> createAndCacheChapters({
    required String novelUrl,
    int count = 10,
    String baseUrl = 'https://test.com/chapter/',
  }) async {
    return TestDataFactory.createAndCacheChapters(
      dbService: databaseService,
      novelUrl: novelUrl,
      count: count,
      baseUrl: baseUrl,
    );
  }

  /// 创建并保存角色
  ///
  /// 使用 TestDataFactory 创建角色并保存到数据库
  Future<Character> createAndSaveCharacter({
    required String novelUrl,
    String name = '测试角色',
  }) async {
    return TestDataFactory.createAndSaveCharacter(
      dbService: databaseService,
      novelUrl: novelUrl,
      name: name,
    );
  }

  /// 检查表中是否存在指定条件的数据
  ///
  /// 使用示例：
  /// ```dart
  /// final exists = await rowExists(
  ///   'bookshelf',
  ///   where: 'url = ?',
  ///   whereArgs: ['test-url'],
  /// );
  /// expect(exists, isTrue);
  /// ```
  Future<bool> rowExists(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await databaseService.database;

    try {
      final result = await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('检查表 $table 数据存在性时出错: $e');
      return false;
    }
  }

  /// ========== 新增辅助方法（用于测试迁移） ==========

  /// 快速验证章节数据
  ///
  /// 使用示例：
  /// ```dart
  /// await expectChapterExists(
  ///   novelUrl: novel.url,
  ///   chapterUrl: 'https://test.com/chapter/1',
  ///   title: '第一章',
  /// );
  /// ```
  Future<void> expectChapterExists({
    required String novelUrl,
    required String chapterUrl,
    required String title,
    int? expectedIndex,
    bool? isUserInserted,
  }) async {
    final chapters = await databaseService.getCachedNovelChapters(novelUrl);

    try {
      final chapter = chapters.firstWhere(
        (c) => c.url.contains(chapterUrl) || c.url == chapterUrl,
      );

      expect(chapter.title, title);

      if (expectedIndex != null) {
        expect(chapter.chapterIndex, expectedIndex);
      }

      if (isUserInserted != null) {
        expect(chapter.isUserInserted, isUserInserted);
      }

      debugPrint('✅ 章节验证通过: ${chapter.title} (${chapter.url})');
    } catch (e) {
      if (e is TestFailure) {
        rethrow;
      }
      throw TestFailure(
        '章节不存在: $chapterUrl\n'
        '当前章节数量: ${chapters.length}\n'
        '错误: $e',
      );
    }
  }

  /// 验证数据库表为空
  ///
  /// 使用示例：
  /// ```dart
  /// await expectTableEmpty('bookshelf');
  /// ```
  Future<void> expectTableEmpty(String table) async {
    await expectTableCount(table, 0);
  }

  /// 验证表中不存在特定章节
  ///
  /// 使用示例：
  /// ```dart
  /// await expectChapterNotExists(novelUrl: novel.url, chapterUrl: 'deleted-chapter');
  /// ```
  Future<void> expectChapterNotExists({
    required String novelUrl,
    required String chapterUrl,
  }) async {
    final chapters = await databaseService.getCachedNovelChapters(novelUrl);

    final exists = chapters.any(
      (c) => c.url.contains(chapterUrl) || c.url == chapterUrl,
    );

    if (exists) {
      throw TestFailure('章节不应该存在: $chapterUrl');
    }

    debugPrint('✅ 章节已正确删除: $chapterUrl');
  }

  /// 获取章节缓存状态
  ///
  /// 使用示例：
  /// ```dart
  /// final isCached = await isChapterCached('chapter-url');
  /// expect(isCached, isTrue);
  /// ```
  Future<bool> isChapterCached(String chapterUrl) async {
    return await databaseService.isChapterCached(chapterUrl);
  }

  /// 批量检查章节缓存状态
  ///
  /// 使用示例：
  /// ```dart
  /// final statusMap = await getChaptersCacheStatus(['url1', 'url2']);
  /// expect(statusMap['url1'], isTrue);
  /// ```
  Future<Map<String, bool>> getChaptersCacheStatus(List<String> urls) async {
    return await databaseService.getChaptersCacheStatus(urls);
  }

  /// 创建角色关系
  ///
  /// 使用示例：
  /// ```dart
  /// final relationship = await createRelationship(
  ///   sourceId: character1.id!,
  ///   targetId: character2.id!,
  ///   relationshipType: '朋友',
  ///   description: '他们是好朋友',
  /// );
  /// ```
  Future<CharacterRelationship> createRelationship({
    required int sourceId,
    required int targetId,
    required String relationshipType,
    String? description,
  }) async {
    final relationship = CharacterRelationship(
      sourceCharacterId: sourceId,
      targetCharacterId: targetId,
      relationshipType: relationshipType,
      description: description,
    );

    final db = await databaseService.database;
    final id = await db.insert('character_relationships', relationship.toMap());

    return CharacterRelationship(
      id: id,
      sourceCharacterId: sourceId,
      targetCharacterId: targetId,
      relationshipType: relationshipType,
      description: description,
      createdAt: relationship.createdAt,
    );
  }
}

/// 简单的测试小说模型（仅用于测试）
class TestNovel {
  final String url;
  final String title;
  final String author;
  final String? coverUrl;
  final String? description;
  final String? backgroundSetting;

  TestNovel({
    required this.url,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description,
    this.backgroundSetting,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'description': description,
      'backgroundSetting': backgroundSetting,
    };
  }

  static TestNovel fromMap(Map<String, dynamic> map) {
    return TestNovel(
      url: map['url'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      coverUrl: map['coverUrl'] as String?,
      description: map['description'] as String?,
      backgroundSetting: map['backgroundSetting'] as String?,
    );
  }
}

/// 测试专用的DatabaseService包装类
///
/// 由于DatabaseService是单例，无法在测试中创建多个独立实例
/// 这个包装类接受一个独立的Database实例，实现测试隔离
///
/// ## 重要说明
/// - 仅用于测试环境
/// - 每个测试实例都有独立的数据库连接
/// - 避免SQLite锁定问题
/// - 修复：添加Repository实例初始化，确保CharacterRepository等Repository能正确获取数据库实例
class _TestDatabaseService implements DatabaseService {
  final Database _database;

  // Repository实例
  late final CharacterRepository characterRepository;
  late final NovelRepository novelRepository;
  late final ChapterRepository chapterRepository;
  late final CharacterRelationRepository characterRelationRepository;
  late final IllustrationRepository illustrationRepository;
  late final OutlineRepository outlineRepository;
  late final ChatSceneRepository chatSceneRepository;
  late final BookshelfRepository bookshelfRepository;

  _TestDatabaseService(this._database) {
    // 初始化所有Repository实例
    _initRepositories();
    // 设置共享数据库实例
    _shareDatabaseWithRepositories();
  }

  /// 初始化所有Repository实例
  void _initRepositories() {
    characterRepository = CharacterRepository();
    novelRepository = NovelRepository();
    chapterRepository = ChapterRepository();
    characterRelationRepository = CharacterRelationRepository();
    illustrationRepository = IllustrationRepository();
    outlineRepository = OutlineRepository();
    chatSceneRepository = ChatSceneRepository();
    bookshelfRepository = BookshelfRepository();
  }

  /// 共享数据库实例给所有Repository
  void _shareDatabaseWithRepositories() {
    characterRepository.setSharedDatabase(_database);
    novelRepository.setSharedDatabase(_database);
    chapterRepository.setSharedDatabase(_database);
    characterRelationRepository.setSharedDatabase(_database);
    illustrationRepository.setSharedDatabase(_database);
    outlineRepository.setSharedDatabase(_database);
    chatSceneRepository.setSharedDatabase(_database);
    bookshelfRepository.setSharedDatabase(_database);
  }

  @override
  Future<Database> get database async => _database;

  // 注意：这里需要实现DatabaseService的所有公共方法
  // 为了简化，我们先实现最常用的几个方法
  // 如果测试需要其他方法，可以逐步添加

  @override
  Future<int> addToBookshelf(Novel novel) async {
    final db = await database;
    final map = novel.toMap();

    // 移除isInBookshelf字段（测试数据库表中没有此字段）
    map.remove('isInBookshelf');

    map['addedAt'] = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('bookshelf', map, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  @override
  Future<List<Novel>> getBookshelf() async {
    final db = await database;
    final result = await db.query('bookshelf');
    return result.map((map) => Novel.fromMap(map)).toList();
  }

  @override
  Future<List<Novel>> getNovels() async {
    // novels 视图与 bookshelf 表数据一致
    return await getBookshelf();
  }

  @override
  Future<String?> getBackgroundSetting(String novelUrl) async {
    final db = await database;
    final result = await db.query(
      'bookshelf',
      columns: ['backgroundSetting'],
      where: 'url = ?',
      whereArgs: [novelUrl],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['backgroundSetting'] as String?;
  }

  @override
  Future<int> appendBackgroundSetting(String novelUrl, String newBackground) async {
    // 忽略空内容或纯空白字符
    if (newBackground.trim().isEmpty) {
      return 0;
    }

    final db = await database;

    // 获取当前背景设定
    final currentBackground = await getBackgroundSetting(novelUrl);

    // 如果小说不存在,返回0
    if (currentBackground == null) {
      final result = await db.query(
        'bookshelf',
        where: 'url = ?',
        whereArgs: [novelUrl],
        limit: 1,
      );
      if (result.isEmpty) return 0;
    }

    // 追加背景设定
    final updatedBackground = currentBackground == null || currentBackground.isEmpty
        ? newBackground
        : '$currentBackground\n\n$newBackground';

    final count = await db.update(
      'bookshelf',
      {'backgroundSetting': updatedBackground},
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
    return count;
  }

  @override
  Future<bool> isInBookshelf(String novelUrl) async {
    final db = await database;
    final result = await db.query(
      'bookshelf',
      where: 'url = ?',
      whereArgs: [novelUrl],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  @override
  Future<int> removeFromBookshelf(String novelUrl) async {
    final db = await database;
    final count = await db.delete(
      'bookshelf',
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
    return count;
  }

  @override
  Future<List<Chapter>> getCachedNovelChapters(String novelUrl) async {
    final db = await database;
    final result = await db.query(
      'novel_chapters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    // 需要将数据库的 chapterUrl 字段映射到 Chapter 的 url 字段
    return result.map((map) {
      // 创建一个新的 map,将 chapterUrl 映射为 url
      final chapterMap = <String, dynamic>{
        'title': map['title'],
        'url': map['chapterUrl'], // 关键映射
        'content': null,
        'isCached': 0,
        'chapterIndex': map['chapterIndex'],
        'isUserInserted': map['isUserInserted'],
        'readAt': map['readAt'],
        'isAccompanied': map['isAccompanied'] ?? 0,
      };
      return Chapter.fromMap(chapterMap);
    }).toList();
  }

  @override
  Future<int> cacheChapter(
    String novelUrl,
    Chapter chapter,
    String content,
  ) async {
    final db = await database;

    // 先插入章节元数据 (注意：使用chapterUrl字段)
    await db.insert(
      'novel_chapters',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapter.url, // 使用chapterUrl而不是url
        'title': chapter.title,
        'chapterIndex': chapter.chapterIndex,
        'isUserInserted': chapter.isUserInserted ? 1 : 0,
        'isAccompanied': chapter.isAccompanied ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 再缓存章节内容（注意：chapter_cache表没有isUserInserted字段）
    final id = await db.insert(
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
    return id;
  }

  @override
  Future<bool> isChapterCached(String chapterUrl) async {
    final db = await database;
    final result = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  @override
  Future<Map<String, bool>> getChaptersCacheStatus(List<String> urls) async {
    final db = await database;
    final resultMap = <String, bool>{};

    for (final url in urls) {
      final result = await db.query(
        'chapter_cache',
        where: 'chapterUrl = ?',
        whereArgs: [url],
        limit: 1,
      );
      resultMap[url] = result.isNotEmpty;
    }

    return resultMap;
  }

  @override
  Future<Character> saveCharacter(Character character) async {
    final db = await database;
    final id = await db.insert('characters', character.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return character.copyWith(id: id);
  }

  @override
  Future<List<Character>> getCharacters(String novelUrl) async {
    final db = await database;
    final result = await db.query(
      'characters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );
    return result.map((map) => Character.fromMap(map)).toList();
  }

  @override
  Future<int> createCharacter(Character character) async {
    final db = await database;
    return await db.insert('characters', character.toMap());
  }

  @override
  Future<int> updateCharacter(Character character) async {
    final db = await database;
    final count = await db.update(
      'characters',
      character.toMap(),
      where: 'id = ?',
      whereArgs: [character.id],
    );
    return count;
  }

  @override
  Future<List<Character>> getCharactersByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.query(
      'characters',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return result.map((map) => Character.fromMap(map)).toList();
  }

  @override
  Future<List<CharacterRelationship>> getOutgoingRelationships(int characterId) async {
    final db = await database;
    final result = await db.query(
      'character_relationships',
      where: 'source_character_id = ?',
      whereArgs: [characterId],
    );
    return result.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  @override
  Future<List<CharacterRelationship>> getIncomingRelationships(int characterId) async {
    final db = await database;
    final result = await db.query(
      'character_relationships',
      where: 'target_character_id = ?',
      whereArgs: [characterId],
    );
    return result.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  @override
  Future<int> createRelationship(CharacterRelationship relationship) async {
    final db = await database;
    return await db.insert('character_relationships', relationship.toMap());
  }

  @override
  Future<int> updateRelationship(CharacterRelationship relationship) async {
    final db = await database;
    final count = await db.update(
      'character_relationships',
      relationship.toMap(),
      where: 'id = ?',
      whereArgs: [relationship.id],
    );
    return count;
  }

  @override
  Future<int> deleteRelationship(int id) async {
    final db = await database;
    final count = await db.delete(
      'character_relationships',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count;
  }

  @override
  Future<void> close() async {
    await _database.close();
  }

  // 添加AI伴读相关方法
  @override
  Future<bool> isChapterAccompanied(String novelUrl, String chapterUrl) async {
    final db = await database;
    try {
      final result = await db.query(
        'chapter_ai_accompaniment',
        where: 'novelUrl = ? AND chapterUrl = ?',
        whereArgs: [novelUrl, chapterUrl],
        limit: 1,
      );
      return result.isNotEmpty &&
          (result.first['isAccompanied'] as int) == 1;
    } catch (e) {
      // 表不存在时返回false
      return false;
    }
  }

  @override
  Future<void> markChapterAsAccompanied(String novelUrl, String chapterUrl) async {
    final db = await database;
    await db.insert(
      'chapter_ai_accompaniment',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'isAccompanied': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> resetChapterAccompaniedFlag(String novelUrl, String chapterUrl) async {
    final db = await database;
    await db.delete(
      'chapter_ai_accompaniment',
      where: 'novelUrl = ? AND chapterUrl = ?',
      whereArgs: [novelUrl, chapterUrl],
    );
  }

  @override
  Future<int> insertUserChapter(String novelUrl, String title, String content, [int? index]) async {
    final db = await database;

    // 生成用户章节URL
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final chapterUrl = 'local://user_chapter_$timestamp';

    // 插入到 novel_chapters 表
    await db.insert(
      'novel_chapters',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'title': title,
        'chapterIndex': index ?? 0,
        'isUserInserted': 1,
        'insertedAt': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 插入到 chapter_cache 表
    return await db.insert(
      'chapter_cache',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'title': title,
        'content': content,
        'chapterIndex': index ?? 0,
        'cachedAt': timestamp,
        'isUserInserted': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearAllCache() async {
    final db = await database;

    // 清理章节内容缓存
    await db.delete('chapter_cache');

    // 清理章节列表元数据
    await db.delete('novel_chapters');
  }

  @override
  Future<List<Chapter>> getChapters(String novelUrl) async {
    return getCachedNovelChapters(novelUrl);
  }

  @override
  Future<void> updateChaptersOrder(String novelUrl, List<Chapter> chapters) async {
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
  }

  @override
  Future<void> cacheNovelChapters(String novelUrl, List<Chapter> chapters) async {
    final db = await database;

    // 批量插入章节列表
    final batch = db.batch();
    for (var i = 0; i < chapters.length; i++) {
      batch.insert(
        'novel_chapters',
        {
          'novelUrl': novelUrl,
          'chapterUrl': chapters[i].url,
          'title': chapters[i].title,
          'chapterIndex': chapters[i].chapterIndex ?? i,
          'isUserInserted': chapters[i].isUserInserted ? 1 : 0,
          'isAccompanied': chapters[i].isAccompanied ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

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

  @override
  Future<void> deleteUserChapter(String chapterUrl) async {
    await deleteCustomChapter(chapterUrl);
  }

  @override
  Future<int> updateBackgroundSetting(String novelUrl, String? backgroundSetting) async {
    final db = await database;
    final count = await db.update(
      'bookshelf',
      {'backgroundSetting': backgroundSetting},
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
    return count;
  }

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

  @override
  Future<int> updateLastReadChapter(String novelUrl, int chapterIndex) async {
    final db = await database;
    return await db.update(
      'bookshelf',
      {
        'lastReadChapter': chapterIndex,
        'lastReadTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  @override
  Future<int> getLastReadChapter(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['lastReadChapter'],
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['lastReadChapter'] as int? ?? 0;
    }
    return 0;
  }

  @override
  Future<int> batchUpdateOrInsertCharacters(
    String novelUrl,
    List<AICompanionRole> aiRoles,
  ) async {
    if (aiRoles.isEmpty) {
      return 0;
    }

    int successCount = 0;

    for (final aiRole in aiRoles) {
      try {
        // 查找是否已存在同名角色
        final existingCharacters = await getCharacters(novelUrl);
        final existingCharacter = existingCharacters
            .where((c) => c.name == aiRole.name)
            .firstOrNull;

        if (existingCharacter != null) {
          // 更新现有角色
          final updatedCharacter = existingCharacter.copyWith(
            gender: (aiRole.gender != null && aiRole.gender!.isNotEmpty)
                ? aiRole.gender
                : null,
            age: aiRole.age,
            occupation: (aiRole.occupation != null && aiRole.occupation!.isNotEmpty)
                ? aiRole.occupation
                : null,
            personality: (aiRole.personality != null && aiRole.personality!.isNotEmpty)
                ? aiRole.personality
                : null,
            bodyType: (aiRole.bodyType != null && aiRole.bodyType!.isNotEmpty)
                ? aiRole.bodyType
                : null,
            clothingStyle: (aiRole.clothingStyle != null && aiRole.clothingStyle!.isNotEmpty)
                ? aiRole.clothingStyle
                : null,
            appearanceFeatures: (aiRole.appearanceFeatures != null &&
                    aiRole.appearanceFeatures!.isNotEmpty)
                ? aiRole.appearanceFeatures
                : null,
            backgroundStory: (aiRole.backgroundStory != null &&
                    aiRole.backgroundStory!.isNotEmpty)
                ? aiRole.backgroundStory
                : null,
            updatedAt: DateTime.now(),
          );

          await updateCharacter(updatedCharacter);
          successCount++;
        } else {
          // 创建新角色
          final newCharacter = Character(
            novelUrl: novelUrl,
            name: aiRole.name,
            gender: (aiRole.gender != null && aiRole.gender!.isNotEmpty)
                ? aiRole.gender
                : null,
            age: aiRole.age,
            occupation: (aiRole.occupation != null && aiRole.occupation!.isNotEmpty)
                ? aiRole.occupation
                : null,
            personality: (aiRole.personality != null && aiRole.personality!.isNotEmpty)
                ? aiRole.personality
                : null,
            bodyType: (aiRole.bodyType != null && aiRole.bodyType!.isNotEmpty)
                ? aiRole.bodyType
                : null,
            clothingStyle: (aiRole.clothingStyle != null && aiRole.clothingStyle!.isNotEmpty)
                ? aiRole.clothingStyle
                : null,
            appearanceFeatures: (aiRole.appearanceFeatures != null &&
                    aiRole.appearanceFeatures!.isNotEmpty)
                ? aiRole.appearanceFeatures
                : null,
            backgroundStory: (aiRole.backgroundStory != null &&
                    aiRole.backgroundStory!.isNotEmpty)
                ? aiRole.backgroundStory
                : null,
          );

          await createCharacter(newCharacter);
          successCount++;
        }
      } catch (e) {
        // 忽略错误，继续处理其他角色
        continue;
      }
    }

    return successCount;
  }

  @override
  Future<String?> getCachedChapter(String chapterUrl) async {
    final db = await database;
    final result = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
      limit: 1,
    );

    if (result.isEmpty) return null;

    // 这里可以添加清理逻辑，如果测试需要的话
    return result.first['content'] as String?;
  }

  @override
  Future<String?> getChapterContent(String chapterUrl) async {
    // 与 getCachedChapter 相同
    return await getCachedChapter(chapterUrl);
  }

  @override
  Future<int> updateChapterContent(String chapterUrl, String newContent) async {
    final db = await database;
    return await db.update(
      'chapter_cache',
      {'content': newContent},
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
  }

  @override
  Future<int> insertSceneIllustration(SceneIllustration illustration) async {
    final db = await database;
    return await db.insert('scene_illustrations', illustration.toMap());
  }

  @override
  Future<List<Chapter>> getCachedChapters(String novelUrl) async {
    final db = await database;
    final result = await db.query(
      'chapter_cache',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    // 将数据库结果转换为Chapter对象
    return result.map((map) {
      return Chapter(
        title: map['title'] as String,
        url: map['chapterUrl'] as String,
        content: map['content'] as String?,
        isCached: true,
        chapterIndex: map['chapterIndex'] as int?,
        isUserInserted: (map['isUserInserted'] as int?) == 1,
      );
    }).toList();
  }

  @override
  void clearMemoryState() {
    // 测试环境中不需要内存状态清理
    // 真实的DatabaseService可能需要清理缓存，但测试数据库不需要
  }

  @override
  Future<List<SceneIllustration>> getSceneIllustrationsByChapter(
      String novelUrl, String chapterId) async {
    final db = await database;
    final result = await db.query(
      'scene_illustrations',
      where: 'novel_url = ? AND chapter_id = ?',
      whereArgs: [novelUrl, chapterId],
      orderBy: 'created_at ASC',
    );
    return result.map((map) => SceneIllustration.fromMap(map)).toList();
  }

  @override
  Future<List<SceneIllustration>> getPendingSceneIllustrations() async {
    final db = await database;
    final result = await db.query(
      'scene_illustrations',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return result.map((map) => SceneIllustration.fromMap(map)).toList();
  }

  @override
  Future<int> deleteSceneIllustration(int id) async {
    final db = await database;
    return await db.delete(
      'scene_illustrations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> updateSceneIllustrationStatus(
    int id,
    String status, {
    List<String>? images,
    String? prompts,
  }) async {
    final db = await database;
    final Map<String, dynamic> updateData = {'status': status};
    if (prompts != null) {
      updateData['prompts'] = prompts;
    }
    if (images != null) {
      updateData['images'] = images.join(',');
    }
    return await db.update(
      'scene_illustrations',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<SceneIllustration>> getAllSceneIllustrations() async {
    final db = await database;
    final result = await db.query(
      'scene_illustrations',
      orderBy: 'created_at ASC',
    );
    return result.map((map) => SceneIllustration.fromMap(map)).toList();
  }

  @override
  Future<SceneIllustration?> getSceneIllustrationById(int id) async {
    final db = await database;
    final result = await db.query(
      'scene_illustrations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return SceneIllustration.fromMap(result.first);
  }

  @override
  Future<int> updateSceneIllustration(SceneIllustration illustration) async {
    final db = await database;
    return await db.update(
      'scene_illustrations',
      illustration.toMap(),
      where: 'id = ?',
      whereArgs: [illustration.id],
    );
  }

  // 其他必要方法的存根（根据测试需要添加实现）
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Method ${invocation.memberName} not implemented in test database service',
    );
  }
}
