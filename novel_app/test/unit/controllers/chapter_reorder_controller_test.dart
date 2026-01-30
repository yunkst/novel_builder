import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/controllers/chapter_list/chapter_reorder_controller.dart';
import 'package:novel_app/models/chapter.dart';
import '../../base/database_test_base.dart';

/// 测试基类
class _ChapterReorderTestBase extends DatabaseTestBase {}

/// ChapterReorderController 单元测试
void main() {
  group('ChapterReorderController', () {
    late ChapterReorderController controller;
    late _ChapterReorderTestBase base;

    setUp(() async {
      base = _ChapterReorderTestBase();
      await base.setUp();

      controller = ChapterReorderController(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('onReorder should move chapter forward', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 5,
      );

      final result = controller.onReorder(
        oldIndex: 0,
        newIndex: 3,
        chapters: chapters,
      );

      // 当从0移到3时，实际是移到索引2（因为oldIndex < newIndex）
      expect(result[0].title, '第二章'); // 原索引1的章节现在在索引0
      expect(result[1].title, '第三章'); // 原索引2的章节现在在索引1
      expect(result[2].title, '第一章'); // 原索引0的章节移到索引2
      expect(result[3].title, '第四章'); // 原索引3的章节现在在索引3
      expect(result[4].title, '第五章'); // 原索引4的章节现在在索引4
    });

    test('onReorder should move chapter backward', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 5,
      );

      final result = controller.onReorder(
        oldIndex: 4,
        newIndex: 1,
        chapters: chapters,
      );

      expect(result[1].title, '第五章'); // 原索引4的章节移到索引1
    });

    test('onReorder should handle adjacent indices', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      final result = controller.onReorder(
        oldIndex: 1,
        newIndex: 0,
        chapters: chapters,
      );

      expect(result[0].title, '第二章');
      expect(result[1].title, '第一章');
    });

    test('saveReorderedChapters should update database', () async {
      final novel = await base.createAndAddNovel();
      await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 5,
      );

      // 获取初始章节
      final chapters = await base.databaseService.getChapters(novel.url);

      // 保存原始章节列表用于验证
      final originalChapters = List<Chapter>.from(chapters);

      // 执行重排序(将第0章移到第2章位置)
      // 因为oldIndex(0) < newIndex(2),所以实际移到索引1
      final reordered = controller.onReorder(
        oldIndex: 0,
        newIndex: 2,
        chapters: chapters,
      );

      // 保存重排后的顺序
      await controller.saveReorderedChapters(
        novelUrl: novel.url,
        chapters: reordered,
      );

      // 验证: 重新获取章节,检查顺序和索引
      // 重排序后: [原1, 原0, 原2, 原3, 原4]
      final updated = await base.databaseService.getChapters(novel.url);

      expect(updated[0].url, originalChapters[1].url);
      expect(updated[0].chapterIndex, 0);
      expect(updated[1].url, originalChapters[0].url);
      expect(updated[1].chapterIndex, 1);
      expect(updated[2].url, originalChapters[2].url);
      expect(updated[2].chapterIndex, 2);
      expect(updated[3].url, originalChapters[3].url);
      expect(updated[3].chapterIndex, 3);
      expect(updated[4].url, originalChapters[4].url);
      expect(updated[4].chapterIndex, 4);
    });

    test('saveReorderedChapters should handle boundary reordering', () async {
      final novel = await base.createAndAddNovel();
      await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      // 获取初始章节
      final chapters = await base.databaseService.getChapters(novel.url);

      // 保存原始章节列表用于验证
      final originalChapters = List<Chapter>.from(chapters);

      // 移动最后一章到最前
      // oldIndex: 2, newIndex: 0, 因为oldIndex > newIndex,所以adjustedIndex = 0
      // 结果: [原2, 原0, 原1]
      final reordered = controller.onReorder(
        oldIndex: 2,
        newIndex: 0,
        chapters: chapters,
      );

      await controller.saveReorderedChapters(
        novelUrl: novel.url,
        chapters: reordered,
      );

      // 验证所有章节索引都已更新
      final updated = await base.databaseService.getChapters(novel.url);

      expect(updated[0].url, originalChapters[2].url);
      expect(updated[0].chapterIndex, 0);
      expect(updated[1].url, originalChapters[0].url);
      expect(updated[1].chapterIndex, 1);
      expect(updated[2].url, originalChapters[1].url);
      expect(updated[2].chapterIndex, 2);
    });

    test('saveReorderedChapters should persist across queries', () async {
      final novel = await base.createAndAddNovel();
      await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 4,
      );

      // 获取初始章节
      final chapters = await base.databaseService.getChapters(novel.url);

      // 重排序: 将第1章移到最后
      final reordered = controller.onReorder(
        oldIndex: 1,
        newIndex: 4,
        chapters: chapters,
      );

      // 保存重排结果
      await controller.saveReorderedChapters(
        novelUrl: novel.url,
        chapters: reordered,
      );

      // 多次查询验证顺序保持一致
      final firstQuery = await base.databaseService.getChapters(novel.url);
      final secondQuery = await base.databaseService.getChapters(novel.url);

      expect(firstQuery.length, equals(secondQuery.length));

      for (int i = 0; i < firstQuery.length; i++) {
        expect(firstQuery[i].url, equals(secondQuery[i].url));
        expect(firstQuery[i].chapterIndex, equals(i));
        expect(secondQuery[i].chapterIndex, equals(i));
      }
    });
  });
}
