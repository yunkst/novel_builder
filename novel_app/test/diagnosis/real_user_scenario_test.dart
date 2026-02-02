import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import '../test_bootstrap.dart';
import '../base/database_test_base.dart';

/// 真实用户场景模拟测试
///
/// 假设：用户从搜索结果进入章节列表，此时：
/// 1. 搜索API返回的URL格式 = A
/// 2. 数据库中存储的URL格式 = B
/// 3. A != B 导致保存失败
void main() {
  setUpAll(() {
    initTests();
  });

  group('真实用户场景模拟', () {
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

    test('场景1: 用户通过"全部小说"书架进入', () async {
      print('\n=== 场景1: 全部小说书架 ===\n');

      // "全部小说"是虚拟书架，显示bookshelf表中的所有小说
      // 但小说可能之前通过搜索加入，URL格式可能不同

      // 模拟：用户之前搜索并添加小说到书架
      // 搜索API返回的URL（不带斜杠）
      const searchApiUrl = 'https://example.com/novel/test-123';

      final novelFromSearch = Novel(
        title: '测试小说',
        author: '作者',
        url: searchApiUrl, // 搜索API返回的URL
        isInBookshelf: true,
      );

      print('步骤1: 用户从搜索添加小说到书架');
      print('搜索API返回的URL: "$searchApiUrl"');
      await dbService.addToBookshelf(novelFromSearch);

      // 步骤2: 用户从"全部小说"书架打开章节列表
      print('\n步骤2: 用户从全部小说书架打开章节列表');
      final novelsInBookshelf = await dbService.getBookshelf();

      final targetNovel = novelsInBookshelf.firstWhere(
        (n) => n.url.contains('test-123'),
        orElse: () => throw Exception('未找到小说'),
      );

      print('数据库中实际存储的URL: "${targetNovel.url}"');
      print('背景设定: "${targetNovel.backgroundSetting ?? "（空）"}"');

      // 关键检查：URL是否一致
      if (targetNovel.url != searchApiUrl) {
        print('\n⚠️  发现URL不一致！');
        print('   搜索API: "$searchApiUrl"');
        print('   数据库存储: "${targetNovel.url}"');
      }

      // 步骤3: 用户打开背景设定页面
      print('\n步骤3: 用户打开背景设定页面');
      print('页面使用的 novel.url: "${targetNovel.url}"');

      // 读取背景设定（使用数据库中的URL）
      final background = await dbService.getBackgroundSetting(targetNovel.url);
      print('读取背景设定: "${background ?? "（空）"}"');

      // 设置背景设定
      print('\n步骤4: 用户设置背景设定');
      const testBackground = '这是新的背景设定';
      final saveResult = await dbService.updateBackgroundSetting(
        targetNovel.url, // 使用数据库中的URL
        testBackground,
      );

      print('保存结果: $saveResult 条记录');

      if (saveResult == 0) {
        print('❌ 保存失败！');
      } else {
        print('✅ 保存成功');
        // 验证
        final saved = await dbService.getBackgroundSetting(targetNovel.url);
        expect(saved, equals(testBackground));
      }

      // Cleanup
      await dbService.removeFromBookshelf(targetNovel.url);
      print('\n✅ 测试完成\n');
    });

    test('场景2: 检查URL何时被修改', () async {
      print('\n=== 场景2: URL何时被修改 ===\n');

      // 追踪：Novel对象的URL在整个流程中是否被修改

      // 1. 从搜索API创建Novel对象
      print('1. 从搜索API创建Novel对象');
      final novelFromApi = Novel(
        title: 'URL追踪测试',
        author: '测试',
        url: 'https://example.com/novel/trace-test',
        isInBookshelf: false,
      );
      print('   API返回的URL: "${novelFromApi.url}"');

      // 2. 添加到数据库
      print('\n2. 添加到数据库');
      await dbService.addToBookshelf(novelFromApi);

      // 3. 从数据库读取
      print('\n3. 从数据库读取');
      final novels = await dbService.getBookshelf();
      final novelFromDb = novels.firstWhere(
        (n) => n.url.contains('trace-test'),
        orElse: () => throw Exception('未找到'),
      );
      print('   数据库中的URL: "${novelFromDb.url}"');

      // 4. 比较
      print('\n4. URL比较');
      print('   API URL: "${novelFromApi.url}"');
      print('   DB URL: "${novelFromDb.url}"');
      print('   是否一致: ${novelFromApi.url == novelFromDb.url ? "✅ 是" : "❌ 否"}');

      if (novelFromApi.url != novelFromDb.url) {
        print('\n💡 问题发现：URL在存储过程中被修改了！');
        print('   可能原因：');
        print('   - DatabaseService.addToBookshelf() 修改了URL');
        print('   - Novel.toMap() 或 fromMap() 修改了URL');
        print('   - 数据库存储/读取过程中URL被处理');
      }

      // 5. 检查数据库存储逻辑
      print('\n5. 检查DatabaseService内部实现');
      print('   查看addToBookshelf()是否修改了URL...');

      // 直接读取数据库原始数据
      final db = await dbService.database;
      final rawMaps = await db.query(
        'bookshelf',
        where: 'url LIKE ?',
        whereArgs: ['%trace-test%'],
        columns: ['url'],
      );

      if (rawMaps.isNotEmpty) {
        final rawUrl = rawMaps.first['url'] as String;
        print('   数据库原始URL: "$rawUrl"');
        print('   Novel对象URL: "${novelFromDb.url}"');
        print('   原始URL == Novel URL: ${rawUrl == novelFromDb.url ? "✅ 是" : "❌ 否"}');
      }

      // Cleanup
      await dbService.removeFromBookshelf(novelFromDb.url);
      print('\n✅ 检查完成\n');
    });

    test('场景3: 模拟完整的读取→编辑→保存流程', () async {
      print('\n=== 场景3: 完整流程测试 ===\n');

      // 创建测试小说
      final testNovel = Novel(
        title: '完整流程测试',
        author: '作者',
        url: 'https://test.com/flow-test',
        isInBookshelf: true,
        backgroundSetting: '原始内容',
      );

      print('1. 创建并添加小说');
      print('   URL: "${testNovel.url}"');
      await dbService.addToBookshelf(testNovel);

      // 模拟：用户打开背景设定页面
      print('\n2. 用户打开背景设定页面');
      print('   widget.novel.url: "${testNovel.url}"');

      // 读取（使用widget.novel.url）
      print('\n3. 读取背景设定');
      final readUrl = testNovel.url;
      final background1 = await dbService.getBackgroundSetting(readUrl);
      print('   使用URL: "$readUrl"');
      print('   读取结果: "${background1 ?? "（空）"}"');

      // 编辑并保存（使用widget.novel.url）
      print('\n4. 编辑并保存');
      const newContent = '新内容';
      final saveUrl = testNovel.url;
      final saveResult = await dbService.updateBackgroundSetting(
        saveUrl,
        newContent,
      );
      print('   使用URL: "$saveUrl"');
      print('   保存结果: $saveResult 条记录');

      // 验证
      print('\n5. 验证保存结果');
      final background2 = await dbService.getBackgroundSetting(testNovel.url);
      print('   读取结果: "${background2 ?? "（空）"}"');
      print('   期望: "$newContent"');
      print('   匹配: ${background2 == newContent ? "✅ 是" : "❌ 否"}');

      expect(background2, equals(newContent),
        reason: '使用相同URL应该能成功保存');

      // Cleanup
      await dbService.removeFromBookshelf(testNovel.url);
      print('\n✅ 测试完成\n');
    });
  });
}
