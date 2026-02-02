import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import '../test_bootstrap.dart';
import '../base/database_test_base.dart';

/// 背景设定持久化集成测试
///
/// 测试目标：
/// 1. 模拟完整的AI总结流程
/// 2. 验证数据确实保存到数据库
/// 3. 验证保存后能正确读取
/// 4. 测试各种失败场景
void main() {
  // 初始化 FFI
  setUpAll(() {
    initTests();
  });

  group('背景设定持久化 - 集成测试', () {
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

    test('场景1: 小说在书架中 - 应该成功保存', () async {
      print('\n=== 场景1: 小说在书架中的保存流程 ===');

      // Arrange: 准备测试数据
      final testNovel = Novel(
        title: '测试小说_场景1_${DateTime.now().millisecondsSinceEpoch}',
        author: '测试作者',
        url: 'https://test.com/scenario1/${DateTime.now().millisecondsSinceEpoch}',
        isInBookshelf: true,
        backgroundSetting: '这是原始的背景设定内容，包含很多详细信息...',
      );

      // 步骤1: 添加小说到书架（模拟用户操作）
      print('\n步骤1: 添加小说到书架');
      final addResult = await dbService.addToBookshelf(testNovel);
      print('✅ 添加结果: $addResult 条记录');
      expect(addResult, greaterThan(0), reason: '应该成功添加到书架');

      // 验证小说确实在书架中
      final isInBookshelf = await dbService.isInBookshelf(testNovel.url);
      expect(isInBookshelf, isTrue, reason: '小说应该在书架表中');
      print('✅ 小说在书架表中: $isInBookshelf');

      // 步骤2: 模拟AI总结并保存（这是真实场景）
      print('\n步骤2: 模拟AI总结并保存');
      const aiSummary = '这是AI总结后的精简背景设定\n\n包含核心世界观和关键设定';

      final saveResult = await dbService.updateBackgroundSetting(
        testNovel.url,
        aiSummary,
      );
      print('保存结果: $saveResult 条记录被修改');

      // 关键断言：验证保存成功
      expect(saveResult, equals(1),
          reason: '应该成功更新1条记录。如果返回0，说明保存失败！');
      print('✅ 保存成功: $saveResult 条记录');

      // 步骤3: 验证数据确实持久化到数据库
      print('\n步骤3: 验证数据持久化');
      final savedBackground = await dbService.getBackgroundSetting(
        testNovel.url,
      );
      print('从数据库读取: "$savedBackground"');

      expect(savedBackground, isNotNull,
          reason: '应该能读取到保存的内容');
      expect(savedBackground, equals(aiSummary),
          reason: '保存的内容应该和AI总结完全一致');
      print('✅ 数据持久化验证通过！');

      // 步骤4: 模拟页面刷新后重新读取
      print('\n步骤4: 模拟页面刷新');
      final reloadedBackground = await dbService.getBackgroundSetting(
        testNovel.url,
      );
      expect(reloadedBackground, equals(aiSummary),
          reason: '刷新后应该能读取到相同的内容');
      print('✅ 刷新后数据一致！');

      // Cleanup
      print('\n清理测试数据');
      await dbService.removeFromBookshelf(testNovel.url);
      print('✅ 测试完成，数据已清理\n');
    });

    test('场景2: 小说不在书架中 - 保存应该失败', () async {
      print('\n=== 场景2: 小说不在书架中的保存流程 ===');

      const nonExistentUrl = 'https://does.not.exist/novel/999';

      // 步骤1: 尝试保存不存在的小说
      print('\n步骤1: 尝试更新不存在的小说背景设定');
      const testBackground = '这是测试内容';

      final updateResult = await dbService.updateBackgroundSetting(
        nonExistentUrl,
        testBackground,
      );

      print('更新结果: $updateResult 条记录被修改');

      // 关键断言：应该返回0（失败）
      expect(updateResult, equals(0),
          reason: '小说不在书架时，update()应该返回0，表示没有记录被更新');
      print('✅ 正确返回0（保存失败）');

      // 步骤2: 验证数据库中确实没有该数据
      print('\n步骤2: 验证数据库中没有该数据');
      final background = await dbService.getBackgroundSetting(
        nonExistentUrl,
      );

      expect(background, isNull,
          reason: '不应该读取到任何内容');
      print('✅ 确认数据库中没有该小说的背景设定');

      print('\n❌ 这就是用户遇到的问题：');
      print('   小说不在bookshelf表中，导致保存失败！');
      print('   但UI没有提示错误，用户以为保存成功了。\n');
    });

    test('场景3: URL不匹配 - 保存应该失败', () async {
      print('\n=== 场景3: URL不匹配导致的保存失败 ===');

      // Arrange: 添加一个URL正常的小说
      final novel = Novel(
        title: 'URL匹配测试',
        author: '测试',
        url: 'https://example.com/novel/exact-url',
        isInBookshelf: true,
      );

      await dbService.addToBookshelf(novel);
      print('添加小说URL: ${novel.url}');

      // Act: 使用略有不同的URL尝试更新
      final urlVariants = [
        ('末尾多斜杠', 'https://example.com/novel/exact-url/'),
        ('HTTP协议', 'http://example.com/novel/exact-url'),
        ('大写字母', 'https://example.com/novel/EXACT-URL'),
        ('带参数', 'https://example.com/novel/exact-url?p=1'),
      ];

      print('\n测试URL变体：');
      for (final (desc, urlVariant) in urlVariants) {
        final result = await dbService.updateBackgroundSetting(
          urlVariant,
          '测试内容',
        );

        final status = result == 0 ? '❌ 失败' : '✅ 成功';
        print('$status - $desc: $urlVariant');
        print('     返回值: $result');

        expect(result, equals(0),
            reason: 'URL不匹配时应该返回0');
      }

      // Cleanup
      await dbService.removeFromBookshelf(novel.url);
      print('\n✅ 测试完成\n');
    });

    test('场景4: 完整用户操作流程模拟', () async {
      print('\n=== 场景4: 完整的用户操作流程 ===');

      // 模拟用户在App中的操作：
      // 1. 搜索小说并查看详情
      // 2. 打开章节列表
      // 3. 点击背景设定菜单
      // 4. 点击AI总结按钮
      // 5. AI生成总结内容
      // 6. 点击确认替换按钮

      final novel = Novel(
        title: '完整流程测试',
        author: '作者',
        url: 'https://test.com/full-flow/${DateTime.now().millisecondsSinceEpoch}',
        isInBookshelf: false, // 注意：用户可能没有加入书架
        backgroundSetting: '很长的原始背景设定...',
      );

      print('\n步骤1: 用户打开章节列表（小说不在书架中）');
      final isInBookshelf = await dbService.isInBookshelf(novel.url);
      print('小说在书架中: $isInBookshelf');

      if (!isInBookshelf) {
        print('⚠️  小说不在书架中，这会导致保存失败！');
      }

      print('\n步骤2: 用户点击"AI总结"并生成内容');
      const aiSummary = '精简的AI总结';

      print('\n步骤3: 用户点击"确认替换"（调用updateBackgroundSetting）');
      final saveResult = await dbService.updateBackgroundSetting(
        novel.url,
        aiSummary,
      );

      print('保存结果: $saveResult 条记录');

      if (saveResult == 0) {
        print('❌ 保存失败！但UI可能显示"保存成功"');
        print('💡 这就是用户报告的BUG！');
      }

      expect(saveResult, equals(0),
          reason: '小说不在书架时应该返回0');

      // 正确的流程：先添加到书架
      print('\n✅ 正确流程：先添加到书架，再保存');
      await dbService.addToBookshelf(novel);

      final retryResult = await dbService.updateBackgroundSetting(
        novel.url,
        aiSummary,
      );

      expect(retryResult, equals(1),
          reason: '添加到书架后应该能成功保存');
      print('保存结果: $retryResult 条记录（成功）');

      // 验证
      final saved = await dbService.getBackgroundSetting(novel.url);
      expect(saved, equals(aiSummary));
      print('✅ 背景设定已成功保存并验证');

      // Cleanup
      await dbService.removeFromBookshelf(novel.url);
      print('\n✅ 测试完成\n');
    });

    test('场景5: 边界情况 - 空字符串和null', () async {
      print('\n=== 场景5: 边界情况测试 ===');

      final novel = Novel(
        title: '边界测试',
        author: '测试',
        url: 'https://test.com/boundary/${DateTime.now().millisecondsSinceEpoch}',
        isInBookshelf: true,
      );

      await dbService.addToBookshelf(novel);

      // 测试1: 保存空字符串
      print('\n测试1: 保存空字符串');
      var result = await dbService.updateBackgroundSetting(novel.url, '');
      expect(result, equals(1));
      print('✅ 空字符串保存成功');

      var saved = await dbService.getBackgroundSetting(novel.url);
      expect(saved, equals(''));
      print('读取结果: "$saved"');

      // 测试2: 保存null（应该清空背景设定）
      print('\n测试2: 保存null（清空）');
      result = await dbService.updateBackgroundSetting(novel.url, null);
      expect(result, equals(1));
      print('✅ null保存成功');

      saved = await dbService.getBackgroundSetting(novel.url);
      expect(saved, isNull);
      print('读取结果: null');

      // 测试3: 保存超长文本
      print('\n测试3: 保存超长文本');
      final longText = 'A' * 10000; // 10000个字符
      result = await dbService.updateBackgroundSetting(novel.url, longText);
      expect(result, equals(1));
      print('✅ 超长文本保存成功');

      saved = await dbService.getBackgroundSetting(novel.url);
      expect(saved, longText);
      print('读取长度: ${saved?.length} 字符');

      // Cleanup
      await dbService.removeFromBookshelf(novel.url);
      print('\n✅ 所有边界测试通过\n');
    });
  });
}
