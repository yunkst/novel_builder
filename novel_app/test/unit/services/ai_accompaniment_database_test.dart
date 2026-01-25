import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../../base/database_test_base.dart';
import '../../test_bootstrap.dart';

/// AI伴读功能数据库服务层测试
///
/// 测试重点：
/// 1. 伴读标记的增删改查
/// 2. 数据库升级后的字段兼容性
/// 3. 边界条件处理
void main() {
  initDatabaseTests();

  group('AI伴读数据库服务测试', () {
    late DatabaseTestBase testBase;

    setUp(() async {
      testBase = _AITestBase();
      await testBase.setUp();
    });

    group('isChapterAccompanied - 检查章节伴读状态', () {
      test('应该返回false对于不存在的章节', () async {
        final result = await testBase.databaseService.isChapterAccompanied(
          'https://example.com/novel1',
          'https://example.com/chapter1',
        );

        expect(result, false);
      });

      test('应该返回false对于未伴读的章节', () async {
        // 先缓存章节但不标记伴读
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        final result = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );

        expect(result, false);
      });

      test('应该返回true对于已伴读的章节', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel2',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter2',
          content: '测试内容',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        // 标记为已伴读
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter.url,
        );

        final result = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );

        expect(result, true);
      });

      test('应该正确区分不同小说的章节', () async {
        final novel1 = Novel(
          title: '小说1',
          author: '作者1',
          url: 'https://example.com/novel1',
        );

        final novel2 = Novel(
          title: '小说2',
          author: '作者2',
          url: 'https://example.com/novel2',
        );

        final chapter1 = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '内容1',
        );

        final chapter2 = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter2', // 不同URL
          content: '内容2',
        );

        await testBase.databaseService.addToBookshelf(novel1);
        await testBase.databaseService.addToBookshelf(novel2);
        await testBase.databaseService.cacheChapter(
          novel1.url,
          chapter1,
          chapter1.content ?? '',
        );
        await testBase.databaseService.cacheChapter(
          novel2.url,
          chapter2,
          chapter2.content ?? '',
        );

        // 只标记novel1的章节
        await testBase.databaseService.markChapterAsAccompanied(
          novel1.url,
          chapter1.url,
        );

        final result1 = await testBase.databaseService.isChapterAccompanied(
          novel1.url,
          chapter1.url,
        );
        final result2 = await testBase.databaseService.isChapterAccompanied(
          novel2.url,
          chapter2.url,
        );

        expect(result1, true);
        expect(result2, false);
      });
    });

    group('markChapterAsAccompanied - 标记章节为已伴读', () {
      test('应该成功标记已缓存的章节', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        // 标记前应该是false
        final before = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(before, false);

        // 标记
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter.url,
        );

        // 标记后应该是true
        final after = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(after, true);
      });

      test('应该可以重复标记同一章节', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        // 第一次标记
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter.url,
        );

        // 第二次标记（不应该抛出异常）
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter.url,
        );

        final result = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(result, true);
      });
    });

    group('resetChapterAccompaniedFlag - 重置章节伴读标记', () {
      test('应该成功重置已伴读的章节', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        // 标记为已伴读
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter.url,
        );

        final before = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(before, true);

        // 重置标记
        await testBase.databaseService.resetChapterAccompaniedFlag(
          novel.url,
          chapter.url,
        );

        final after = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(after, false);
      });

      test('应该可以重置未伴读的章节（幂等性）', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        // 重置未伴读的章节（不应该抛出异常）
        await testBase.databaseService.resetChapterAccompaniedFlag(
          novel.url,
          chapter.url,
        );

        final result = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(result, false);
      });

      test('应该只重置指定章节的标记', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter1 = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '内容1',
        );

        final chapter2 = Chapter(
          title: '第二章',
          url: 'https://example.com/chapter2',
          content: '内容2',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter1,
          chapter1.content ?? '',
        );
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter2,
          chapter2.content ?? '',
        );

        // 标记两个章节
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter1.url,
        );
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter2.url,
        );

        // 只重置chapter1
        await testBase.databaseService.resetChapterAccompaniedFlag(
          novel.url,
          chapter1.url,
        );

        final result1 = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter1.url,
        );
        final result2 = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter2.url,
        );

        expect(result1, false); // chapter1被重置
        expect(result2, true); // chapter2保持不变
      });
    });

    group('集成场景测试', () {
      test('完整流程：缓存 -> 标记 -> 检查 -> 重置 -> 检查', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapter = Chapter(
          title: '第一章',
          url: 'https://example.com/chapter1',
          content: '测试内容',
        );

        await testBase.databaseService.addToBookshelf(novel);
        await testBase.databaseService.cacheChapter(
          novel.url,
          chapter,
          chapter.content ?? '',
        );

        // 1. 初始状态：未伴读
        final state1 = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(state1, false);

        // 2. 标记为已伴读
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapter.url,
        );

        // 3. 检查已伴读
        final state2 = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(state2, true);

        // 4. 重置标记
        await testBase.databaseService.resetChapterAccompaniedFlag(
          novel.url,
          chapter.url,
        );

        // 5. 检查已重置
        final state3 = await testBase.databaseService.isChapterAccompanied(
          novel.url,
          chapter.url,
        );
        expect(state3, false);
      });

      test('多章节场景：正确跟踪每个章节的伴读状态', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel1',
        );

        final chapters = List.generate(
          5,
          (i) => Chapter(
            title: '第${i + 1}章',
            url: 'https://example.com/chapter$i',
            content: '内容$i',
          ),
        );

        await testBase.databaseService.addToBookshelf(novel);

        for (var chapter in chapters) {
          await testBase.databaseService.cacheChapter(
            novel.url,
            chapter,
            chapter.content ?? '',
          );
        }

        // 标记第1、3、5章
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapters[0].url,
        );
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapters[2].url,
        );
        await testBase.databaseService.markChapterAsAccompanied(
          novel.url,
          chapters[4].url,
        );

        // 验证状态
        expect(
          await testBase.databaseService.isChapterAccompanied(
            novel.url,
            chapters[0].url,
          ),
          true,
        );
        expect(
          await testBase.databaseService.isChapterAccompanied(
            novel.url,
            chapters[1].url,
          ),
          false,
        );
        expect(
          await testBase.databaseService.isChapterAccompanied(
            novel.url,
            chapters[2].url,
          ),
          true,
        );
        expect(
          await testBase.databaseService.isChapterAccompanied(
            novel.url,
            chapters[3].url,
          ),
          false,
        );
        expect(
          await testBase.databaseService.isChapterAccompanied(
            novel.url,
            chapters[4].url,
          ),
          true,
        );
      });
    });
  });
}

/// 测试基类实现
class _AITestBase extends DatabaseTestBase {}
