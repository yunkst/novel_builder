import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';
import '../../base/database_test_base.dart';

void main() {
  // 初始化FFI
  initTests();

  group('insertUserChapter Bug Fix Verification', () {
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

    test('insertUserChapter应该正确传递index参数', () async {
      // 创建测试小说 - 使用唯一URL避免冲突
      final testNovel = Novel(
        title: '测试小说_index',
        author: '测试作者',
        url: 'test://novel_index_${DateTime.now().millisecondsSinceEpoch}',
        coverUrl: null,
        description: null,
        backgroundSetting: null,
      );
      await dbService.addToBookshelf(testNovel);

      // 在索引0处插入用户章节
      await dbService.insertUserChapter(
        testNovel.url,
        '用户章节',
        '用户内容',
        0,
      );

      final chapters = await dbService.getChapters(testNovel.url);
      expect(chapters.length, 1, reason: '应该只有1个章节');
      expect(chapters[0].title, '用户章节');
      expect(chapters[0].chapterIndex, 0, reason: '索引应该为0'); // 验证索引为0
    });

    test('insertUserChapter不传index时应该自动计算', () async {
      // 创建测试小说
      final testNovel = Novel(
        title: '测试小说_auto',
        author: '测试作者',
        url: 'test://novel_auto_${DateTime.now().millisecondsSinceEpoch}',
        coverUrl: null,
        description: null,
        backgroundSetting: null,
      );
      await dbService.addToBookshelf(testNovel);

      // 不传index,应该自动计算为0 (MAX为null时使用0)
      await dbService.insertUserChapter(
        testNovel.url,
        '章节自动',
        '内容自动',
      );

      final chapters = await dbService.getChapters(testNovel.url);
      expect(chapters.length, 1, reason: '应该只有1个章节');
      expect(chapters[0].chapterIndex, 0, reason: '自动计算的索引应该是0');
    });
  });
}
