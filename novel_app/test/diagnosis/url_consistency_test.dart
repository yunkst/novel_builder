import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import '../test_bootstrap.dart';
import '../base/database_test_base.dart';

/// URL一致性诊断测试
///
/// 问题：为什么能看到背景设定但保存失败？
///
/// 假设：读取和保存使用了不同的URL
void main() {
  setUpAll(() {
    initTests();
  });

  group('URL一致性诊断', () {
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

    test('诊断: 检查URL细微差异', () async {
      print('\n=== URL一致性诊断测试 ===\n');

      // 步骤1: 添加一个正常URL的小说
      final novel = Novel(
        title: 'URL测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/test-123', // 标准URL
        isInBookshelf: true,
        backgroundSetting: '这是原始背景设定',
      );

      print('步骤1: 添加小说到书架');
      print('URL: ${novel.url}');
      await dbService.addToBookshelf(novel);

      // 步骤2: 读取背景设定（成功）
      print('\n步骤2: 读取背景设定');
      final readBackground = await dbService.getBackgroundSetting(novel.url);
      print('✅ 读取成功: "$readBackground"');
      expect(readBackground, isNotNull);

      // 步骤3: 使用相同URL更新（应该成功）
      print('\n步骤3: 使用相同URL更新背景设定');
      final updateResult1 = await dbService.updateBackgroundSetting(
        novel.url,
        '更新内容1',
      );
      print('更新结果: $updateResult1 条记录');
      expect(updateResult1, equals(1), reason: '相同URL应该更新成功');

      // 步骤4: 验证更新成功
      final updated1 = await dbService.getBackgroundSetting(novel.url);
      expect(updated1, equals('更新内容1'));
      print('✅ 更新成功，读取到: "$updated1"');

      // ========================================
      // 关键测试：URL细微差异
      // ========================================

      final urlVariants = [
        ('末尾多斜杠', 'https://example.com/novel/test-123/'),
        ('末尾少斜杠', 'https://example.com/novel/test-123'),
        ('HTTP协议', 'http://example.com/novel/test-123'),
        ('HTTPS协议', 'https://example.com/novel/test-123'),
        ('大写路径', 'https://example.com/novel/TEST-123'),
        ('小写路径', 'https://example.com/novel/test-123'),
        ('带参数', 'https://example.com/novel/test-123?param=1'),
        ('带锚点', 'https://example.com/novel/test-123#anchor'),
        ('URL编码', 'https://example.com/novel/test%2D123'),
        ('双斜杠', 'https://example.com//novel/test-123'),
      ];

      print('\n=== 测试URL变体的读写行为 ===\n');

      for (final (desc, urlVariant) in urlVariants) {
        print('--- $desc ---');
        print('URL变体: $urlVariant');

        // 尝试读取
        final readResult = await dbService.getBackgroundSetting(urlVariant);
        final canRead = readResult != null;
        print('读取: ${canRead ? "✅ 成功" : "❌ 失败"}');

        if (canRead && readResult!.isNotEmpty) {
          final preview = readResult.length > 20
              ? '${readResult.substring(0, 20)}...'
              : readResult;
          print('  读取内容: "$preview"');
        }

        // 尝试更新
        final updateResult = await dbService.updateBackgroundSetting(
          urlVariant,
          '测试更新-$desc',
        );
        final canWrite = updateResult > 0;
        print('更新: ${canWrite ? "✅ 成功" : "❌ 失败"} (返回: $updateResult)');

        // 关键判断：如果能读但不能写，这就是BUG！
        if (canRead && !canWrite) {
          print('🐛 发现BUG：能读取但不能写入！');
          print('   这就是用户遇到的问题！');
        }

        print('');
      }

      // Cleanup
      await dbService.removeFromBookshelf(novel.url);
      print('✅ 测试完成，数据已清理');
    });

    test('复现用户场景：能读取但不能写入', () async {
      print('\n=== 复现用户场景 ===\n');

      // 场景：从搜索结果进入章节列表
      // 搜索API返回的URL可能是：https://example.com/novel/123
      // 但数据库中存储的URL可能是：https://example.com/novel/123/

      final storedUrl = 'https://example.com/novel/stored-123/';
      final apiReturnedUrl = 'https://example.com/novel/stored-123';

      // 步骤1: 模拟数据库中存储的URL（带末尾斜杠）
      final novelInDb = Novel(
        title: '测试小说',
        author: '作者',
        url: storedUrl, // 带斜杠
        isInBookshelf: true,
        backgroundSetting: '数据库中的背景设定',
      );

      print('步骤1: 添加小说到数据库（URL带末尾斜杠）');
      print('存储URL: $storedUrl');
      await dbService.addToBookshelf(novelInDb);

      // 步骤2: 使用存储的URL读取（成功）
      print('\n步骤2: 使用存储URL读取背景设定');
      final background1 = await dbService.getBackgroundSetting(storedUrl);
      print('✅ 读取成功: "$background1"');

      // 步骤3: 模拟从API获取的URL（不带斜杠）读取
      print('\n步骤3: 使用API返回的URL（不带斜杠）读取');
      final background2 = await dbService.getBackgroundSetting(apiReturnedUrl);
      print('读取结果: ${background2 != null ? "✅ 成功" : "❌ 失败"}');
      if (background2 != null) {
        print('  内容: "$background2"');
      }

      // 步骤4: 使用API返回的URL更新（失败？）
      print('\n步骤4: 使用API返回的URL更新背景设定');
      final updateResult = await dbService.updateBackgroundSetting(
        apiReturnedUrl, // 不带斜杠
        'AI总结内容',
      );
      print('更新结果: $updateResult 条记录');

      if (updateResult == 0) {
        print('❌ 更新失败！');
        print('\n🐛 BUG复现成功！');
        print('   - 能读取背景设定（使用存储URL）');
        print('   - 但不能保存（使用API URL）');
        print('   - 原因：URL不一致');
      } else {
        print('✅ 更新成功（说明没有URL不匹配问题）');
      }

      // Cleanup
      await dbService.removeFromBookshelf(storedUrl);
      print('\n✅ 测试完成');
    });

    test('检查数据库中实际存储的URL', () async {
      print('\n=== 检查数据库中实际存储的URL ===\n');

      // 添加几个测试小说
      final novels = [
        Novel(
          title: '小说1',
          author: '作者1',
          url: 'https://example.com/novel/1/',
          isInBookshelf: true,
        ),
        Novel(
          title: '小说2',
          author: '作者2',
          url: 'https://example.com/novel/2', // 不带斜杠
          isInBookshelf: true,
        ),
      ];

      for (final novel in novels) {
        await dbService.addToBookshelf(novel);
      }

      // 查询所有书架中的小说
      final allNovels = await dbService.getBookshelf();

      print('数据库中的小说：');
      for (final novel in allNovels.take(10)) {
        print('- ${novel.title}');
        print('  URL: "${novel.url}"');
        print('  末尾斜杠: ${novel.url.endsWith("/") ? "是" : "否"}');
        print('');
      }

      // Cleanup
      for (final novel in novels) {
        await dbService.removeFromBookshelf(novel.url);
      }

      print('✅ 检查完成');
    });
  });
}
