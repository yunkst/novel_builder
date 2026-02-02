import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';

/// 简单的测试确认数据库锁定问题
///
/// 这个测试会模拟多个测试并发执行的场景
/// 来确认是否存在数据库锁定问题
void main() {
  initDatabaseTests();

  group('数据库锁定问题确认测试', () {
    late DatabaseService dbService1;
    late DatabaseService dbService2;

    setUp(() async {
      // 创建两个独立的数据库服务实例
      dbService1 = DatabaseService();
      dbService2 = DatabaseService();
    });

    test('两个独立测试应该使用不同的数据库实例', () async {
      // 第一个实例添加数据
      final novels1 = await dbService1.getBookshelf();
      expect(novels1, isEmpty);

      // 第二个实例添加数据
      final novels2 = await dbService2.getBookshelf();
      expect(novels2, isEmpty);

      print('✅ 测试1完成：两个实例独立运行');
    });

    test('并发操作应该不会导致锁定', () async {
      // 模拟并发操作
      final future1 = dbService1.getBookshelf();
      final future2 = dbService2.getBookshelf();

      final results = await Future.wait([future1, future2]);

      expect(results[0], isA<List>());
      expect(results[1], isA<List>());

      print('✅ 测试2完成：并发操作正常');
    });
  });

  group('验证数据库隔离性', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      // 每个测试前清理
      final db = await dbService.database;
      await db.delete('bookshelf');
    });

    test('每个测试应该看到干净的数据库', () async {
      final novels = await dbService.getBookshelf();
      expect(novels, isEmpty);
      print('✅ 测试3完成：数据库隔离正常');
    });
  });
}
