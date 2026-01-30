import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../test_bootstrap.dart';
import '../utils/test_data_factory.dart';

/// 数据库测试基类
///
/// 提供数据库测试的通用初始化和清理逻辑
/// 所有需要使用数据库的测试都应该使用此类
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

  /// 设置测试环境
  ///
  /// 子类可以覆盖此方法添加自定义初始化逻辑
  Future<void> setUp() async {
    // 初始化测试环境
    initDatabaseTests();

    // 创建数据库服务实例
    databaseService = DatabaseService();

    // 清理测试数据
    await cleanTestData();
  }

  /// 清理测试数据
  ///
  /// 在每个测试前调用，确保测试隔离
  Future<void> cleanTestData() async {
    final db = await databaseService.database;

    // 清理所有测试相关的表
    final tables = [
      'bookshelf',
      'bookshelves',
      'novel_bookshelves',
      'chapter_cache',
      'novel_chapters',
      'characters',
      'scene_illustrations',
      'character_relationships',
      'outlines',
      'chat_scenes',
      'reading_chapter_log',
      'chapter_ai_accompaniment',
    ];

    for (final table in tables) {
      try {
        await db.delete(table);
      } catch (e) {
        // 表不存在或其他错误，忽略
        debugPrint('清理表 $table 时出错: $e');
      }
    }
  }

  /// 清理测试环境
  ///
  /// 在测试完成后调用
  Future<void> tearDown() async {
    // 清理所有测试数据
    await cleanTestData();
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
      'url': url,
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
    final chapters = await databaseService.getChapters(novelUrl);

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
    final chapters = await databaseService.getChapters(novelUrl);

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
