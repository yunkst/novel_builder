/// ParagraphReplaceHelper 段落替换工具单元测试
///
/// 验证段落替换的核心逻辑：
/// - 正常替换（单段/多段）
/// - 边界条件（空列表、越界索引）
/// - executeReplaceAndJoin 文本拼接
/// - filterValidIndices 过滤
/// - calculateNewLength 计算
/// - validateReplacement 验证
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/paragraph_replace_helper_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/paragraph_replace_helper.dart';

void main() {
  group('ParagraphReplaceHelper', () {
    group('executeReplace', () {
      test('应替换单个段落', () {
        final paragraphs = ['第一段', '第二段', '第三段'];
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [1],
          newContent: ['改写段'],
        );

        expect(result, ['第一段', '改写段', '第三段']);
      });

      test('应替换多个连续段落', () {
        final paragraphs = ['A', 'B', 'C', 'D', 'E'];
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [1, 2, 3],
          newContent: ['新内容'],
        );

        expect(result, ['A', '新内容', 'E']);
      });

      test('应替换多个不连续段落', () {
        final paragraphs = ['A', 'B', 'C', 'D', 'E'];
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [1, 3],
          newContent: ['新内容'],
        );

        expect(result, ['A', '新内容', 'C', 'E']);
      });

      test('应插入多段新内容', () {
        final paragraphs = ['A', 'B', 'C'];
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [1],
          newContent: ['新1', '新2', '新3'],
        );

        expect(result, ['A', '新1', '新2', '新3', 'C']);
      });

      test('空段落列表应返回原列表', () {
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: [],
          selectedIndices: [0],
          newContent: ['新内容'],
        );

        expect(result, []);
      });

      test('空索引列表应返回原列表副本', () {
        final paragraphs = ['A', 'B', 'C'];
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [],
          newContent: ['新内容'],
        );

        expect(result, ['A', 'B', 'C']);
        expect(identical(result, paragraphs), isFalse); // 应为副本
      });

      test('越界索引应被过滤', () {
        final paragraphs = ['A', 'B', 'C'];
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [1, 999, -1],
          newContent: ['新内容'],
        );

        expect(result, ['A', '新内容', 'C']);
      });

      test('全部索引无效时应返回原列表', () {
        final paragraphs = ['A', 'B'];
        final result = ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [999, -1],
          newContent: ['新内容'],
        );

        expect(result, ['A', 'B']);
      });

      test('不应修改原列表', () {
        final paragraphs = ['A', 'B', 'C'];
        ParagraphReplaceHelper.executeReplace(
          paragraphs: paragraphs,
          selectedIndices: [1],
          newContent: ['新内容'],
        );

        // 原列表应保持不变
        expect(paragraphs, ['A', 'B', 'C']);
      });
    });

    group('executeReplaceAndJoin', () {
      test('应替换并拼接为文本', () {
        final result = ParagraphReplaceHelper.executeReplaceAndJoin(
          content: '第一段\n第二段\n第三段',
          selectedIndices: [1],
          newContent: ['改写段'],
        );

        expect(result, '第一段\n改写段\n第三段');
      });

      test('单行内容替换', () {
        final result = ParagraphReplaceHelper.executeReplaceAndJoin(
          content: '唯一段落',
          selectedIndices: [0],
          newContent: ['改写后'],
        );

        expect(result, '改写后');
      });
    });

    group('filterValidIndices', () {
      test('应过滤越界索引', () {
        final result =
            ParagraphReplaceHelper.filterValidIndices([0, 1, 5, -1, 2], 3);

        expect(result, [0, 1, 2]);
      });

      test('全部有效时应全部保留', () {
        final result =
            ParagraphReplaceHelper.filterValidIndices([0, 1, 2], 3);

        expect(result, [0, 1, 2]);
      });

      test('全部无效时应返回空列表', () {
        final result =
            ParagraphReplaceHelper.filterValidIndices([5, 6, -1], 3);

        expect(result, []);
      });
    });

    group('calculateNewLength', () {
      test('应正确计算新长度', () {
        expect(
          ParagraphReplaceHelper.calculateNewLength(
            originalLength: 10,
            deletedCount: 3,
            insertedCount: 5,
          ),
          12,
        );
      });

      test('删除和插入数量相同时长度不变', () {
        expect(
          ParagraphReplaceHelper.calculateNewLength(
            originalLength: 10,
            deletedCount: 2,
            insertedCount: 2,
          ),
          10,
        );
      });
    });

    group('validateReplacement', () {
      test('应验证替换完整性', () {
        final original = ['A', 'B', 'C', 'D'];
        final updated = ['A', '新内容', 'D'];
        final result = ParagraphReplaceHelper.validateReplacement(
          originalParagraphs: original,
          updatedParagraphs: updated,
          selectedIndices: [1, 2],
        );

        expect(result.isValid, isTrue);
        expect(result.message, '替换验证通过');
      });

      test('应检测丢失的段落', () {
        final original = ['A', 'B', 'C', 'D'];
        final updated = ['新内容', 'D']; // A 丢失了
        final result = ParagraphReplaceHelper.validateReplacement(
          originalParagraphs: original,
          updatedParagraphs: updated,
          selectedIndices: [1, 2],
        );

        expect(result.isValid, isFalse);
        expect(result.message, contains('丢失'));
      });
    });
  });
}
