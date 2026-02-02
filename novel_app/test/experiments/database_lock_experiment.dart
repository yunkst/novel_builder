import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/services/database_service.dart';
import '../base/database_test_base.dart';
import '../test_bootstrap.dart';

/// 数据库隔离方案实验
///
/// 目标: 通过系统性实验找出数据库锁定问题的真正有效解决方案
///
/// 实验设计:
/// - 方案1: 直接使用DatabaseService单例
/// - 方案2: 使用DatabaseTestBase (包装类)
/// - 方案3: 纯内存数据库 (独立创建)
/// - 方案4: 带显式关闭的内存数据库
void main() {
  // 初始化测试环境
  initDatabaseTests();
  sqfliteFfiInit();

  group('数据库隔离方案实验', () {

    // ==================== 方案1: DatabaseService单例 ====================
    group('方案1-DatabaseService单例', () {
      late DatabaseService dbService;

      setUpAll(() {
        dbService = DatabaseService();
      });

      test('测试1-1: 连续运行第1次 - 单例模式', () async {
        // 创建测试数据
        final novel = Novel(
          url: 'https://test1.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '测试小说1',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await dbService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await dbService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '第1次运行: 应该能成功添加小说');

        print('✅ 方案1-测试1成功: 单例模式第1次运行通过');
      });

      test('测试1-2: 连续运行第2次 - 单例模式', () async {
        // 创建测试数据
        final novel = Novel(
          url: 'https://test2.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '测试小说2',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await dbService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await dbService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '第2次运行: 应该能成功添加小说');

        print('✅ 方案1-测试2成功: 单例模式第2次运行通过');
      });

      test('测试1-3: 连续运行第3次 - 单例模式', () async {
        // 创建测试数据
        final novel = Novel(
          url: 'https://test3.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '测试小说3',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await dbService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await dbService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '第3次运行: 应该能成功添加小说');

        print('✅ 方案1-测试3成功: 单例模式第3次运行通过');
      });
    });

    // ==================== 方案2: DatabaseTestBase包装类 ====================
    group('方案2-DatabaseTestBase包装类', () {
      late DatabaseTestBase testBase;

      setUp(() async {
        testBase = DatabaseTestBase();
        await testBase.setUp();
      });

      tearDown(() async {
        await testBase.tearDown();
      });

      test('测试2-1: 连续运行第1次 - 包装类模式', () async {
        // 创建测试数据
        final novel = Novel(
          url: 'https://test-wrapper1.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '包装类测试1',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await testBase.databaseService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await testBase.databaseService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '包装类第1次运行: 应该能成功添加小说');

        print('✅ 方案2-测试1成功: 包装类模式第1次运行通过');
      });

      test('测试2-2: 连续运行第2次 - 包装类模式', () async {
        // 创建测试数据
        final novel = Novel(
          url: 'https://test-wrapper2.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '包装类测试2',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await testBase.databaseService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await testBase.databaseService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '包装类第2次运行: 应该能成功添加小说');

        print('✅ 方案2-测试2成功: 包装类模式第2次运行通过');
      });

      test('测试2-3: 连续运行第3次 - 包装类模式', () async {
        // 创建测试数据
        final novel = Novel(
          url: 'https://test-wrapper3.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '包装类测试3',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await testBase.databaseService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await testBase.databaseService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '包装类第3次运行: 应该能成功添加小说');

        print('✅ 方案2-测试3成功: 包装类模式第3次运行通过');
      });
    });

    // ==================== 方案3: 纯内存数据库 ====================
    group('方案3-纯内存数据库', () {

      test('测试3-1: 连续运行第1次 - 纯内存模式', () async {
        // 创建独立的内存数据库
        final db = await databaseFactoryFfi.openDatabase(
          'in-memory-db-3-1',
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              // 创建bookshelf表
              await db.execute('''
              CREATE TABLE bookshelf (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                url TEXT NOT NULL UNIQUE,
                coverUrl TEXT,
                description TEXT,
                backgroundSetting TEXT,
                addedAt INTEGER NOT NULL
              )
            ''');
            },
          ),
        );

        // 插入数据
        final novel = {
          'title': '纯内存测试1',
          'author': '测试作者',
          'url': 'https://pure-memory1.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          'coverUrl': null,
          'description': '测试描述',
          'backgroundSetting': '测试背景',
          'addedAt': DateTime.now().millisecondsSinceEpoch,
        };

        await db.insert('bookshelf', novel);

        // 验证
        final result = await db.query(
          'bookshelf',
          where: 'url = ?',
          whereArgs: [novel['url']],
        );

        expect(result.isNotEmpty, isTrue, reason: '纯内存第1次: 应该能成功插入数据');

        // 关闭数据库
        await db.close();

        print('✅ 方案3-测试1成功: 纯内存模式第1次运行通过');
      });

      test('测试3-2: 连续运行第2次 - 纯内存模式', () async {
        // 创建独立的内存数据库
        final db = await databaseFactoryFfi.openDatabase(
          'in-memory-db-3-2',
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              // 创建bookshelf表
              await db.execute('''
              CREATE TABLE bookshelf (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                url TEXT NOT NULL UNIQUE,
                coverUrl TEXT,
                description TEXT,
                backgroundSetting TEXT,
                addedAt INTEGER NOT NULL
              )
            ''');
            },
          ),
        );

        // 插入数据
        final novel = {
          'title': '纯内存测试2',
          'author': '测试作者',
          'url': 'https://pure-memory2.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          'coverUrl': null,
          'description': '测试描述',
          'backgroundSetting': '测试背景',
          'addedAt': DateTime.now().millisecondsSinceEpoch,
        };

        await db.insert('bookshelf', novel);

        // 验证
        final result = await db.query(
          'bookshelf',
          where: 'url = ?',
          whereArgs: [novel['url']],
        );

        expect(result.isNotEmpty, isTrue, reason: '纯内存第2次: 应该能成功插入数据');

        // 关闭数据库
        await db.close();

        print('✅ 方案3-测试2成功: 纯内存模式第2次运行通过');
      });

      test('测试3-3: 连续运行第3次 - 纯内存模式', () async {
        // 创建独立的内存数据库
        final db = await databaseFactoryFfi.openDatabase(
          'in-memory-db-3-3',
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              // 创建bookshelf表
              await db.execute('''
              CREATE TABLE bookshelf (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                url TEXT NOT NULL UNIQUE,
                coverUrl TEXT,
                description TEXT,
                backgroundSetting TEXT,
                addedAt INTEGER NOT NULL
              )
            ''');
            },
          ),
        );

        // 插入数据
        final novel = {
          'title': '纯内存测试3',
          'author': '测试作者',
          'url': 'https://pure-memory3.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          'coverUrl': null,
          'description': '测试描述',
          'backgroundSetting': '测试背景',
          'addedAt': DateTime.now().millisecondsSinceEpoch,
        };

        await db.insert('bookshelf', novel);

        // 验证
        final result = await db.query(
          'bookshelf',
          where: 'url = ?',
          whereArgs: [novel['url']],
        );

        expect(result.isNotEmpty, isTrue, reason: '纯内存第3次: 应该能成功插入数据');

        // 关闭数据库
        await db.close();

        print('✅ 方案3-测试3成功: 纯内存模式第3次运行通过');
      });
    });

    // ==================== 方案4: 混合方案 (独立数据库实例) ====================
    group('方案4-独立数据库实例', () {

      test('测试4-1: 连续运行第1次 - 独立实例模式', () async {
        // 创建独立的内存数据库
        final testDatabase = await createInMemoryDatabase();

        // 创建包装服务
        final dbService = _TestDatabaseService(testDatabase);

        // 创建测试数据
        final novel = Novel(
          url: 'https://test-instance1.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '独立实例测试1',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await dbService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await dbService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '独立实例第1次: 应该能成功添加小说');

        // 显式关闭
        await testDatabase.close();

        print('✅ 方案4-测试1成功: 独立实例模式第1次运行通过');
      });

      test('测试4-2: 连续运行第2次 - 独立实例模式', () async {
        // 创建独立的内存数据库
        final testDatabase = await createInMemoryDatabase();

        // 创建包装服务
        final dbService = _TestDatabaseService(testDatabase);

        // 创建测试数据
        final novel = Novel(
          url: 'https://test-instance2.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '独立实例测试2',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await dbService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await dbService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '独立实例第2次: 应该能成功添加小说');

        // 显式关闭
        await testDatabase.close();

        print('✅ 方案4-测试2成功: 独立实例模式第2次运行通过');
      });

      test('测试4-3: 连续运行第3次 - 独立实例模式', () async {
        // 创建独立的内存数据库
        final testDatabase = await createInMemoryDatabase();

        // 创建包装服务
        final dbService = _TestDatabaseService(testDatabase);

        // 创建测试数据
        final novel = Novel(
          url: 'https://test-instance3.com/novel/${DateTime.now().millisecondsSinceEpoch}',
          title: '独立实例测试3',
          author: '测试作者',
          coverUrl: null,
          description: '测试描述',
          backgroundSetting: '测试背景',
        );

        // 添加到书架
        await dbService.addToBookshelf(novel);

        // 验证
        final isInBookshelf = await dbService.isInBookshelf(novel.url);
        expect(isInBookshelf, isTrue, reason: '独立实例第3次: 应该能成功添加小说');

        // 显式关闭
        await testDatabase.close();

        print('✅ 方案4-测试3成功: 独立实例模式第3次运行通过');
      });
    });

  });
}

/// 测试专用的轻量级DatabaseService包装类
class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<int> addToBookshelf(Novel novel) async {
    final db = await database;
    final map = novel.toMap();
    map.remove('isInBookshelf');
    map['addedAt'] = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('bookshelf', map, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
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
  Future<void> close() async {
    await _database.close();
  }

  // 其他方法的存根
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Method ${invocation.memberName} not implemented in test database service',
    );
  }
}
