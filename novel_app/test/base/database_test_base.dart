import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_bootstrap.dart';

/// 数据库测试基类
///
/// 提供数据库测试的通用初始化和清理逻辑
/// 所有需要使用数据库的测试都应该继承此类
///
/// 使用示例：
/// ```dart
/// class MyDatabaseTest extends DatabaseTestBase {
///   @override
///   Future<void> setUp() async {
///     await super.setUp();
///     // 自定义初始化
///   }
/// }
/// ```
abstract class DatabaseTestBase {
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
      'chapter_cache',
      'novel_chapters',
      'characters',
      'scene_illustrations',
      'character_relationships',
      'outlines',
      'chat_scenes',
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
