import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel_export_data.dart';

void main() {
  group('Sync Download Chapter Order Bug', () {
    test('章节导入应保持服务器返回的顺序', () {
      // 模拟服务器返回的章节数据（顺序已打乱或新增）
      final serverChapters = [
        ChapterExportData(
          title: '第一章',
          url: 'https://example.com/chapter/1',
          content: '内容1',
          chapterIndex: 1,
          isUserInserted: false,
        ),
        ChapterExportData(
          title: '第二章',
          url: 'https://example.com/chapter/2',
          content: '内容2',
          chapterIndex: 2,
          isUserInserted: false,
        ),
        ChapterExportData(
          title: '新章节',
          url: 'https://example.com/chapter/new',
          content: '新内容',
          chapterIndex: 3,
          isUserInserted: false,
        ),
        ChapterExportData(
          title: '第三章',
          url: 'https://example.com/chapter/3',
          content: '内容3',
          chapterIndex: 4,
          isUserInserted: false,
        ),
      ];

      // 转换为 Chapter 列表
      final chapterList = serverChapters.map((data) => data.toChapter()).toList();

      // 验证：列表顺序应与服务器返回顺序一致
      expect(chapterList.length, equals(4));
      expect(chapterList[0].title, equals('第一章'));
      expect(chapterList[1].title, equals('第二章'));
      expect(chapterList[2].title, equals('新章节'));
      expect(chapterList[3].title, equals('第三章'));
    });

    test('章节 chapterIndex 应正确反映列表位置', () {
      final chapters = [
        ChapterExportData(
          title: '第A章',
          url: 'https://example.com/a',
          content: 'A',
          chapterIndex: 100, // 服务器可能有不连续的 index
          isUserInserted: false,
        ),
        ChapterExportData(
          title: '第B章',
          url: 'https://example.com/b',
          content: 'B',
          chapterIndex: 200,
          isUserInserted: false,
        ),
        ChapterExportData(
          title: '第C章',
          url: 'https://example.com/c',
          content: 'C',
          chapterIndex: 300,
          isUserInserted: false,
        ),
      ];

      final chapterList = chapters.map((data) => data.toChapter()).toList();

      // 验证 chapterIndex 保留了原始值
      expect(chapterList[0].chapterIndex, equals(100));
      expect(chapterList[1].chapterIndex, equals(200));
      expect(chapterList[2].chapterIndex, equals(300));
    });

    test('批量导入 vs 逐个导入的 chapterIndex 差异', () {
      // 模拟 cacheNovelChapters 的行为
      // 正确方式：一次性导入所有章节
      final chapters = [
        Chapter(title: 'A', url: 'a', chapterIndex: 0),
        Chapter(title: 'B', url: 'b', chapterIndex: 1),
        Chapter(title: 'C', url: 'c', chapterIndex: 2),
      ];

      // 模拟 cacheNovelChapters 中的 for 循环逻辑
      // for (var i = 0; i < chapters.length; i++) {
      //   INSERT ... chapterIndex = i
      // }
      final assignedIndices = <int>[];
      for (var i = 0; i < chapters.length; i++) {
        assignedIndices.add(i); // 正确：0, 1, 2
      }

      expect(assignedIndices, equals([0, 1, 2]));

      // 错误方式：逐个导入（每次只有一个章节，i 永远是 0）
      final wrongIndices = <int>[];
      for (final chapter in chapters) {
        // 错误：每次调用 cacheNovelChapters(novelUrl, [chapter])
        // 内部 for 循环只有一个元素，i 永远是 0
        for (var i = 0; i < 1; i++) {
          wrongIndices.add(i); // 错误：0, 0, 0
        }
      }

      expect(wrongIndices, equals([0, 0, 0])); // 这就是 bug 的根源！
    });
  });
}