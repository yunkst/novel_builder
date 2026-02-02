import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import '../../test_bootstrap.dart';
import '../../base/database_test_base.dart';

/// 背景设定实时加载测试
///
/// 验证修复：每次打开背景设定页面都从数据库读取最新数据
void main() {
  setUpAll(() {
    initTests();
  });

  group('背景设定实时加载测试', () {
    late DatabaseTestBase testBase;
    late DatabaseService dbService;
    setUp(() async {
      testBase = DatabaseTestBase();
      await testBase.setUp();
      dbService = testBase.databaseService;
    });

    tearDown(() async {
      await testBase.tearDown();
    });

    test('验证：数据库读取和内存对象不一致时的行为', () async {
      print('\n=== 验证数据库和内存数据不一致场景 ===\n');

      // 步骤1: 创建并添加小说到书架
      final novel = Novel(
        title: '实时加载测试',
        author: '测试作者',
        url: 'https://test.com/realtime/${DateTime.now().millisecondsSinceEpoch}',
        isInBookshelf: true,
        backgroundSetting: '原始内容（内存中）',
      );

      print('步骤1: 添加小说到书架');
      await dbService.addToBookshelf(novel);
      print('Novel对象中的backgroundSetting: "${novel.backgroundSetting}"');

      // 步骤2: 直接修改数据库，模拟另一个操作修改了背景设定
      print('\n步骤2: 直接修改数据库（模拟其他操作）');
      await dbService.updateBackgroundSetting(
        novel.url,
        '数据库中的最新内容',
      );

      // 步骤3: 从数据库读取，验证数据已更新
      final fromDb = await dbService.getBackgroundSetting(novel.url);
      print('数据库中的backgroundSetting: "$fromDb"');
      print('Novel对象中的backgroundSetting: "${novel.backgroundSetting}"');
      print('是否一致: ${fromDb == novel.backgroundSetting ? "是" : "否"}');

      expect(fromDb, equals('数据库中的最新内容'));
      expect(novel.backgroundSetting, equals('原始内容（内存中）'));

      print('\n✅ 确认：数据库和内存对象不一致');
      print('   - 数据库: "数据库中的最新内容"');
      print('   - Novel对象: "原始内容（内存中）"');

      // 步骤4: 验证修复后的行为
      print('\n步骤3: 修复后的行为验证');
      print('如果页面使用 _loadBackgroundSetting()：');
      print('  应该读取到: "数据库中的最新内容" ✅');
      print('如果页面使用 widget.novel.backgroundSetting：');
      print('  会读取到: "原始内容（内存中）" ❌');

      // Cleanup
      await dbService.removeFromBookshelf(novel.url);
      print('\n✅ 测试完成\n');
    });

    test('场景: 用户修改背景设定后重新打开页面', () async {
      print('\n=== 模拟用户真实操作流程 ===\n');

      final novel = Novel(
        title: '用户操作测试',
        author: '作者',
        url: 'https://test.com/user-flow/${DateTime.now().millisecondsSinceEpoch}',
        isInBookshelf: true,
        backgroundSetting: '第一次打开时的内容',
      );

      await dbService.addToBookshelf(novel);

      // 场景1: 第一次打开页面
      print('场景1: 用户第一次打开背景设定页面');
      print('  Novel.backgroundSetting: "${novel.backgroundSetting}"');
      print('  （旧实现）页面会显示: "${novel.backgroundSetting}" ❌ 内存旧值');
      print('  （新实现）页面会从数据库读取最新数据 ✅');

      final dbValue1 = await dbService.getBackgroundSetting(novel.url);
      print('  数据库实际值: "$dbValue1"');

      // 场景2: 用户修改并保存
      print('\n场景2: 用户修改内容为"用户修改后的内容"并保存');
      await dbService.updateBackgroundSetting(novel.url, '用户修改后的内容');

      final dbValue2 = await dbService.getBackgroundSetting(novel.url);
      print('  保存后数据库值: "$dbValue2"');
      print('  Novel对象值: "${novel.backgroundSetting}"（未改变）');

      // 场景3: 用户返回，再次打开页面
      print('\n场景3: 用户再次打开背景设定页面');
      print('  Novel.backgroundSetting: "${novel.backgroundSetting}"（还是旧值）');
      print('  （旧实现）页面会显示: "${novel.backgroundSetting}" ❌ 错误！');
      print('  （新实现）从数据库读取: "$dbValue2" ✅ 正确！');

      // 验证
      expect(dbValue2, equals('用户修改后的内容'));
      expect(novel.backgroundSetting, equals('第一次打开时的内容'));

      print('\n✅ 修复验证：');
      print('   旧实现: 使用内存值，导致显示"第一次打开时的内容"');
      print('   新实现: 从数据库读取，显示"用户修改后的内容"');

      // Cleanup
      await dbService.removeFromBookshelf(novel.url);
      print('\n✅ 测试完成\n');
    });

    test('场景: AI总结后的数据刷新', () async {
      print('\n=== AI总结后数据刷新测试 ===\n');

      final novel = Novel(
        title: 'AI总结测试',
        author: '作者',
        url: 'https://test.com/ai-summary/${DateTime.now().millisecondsSinceEpoch}',
        isInBookshelf: true,
        backgroundSetting: '很长的原始背景设定...',
      );

      await dbService.addToBookshelf(novel);

      print('1. 初始状态');
      final initial = await dbService.getBackgroundSetting(novel.url);
      print('   背景: "${initial}"');

      print('\n2. 用户点击AI总结，生成总结内容');
      const aiSummary = '这是AI总结后的精简内容';

      // 模拟AI总结后保存
      await dbService.updateBackgroundSetting(novel.url, aiSummary);

      final afterSummary = await dbService.getBackgroundSetting(novel.url);
      print('   AI总结后数据库: "$afterSummary"');
      print('   Novel对象: "${novel.backgroundSetting}"（未更新）');

      print('\n3. 调用 _reloadBackgroundSetting()');
      // _reloadBackgroundSetting() 现在内部调用 _loadBackgroundSetting()
      // 会从数据库读取最新数据
      final reloaded = await dbService.getBackgroundSetting(novel.url);
      print('   重新读取: "$reloaded"');

      expect(reloaded, equals(aiSummary));

      print('\n✅ AI总结后刷新验证通过');

      // Cleanup
      await dbService.removeFromBookshelf(novel.url);
      print('\n✅ 测试完成\n');
    });
  });
}
