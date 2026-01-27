import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/paragraph_replace_helper.dart';

/// 测试从Dify返回内容到执行替换的完整逻辑
void main() {
  group('Dify返回内容后的替换逻辑测试', () {
    test('完整流程：Dify返回内容 -> 点击替换 -> 执行删除插入', () {
      // 模拟场景：
      // 1. 原文：5段
      // 2. 用户选中：第2、3、4段（索引1,2,3）
      // 3. Dify返回：3段改写内容
      // 4. 用户点击"替换"按钮
      // 5. 执行：删除索引1,2,3，在位置1插入3段新内容

      final originalContent = '第一段\n第二段\n第三段\n第四段\n第五段';
      final selectedIndices = [1, 2, 3];
      final difyResponse = '改写第一段\n改写第二段\n改写第三段';

      // 步骤1: 分割原文
      final paragraphs = originalContent.split('\n');
      expect(paragraphs.length, 5);

      // 步骤2: 分割Dify返回内容
      final rewrittenParagraphs = difyResponse.split('\n');
      expect(rewrittenParagraphs.length, 3);

      // 步骤3: 执行替换（使用工具类）
      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 步骤4: 验证结果
      expect(result.length, 5); // 5 - 3 + 3 = 5
      expect(result[0], '第一段'); // 第一段保留
      expect(result[1], '改写第一段'); // 改写内容插入
      expect(result[2], '改写第二段');
      expect(result[3], '改写第三段');
      expect(result[4], '第五段'); // 第五段保留

      // 步骤5: 重新组合为完整内容
      final newContent = result.join('\n');
      expect(newContent, '第一段\n改写第一段\n改写第二段\n改写第三段\n第五段');

      debugPrint('✅ 完整流程测试通过：Dify返回 -> 替换 -> 新内容生成');
    });

    test('场景：Dify返回更多段落', () {
      // 原文3段，选中1段，Dify返回5段
      final originalContent = '第一段\n第二段\n第三段';
      final selectedIndices = [1];
      final difyResponse = '改写1\n改写2\n改写3\n改写4\n改写5';

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 3 - 1 + 5 = 7段
      expect(result.length, 7);
      expect(result[0], '第一段');
      expect(result[1], '改写1');
      expect(result[5], '改写5');
      expect(result[6], '第三段');

      debugPrint('✅ Dify返回更多段落测试通过');
    });

    test('场景：Dify返回更少段落', () {
      // 原文5段，选中3段，Dify返回1段
      final originalContent = '第一段\n第二段\n第三段\n第四段\n第五段';
      final selectedIndices = [1, 2, 3];
      final difyResponse = '改写段';

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 5 - 3 + 1 = 3段
      expect(result.length, 3);
      expect(result, ['第一段', '改写段', '第五段']);

      debugPrint('✅ Dify返回更少段落测试通过');
    });

    test('场景：Dify返回空内容', () {
      // 原文3段，选中1段，Dify返回空
      final originalContent = '第一段\n第二段\n第三段';
      final selectedIndices = [1];
      final difyResponse = ''; // 空内容

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      // 空字符串split会返回['']
      expect(rewrittenParagraphs.length, 1);
      expect(rewrittenParagraphs[0], '');

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 3 - 1 + 1 = 3段（包含一个空字符串）
      expect(result.length, 3);
      expect(result[0], '第一段');
      expect(result[1], ''); // 空段落
      expect(result[2], '第三段');

      debugPrint('✅ Dify返回空内容测试通过');
    });

    test('场景：Dify返回相同数量段落', () {
      // 原文5段，选中3段，Dify返回3段
      final originalContent = '第一段\n第二段\n第三段\n第四段\n第五段';
      final selectedIndices = [1, 2, 3];
      final difyResponse = '改写1\n改写2\n改写3';

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 5 - 3 + 3 = 5段（总数不变）
      expect(result.length, 5);
      expect(result, ['第一段', '改写1', '改写2', '改写3', '第五段']);

      debugPrint('✅ Dify返回相同数量测试通过');
    });

    test('边界：Dify返回包含空行', () {
      // Dify返回的内容可能包含空行
      final originalContent = '第一段\n第二段\n第三段';
      final selectedIndices = [1];
      final difyResponse = '改写1\n\n改写2'; // 中间有空行

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      expect(rewrittenParagraphs.length, 3);
      expect(rewrittenParagraphs[1], ''); // 空行

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 3 - 1 + 3 = 5段
      expect(result.length, 5);
      expect(result, ['第一段', '改写1', '', '改写2', '第三段']);

      final newContent = result.join('\n');
      expect(newContent, '第一段\n改写1\n\n改写2\n第三段');

      debugPrint('✅ Dify返回包含空行测试通过');
    });

    test('边界：Dify返回内容有首尾空格', () {
      // Dify返回的内容可能有首尾空格
      final originalContent = '第一段\n第二段\n第三段';
      final selectedIndices = [1];
      final difyResponse = '  改写段  '; // 有空格

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      // 注意：split不会自动trim，需要手动处理
      final trimmedParagraphs = rewrittenParagraphs
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: trimmedParagraphs,
      );

      expect(result, ['第一段', '改写段', '第三段']);

      debugPrint('✅ Dify返回内容有首尾空格测试通过');
    });

    test('数据验证：替换前后内容完整性', () {
      // 验证未选中的段落是否保留
      final originalContent = 'A段\nB段\nC段\nD段\nE段';
      final selectedIndices = [1, 3]; // 选中B和D
      final difyResponse = '新1\n新2';

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 验证：A、C、E段应该保留
      expect(result.contains('A段'), true);
      expect(result.contains('B段'), false); // 被删除
      expect(result.contains('C段'), true);
      expect(result.contains('D段'), false); // 被删除
      expect(result.contains('E段'), true);

      // 验证：新内容应该存在
      expect(result.contains('新1'), true);
      expect(result.contains('新2'), true);

      debugPrint('✅ 数据完整性验证通过');
    });

    test('性能：大章节内容替换', () {
      // 模拟大章节：100段
      final largeContent = List.generate(100, (i) => '第${i + 1}段').join('\n');
      final selectedIndices = [10, 11, 12, 13, 14]; // 选中5段
      final difyResponse = List.generate(3, (i) => '改写${i + 1}').join('\n');

      final paragraphs = largeContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      final stopwatch = Stopwatch()..start();
      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );
      stopwatch.stop();

      // 验证结果
      expect(result.length, 98); // 100 - 5 + 3 = 98
      expect(result[0], '第1段');
      expect(result[10], '改写1');
      expect(result[12], '改写3');
      expect(result[97], '第100段');

      // 验证性能（应该很快）
      expect(stopwatch.elapsedMilliseconds, lessThan(10));

      debugPrint('✅ 大章节性能测试通过: ${stopwatch.elapsedMilliseconds}ms');
    });
  });

  group('特殊情况处理', () {
    test('特殊情况：选中包含空行的段落', () {
      final content = '第一段\n\n第三段'; // 第二行是空行
      final selectedIndices = [1]; // 选中空行
      final difyResponse = '改写段';

      final paragraphs = content.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      expect(result, ['第一段', '改写段', '第三段']);

      debugPrint('✅ 选中空行段落测试通过');
    });

    test('特殊情况：Dify返回只有空格', () {
      final content = '第一段\n第二段\n第三段';
      final selectedIndices = [1];
      final difyResponse = '   '; // 只有空格

      final paragraphs = content.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      // 处理：过滤掉纯空格的段落
      final filteredParagraphs = rewrittenParagraphs
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: filteredParagraphs.isEmpty ? [''] : filteredParagraphs,
      );

      // 由于过滤后为空，会插入一个空字符串
      expect(result.length, 3);
      expect(result[1], '');

      debugPrint('✅ Dify返回只有空格测试通过');
    });
  });

  group('日志验证测试', () {
    test('验证：替换过程的日志输出', () {
      final originalContent = '第一段\n第二段\n第三段';
      final selectedIndices = [1];
      final difyResponse = '改写段';

      final paragraphs = originalContent.split('\n');
      final rewrittenParagraphs = difyResponse.split('\n');

      // 模拟日志输出
      final logs = <String>[];

      // 模拟准备替换日志
      logs.add('📝 准备替换: 删除 ${selectedIndices.length} 段，插入 ${rewrittenParagraphs.length} 段');

      // 执行替换
      final result = ParagraphReplaceHelper.executeReplace(
        paragraphs: paragraphs,
        selectedIndices: selectedIndices,
        newContent: rewrittenParagraphs,
      );

      // 验证日志内容
      expect(logs.first, '📝 准备替换: 删除 1 段，插入 1 段');

      // 验证替换结果
      expect(result, ['第一段', '改写段', '第三段']);

      debugPrint('✅ 日志验证测试通过');
    });
  });
}
