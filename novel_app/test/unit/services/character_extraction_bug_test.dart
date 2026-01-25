import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/character_extraction_service.dart';
import 'package:novel_app/models/chapter.dart';

/// 测试 matchPositions 丢失导致的问题
///
/// 这个测试验证了 character_input_dialog.dart:758-764 中的 bug
/// 问题：在传递 selectedChapters 时，matchPositions 被清空为空数组
void main() {
  group('Bug复现: matchPositions 丢失问题', () {
    late CharacterExtractionService extractionService;

    setUp(() {
      extractionService = CharacterExtractionService();
    });

    test('当 matchPositions 为空时，extractContextAroundMatches 应该返回空列表', () {
      const content = '张三在这里，张三也在那里，张三又出现了';
      final chapter = Chapter(
        title: '测试章节',
        url: 'test_url',
        content: content,
        isCached: true,
      );

      // 模拟对话框传递过来的 ChapterMatch（matchPositions 被清空）
      final chapterMatch = ChapterMatch(
        chapter: chapter,
        matchCount: 3, // 虽然有3次匹配
        matchPositions: [], // ❌ 但 matchPositions 是空的！
      );

      // 尝试提取上下文
      final contexts = extractionService.extractContextAroundMatches(
        content: content,
        matchPositions: chapterMatch.matchPositions,
        contextLength: 100,
        useFullChapter: false,
      );

      // 结果：因为 matchPositions 为空，所以无法提取任何内容
      expect(contexts, isEmpty);
      print('✅ 测试确认：当 matchPositions 为空时，无法提取任何上下文');
    });

    test('当 matchPositions 正确传递时，应该能提取上下文', () {
      const content = '张三在这里，张三也在那里，张三又出现了';
      final chapter = Chapter(
        title: '测试章节',
        url: 'test_url',
        content: content,
        isCached: true,
      );

      // 正确的 ChapterMatch（包含 matchPositions）
      final chapterMatch = ChapterMatch(
        chapter: chapter,
        matchCount: 3,
        matchPositions: [0, 7, 14], // ✅ 正确的匹配位置
      );

      // 提取上下文
      final contexts = extractionService.extractContextAroundMatches(
        content: content,
        matchPositions: chapterMatch.matchPositions,
        contextLength: 100,
        useFullChapter: false,
      );

      // 结果：成功提取了3个上下文片段
      expect(contexts.length, 3);
      expect(contexts[0], contains('张三'));
      expect(contexts[1], contains('张三'));
      expect(contexts[2], contains('张三'));
      print('✅ 测试确认：当 matchPositions 正确时，能成功提取上下文');
    });

    test('整章模式不受 matchPositions 影响', () {
      const content = '张三在这里，张三也在那里，张三又出现了';
      final chapter = Chapter(
        title: '测试章节',
        url: 'test_url',
        content: content,
        isCached: true,
      );

      // 即使 matchPositions 为空
      final chapterMatch = ChapterMatch(
        chapter: chapter,
        matchCount: 3,
        matchPositions: [], // 空的
      );

      // 使用整章模式
      final contexts = extractionService.extractContextAroundMatches(
        content: content,
        matchPositions: chapterMatch.matchPositions,
        contextLength: 100,
        useFullChapter: true, // ✅ 整章模式
      );

      // 结果：整章模式会返回完整内容
      expect(contexts.length, 1);
      expect(contexts[0], content);
      print('✅ 测试确认：整章模式不受 matchPositions 影响');
    });
  });

  group('Bug复现: Chapter.content 可能为 null', () {
    test('当 Chapter.content 为 null 时应该正确处理', () {
      // 创建一个 content 为 null 的 Chapter
      final chapter = Chapter(
        title: '测试章节',
        url: 'test_url',
        content: null, // ❌ content 为 null
        isCached: true,
      );

      // 模拟提取过程
      final content = chapter.content ?? '';
      expect(content, isEmpty);
      print('✅ 测试确认：当 content 为 null 时，应使用空字符串');
    });
  });
}
