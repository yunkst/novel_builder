import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 背景设定保存问题诊断测试
///
/// 用途：诊断为什么背景设定无法保存到数据库
///
/// 使用方法：
/// 1. 运行测试: flutter test test/diagnosis/background_setting_save_diagnosis_test.dart
/// 2. 查看控制台输出，了解哪一步出现问题
/// 3. 根据输出定位问题根源
void main() {
  // 初始化 FFI
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('背景设定保存诊断', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
    });

    test('诊断步骤1: 检查小说是否在bookshelf表中', () async {
      // 测试数据 - 请替换为您实际测试的小说URL
      const testUrl = 'https://example.com/novel/123';

      print('\n=== 步骤1: 检查小说是否在bookshelf表中 ===');

      // 检查小说是否存在
      final isInBookshelf = await dbService.isInBookshelf(testUrl);
      print('小说URL: $testUrl');
      print('小说在bookshelf表中: $isInBookshelf');

      if (!isInBookshelf) {
        print('❌ 问题根源：小说不在bookshelf表中！');
        print('💡 解决方案：需要先将小说添加到书架');
        return;
      }

      print('✅ 小说在bookshelf表中');

      // 步骤2: 查询当前背景设定
      print('\n=== 步骤2: 查询当前背景设定 ===');
      final currentBackground = await dbService.getBackgroundSetting(testUrl);
      print('当前背景设定: "${currentBackground ?? "（空）"}"');

      // 步骤3: 尝试更新背景设定
      print('\n=== 步骤3: 尝试更新背景设定 ===');
      final testBackground = '这是测试更新的背景设定\n时间: ${DateTime.now()}';
      final updateResult = await dbService.updateBackgroundSetting(
        testUrl,
        testBackground,
      );
      print('更新结果: $updateResult 条记录被修改');

      if (updateResult == 0) {
        print('❌ 问题根源：update()返回0，没有记录被更新！');
        print('💡 可能原因：');
        print('   1. URL不匹配（检查末尾斜杠、http/https、参数等）');
        print('   2. 数据库连接问题');
        print('   3. 权限问题');
        return;
      }

      print('✅ 成功更新 $updateResult 条记录');

      // 步骤4: 验证更新是否成功
      print('\n=== 步骤4: 验证更新是否成功 ===');
      final updatedBackground = await dbService.getBackgroundSetting(testUrl);
      print('更新后的背景设定: "${updatedBackground ?? "（空）"}"');

      if (updatedBackground == testBackground) {
        print('✅ 背景设定保存成功！');
      } else {
        print('❌ 背景设定保存失败！');
        print('   期望: "$testBackground"');
        print('   实际: "${updatedBackground ?? "null"}"');
      }
    });

    test('诊断步骤2: 模拟完整流程', () async {
      print('\n=== 模拟完整AI总结流程 ===');

      // 步骤1: 创建并添加小说到书架
      final testNovel = Novel(
        title: '测试小说_${DateTime.now().millisecondsSinceEpoch}',
        author: '测试作者',
        url: 'https://test.com/novel/${DateTime.now().millisecondsSinceEpoch}',
        isInBookshelf: true,
        backgroundSetting: '这是原始背景设定，包含很多详细内容...',
      );

      print('步骤1: 添加小说到书架');
      final addResult = await dbService.addToBookshelf(testNovel);
      print('添加结果: $addResult 条记录');
      expect(addResult, greaterThan(0), reason: '应该成功添加');

      // 步骤2: 模拟AI总结并保存
      print('\n步骤2: 模拟AI总结并保存');
      const aiSummary = '这是精简的AI总结内容';
      final saveResult = await dbService.updateBackgroundSetting(
        testNovel.url,
        aiSummary,
      );
      print('保存结果: $saveResult 条记录被修改');

      if (saveResult == 0) {
        print('❌ 保存失败：返回0');
        fail('保存背景设定失败');
      }

      print('✅ 保存成功');

      // 步骤3: 验证保存结果
      print('\n步骤3: 验证保存结果');
      final savedBackground = await dbService.getBackgroundSetting(testNovel.url);
      print('保存的内容: "$savedBackground"');

      expect(savedBackground, equals(aiSummary),
        reason: '应该读取到AI总结的内容');

      print('✅ 完整流程验证通过！');

      // 清理测试数据
      print('\n清理测试数据');
      await dbService.removeFromBookshelf(testNovel.url);
      print('✅ 清理完成');
    });

    test('诊断步骤3: URL匹配测试', () async {
      print('\n=== 测试URL匹配问题 ===');

      // 添加测试小说
      final novel = Novel(
        title: 'URL测试小说',
        author: '测试',
        url: 'https://example.com/novel/test-123',
        isInBookshelf: true,
      );

      await dbService.addToBookshelf(novel);
      print('添加小说: ${novel.url}');

      // 测试不同的URL变体
      final urlVariants = [
        ('完全相同', 'https://example.com/novel/test-123'),
        ('末尾斜杠', 'https://example.com/novel/test-123/'),
        ('HTTP协议', 'http://example.com/novel/test-123'),
        ('带参数', 'https://example.com/novel/test-123?p=1'),
      ];

      for (final (desc, urlVariant) in urlVariants) {
        final result = await dbService.updateBackgroundSetting(
          urlVariant,
          '测试内容',
        );

        final status = result > 0 ? '✅ 成功' : '❌ 失败';
        print('$status - $desc: $urlVariant (结果: $result)');
      }

      // 清理
      await dbService.removeFromBookshelf(novel.url);
    });
  });
}
