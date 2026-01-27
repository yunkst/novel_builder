import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/paragraph_replace_helper.dart';

void main() {
  group('段落替换逻辑核心测试', () {
    test('基础替换：删除选中段落并插入新内容', () {
      // 场景：原文5段，选中3段，AI生成5段
      final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段'];
      final selectedIndices = [1, 2, 3]; // 选中第二、三、四段
      final aiContent = ['改写1', '改写2', '改写3', '改写4', '改写5'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result.length, 7, reason: '5 - 3 + 5 = 7');
      expect(result[0], '第一段', reason: '第一段应该保留');
      expect(result[1], '改写1', reason: '插入位置应该从改写1开始');
      expect(result[5], '改写5', reason: '最后一段改写内容');
      expect(result[6], '第五段', reason: '原文最后一段应该保留');
    });

    test('AI生成更少段落', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段'];
      final selectedIndices = [1, 2, 3];
      final aiContent = ['改写1', '改写2'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result.length, 4, reason: '5 - 3 + 2 = 4');
      expect(result, ['第一段', '改写1', '改写2', '第五段']);
    });

    test('AI生成相同数量段落', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段'];
      final selectedIndices = [1, 2, 3];
      final aiContent = ['改写1', '改写2', '改写3'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result.length, 5, reason: '5 - 3 + 3 = 5');
      expect(result, ['第一段', '改写1', '改写2', '改写3', '第五段']);
    });

    test('空内容处理：AI生成空数组', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [1];
      final aiContent = <String>[];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result.length, 2, reason: '3 - 1 + 0 = 2');
      expect(result, ['第一段', '第三段']);
    });

    test('边界情况：索引越界保护', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [0, 1, 100]; // 索引100超出范围
      final aiContent = ['改写1'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      // 应该自动过滤掉无效索引100
      expect(result.length, 2, reason: '只处理有效索引0和1');
      expect(result[0], '改写1');
      expect(result[1], '第三段');
    });

    test('边界情况：所有索引都无效', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [100, 200, 300]; // 全部超出范围
      final aiContent = ['改写1'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      // 应该不进行任何替换
      expect(result, paragraphs);
    });

    test('特殊情况：选中不连续段落', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段', '第六段'];
      final selectedIndices = [1, 3, 5]; // 第二段、第四段、第六段
      final aiContent = ['改写1', '改写2', '改写3'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      // 预期：删除索引1,3,5，然后在索引1位置插入3段改写内容
      expect(result.length, 6);
      expect(result[0], '第一段');
      expect(result[1], '改写1');
      expect(result[2], '改写2');
      expect(result[3], '改写3');
      expect(result[4], '第三段');
      expect(result[5], '第五段');
    });

    test('数据验证：替换后完整性检查', () {
      final originalContent = '第一段\n第二段\n第三段\n第四段\n第五段';
      final paragraphs = originalContent.split('\n');
      final selectedIndices = [1, 2, 3];
      final aiContent = ['改写A', '改写B'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      final newContent = result.join('\n');

      // 验证：保留的段落应该存在
      expect(newContent.contains('第一段'), true);
      expect(newContent.contains('第五段'), true);

      // 验证：被删除的段落不应该存在
      expect(newContent.contains('第二段'), false);
      expect(newContent.contains('第三段'), false);
      expect(newContent.contains('第四段'), false);

      // 验证：新内容应该存在
      expect(newContent.contains('改写A'), true);
      expect(newContent.contains('改写B'), true);
    });

    test('边界情况：只选一段', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [1];
      final aiContent = ['改写1'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result, ['第一段', '改写1', '第三段']);
    });

    test('边界情况：选中所有段落', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [0, 1, 2];
      final aiContent = ['改写1', '改写2', '改写3', '改写4'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result.length, 4);
      expect(result, aiContent);
    });

    test('边界情况：选中第一段', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段'];
      final selectedIndices = [0];
      final aiContent = ['改写1', '改写2'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result.length, 5);
      expect(result[0], '改写1');
      expect(result[1], '改写2');
      expect(result[2], '第二段');
    });

    test('边界情况：选中最后一段', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段'];
      final selectedIndices = [3];
      final aiContent = ['改写1'];

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      expect(result.length, 4);
      expect(result[0], '第一段');
      expect(result[1], '第二段');
      expect(result[2], '第三段');
      expect(result[3], '改写1');
    });
  });

  group('ParagraphReplaceHelper 工具方法测试', () {
    test('executeReplaceAndJoin - 便捷方法', () {
      final content = '第一段\n第二段\n第三段';
      final selectedIndices = [1];
      final newContent = ['改写段'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: content,
        selectedIndices: selectedIndices,
        newContent: newContent,
      );

      expect(result, '第一段\n改写段\n第三段');
    });

    test('filterValidIndices - 过滤有效索引', () {
      final indices = [0, 1, 100, -1, 2];
      final valid = ParagraphReplaceHelper.filterValidIndices(indices, 3);

      expect(valid, [0, 1, 2]);
      expect(valid.contains(100), false);
      expect(valid.contains(-1), false);
    });

    test('calculateNewLength - 计算新长度', () {
      final newLength = ParagraphReplaceHelper.calculateNewLength(
        originalLength: 10,
        deletedCount: 3,
        insertedCount: 5,
      );

      expect(newLength, 12); // 10 - 3 + 5 = 12
    });

    test('validateReplacement - 验证替换完整性', () {
      final original = ['第一段', '第二段', '第三段'];
      final updated = ['第一段', '改写段', '第三段'];
      final indices = [1];

      final result = ParagraphReplaceHelper.validateReplacement(
        originalParagraphs: original,
        updatedParagraphs: updated,
        selectedIndices: indices,
      );

      expect(result.isValid, true);
      expect(result.message, contains('通过'));
    });

    test('validateReplacement - 检测内容丢失', () {
      final original = ['第一段', '第二段', '第三段'];
      final updated = ['第一段', '改写段']; // 第三段丢失
      final indices = [1];

      final result = ParagraphReplaceHelper.validateReplacement(
        originalParagraphs: original,
        updatedParagraphs: updated,
        selectedIndices: indices,
      );

      expect(result.isValid, false);
      expect(result.message, contains('意外丢失'));
    });
  });
}

