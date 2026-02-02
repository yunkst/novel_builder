import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';
import '../../base/database_test_base.dart';

/// 并发测试验证 - 确认数据库锁定问题已修复
void main() {
  initDatabaseTests();

  group('并发测试 - 数据库锁定修复验证', () {
    test('多个测试同时运行应该不会锁定', () async {
      // 创建多个独立的测试实例
      final tests = List.generate(10, (index) async {
        final base = DatabaseTestBase();
        await base.setUp();

        // 执行数据库操作
        final novel = await base.createAndAddNovel(
          url: 'https://test.com/novel/$index',
          title: '测试小说$index',
        );

        // 验证数据
        final novels = await base.databaseService.getBookshelf();
        expect(novels, isNotEmpty);
        expect(novels.first.url, contains('$index'));

        await base.tearDown();
        return index;
      });

      // 并发执行所有测试
      final results = await Future.wait(tests);

      // 验证所有测试都成功完成
      expect(results, hasLength(10));
      print('✅ 所有并发测试通过，数据库锁定问题已修复!');
    });

    test('测试之间应该完全隔离', () async {
      // 测试1
      final base1 = DatabaseTestBase();
      await base1.setUp();
      await base1.createAndAddNovel(url: 'https://test.com/novel/1');

      // 测试2
      final base2 = DatabaseTestBase();
      await base2.setUp();
      await base2.createAndAddNovel(url: 'https://test.com/novel/2');

      // 验证隔离性
      final novels1 = await base1.databaseService.getBookshelf();
      final novels2 = await base2.databaseService.getBookshelf();

      expect(novels1, hasLength(1));
      expect(novels2, hasLength(1));
      expect(novels1.first.url, contains('novel/1'));
      expect(novels2.first.url, contains('novel/2'));

      await base1.tearDown();
      await base2.tearDown();

      print('✅ 测试隔离性验证通过');
    });
  });
}
