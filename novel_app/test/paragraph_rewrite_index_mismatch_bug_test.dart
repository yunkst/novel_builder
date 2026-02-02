import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/paragraph_replace_helper.dart';

/// 段落改写功能Bug复现 - 索引不匹配问题
///
/// Bug根源：UI层过滤空段落，但传入Dialog的是原始内容（包含空行）
/// 导致索引不匹配，替换了错误的段落
void main() {
  group('Bug复现：索引不匹配问题', () {
    test('场景1：原始内容包含空行', () {
      // 模拟真实的章节内容（包含空行）
      const rawContent = '''第一章 开始

夜幕降临，繁华的城市渐渐安静下来。

街道上的霓虹灯依旧闪烁，但行人已经稀少。

她独自走在回家的路上。''';

      print('\n=== Bug场景：原始内容包含空行 ===');
      print('原始内容:');
      print(rawContent);
      print('\n原始段落（split("\\n")）:');
      final rawParagraphs = rawContent.split('\n');
      for (int i = 0; i < rawParagraphs.length; i++) {
        print('  [$i] "${rawParagraphs[i]}"');
      }

      // reader_screen.dart 会过滤空段落
      final filteredParagraphs = rawParagraphs.where((p) => p.trim().isNotEmpty).toList();
      print('\n过滤后段落（UI显示）:');
      for (int i = 0; i < filteredParagraphs.length; i++) {
        print('  [$i] "${filteredParagraphs[i]}"');
      }

      // 用户在UI上看到的索引和实际索引不匹配！
      // 例如：用户点击UI上的索引2（"夜幕降临..."）
      // 但在原始内容中，这是索引1

      print('\n⚠️ 索引不匹配问题：');
      print('  UI索引2 → "${filteredParagraphs[2]}"');
      print('  原始索引? → "${rawParagraphs[2]}" (是空行!)');
      print('  原始索引3 → "${rawParagraphs[3]}" (这才是UI索引2)');

      // 如果用户选择了UI上的索引[1, 2]（"夜幕降临..." 和 "街道上的..."）
      // 传给Dialog的索引是[1, 2]
      // 但Dialog使用rawContent.split('\n')，索引1是空行，索引2是"夜幕降临..."

      const selectedIndices = [1, 2]; // 这是UI传递的索引
      const aiGeneratedContent = ['改写段落1', '改写段落2'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: rawContent, // Dialog接收的是原始内容
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      print('\n替换结果:');
      final resultParagraphs = result.split('\n');
      for (int i = 0; i < resultParagraphs.length; i++) {
        print('  [$i] "${resultParagraphs[i]}"');
      }

      print('\n❌ 问题：用户期望替换"夜幕降临..."和"街道上的..."');
      print('   实际替换了空行和"夜幕降临..."');
      print('   索引完全不匹配！');

      // 验证Bug
      expect(resultParagraphs[1], isNot(equals('改写段落1')),
          reason: '这个测试会失败，证明Bug存在');
    });

    test('场景2：连续空行', () {
      const rawContent = '''第一段

第二段


第三段

第四段''';

      print('\n=== Bug场景：连续空行 ===');
      final rawParagraphs = rawContent.split('\n');
      final filteredParagraphs = rawContent.split('\n').where((p) => p.trim().isNotEmpty).toList();

      print('原始段落数: ${rawParagraphs.length}');
      print('过滤后段落数: ${filteredParagraphs.length}');
      print('索引偏移量: ${rawParagraphs.length - filteredParagraphs.length}');

      // 用户在UI上选择索引[1, 2]（第二段和第三段）
      // 传递给Dialog的索引是[1, 2]
      // 但实际原始内容中，第二段在索引2，第三段在索引5！

      print('\n索引映射:');
      print('  UI索引0 → 原始索引0 ("第一段")');
      print('  UI索引1 → 原始索引2 ("第二段") ← 跳过了索引1的空行');
      print('  UI索引2 → 原始索引5 ("第三段") ← 跳过了索引3、4的空行');
      print('  UI索引3 → 原始索引7 ("第四段") ← 跳过了索引6的空行');

      const selectedIndices = [1, 2]; // UI传递的索引

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: rawContent,
        selectedIndices: selectedIndices,
        newContent: ['X', 'Y'],
      );

      final resultParagraphs = result.split('\n');
      print('\n替换结果:');
      for (int i = 0; i < resultParagraphs.length; i++) {
        print('  [$i] "${resultParagraphs[i]}"');
      }

      print('\n❌ Bug：替换了索引1、2（空行和"第二段"）');
      print('   用户期望替换索引2、5（"第二段"和"第三段"）');
    });

    test('场景3：段落前有空行', () {
      const rawContent = '''第一章

这是第一段内容。

这是第二段内容。''';

      print('\n=== Bug场景：段落前有空行 ===');
      final rawParagraphs = rawContent.split('\n');
      final filteredParagraphs = rawContent.split('\n').where((p) => p.trim().isNotEmpty).toList();

      print('用户看到的段落（过滤空行）:');
      filteredParagraphs.asMap().forEach((i, p) => print('  [$i] $p'));

      // 用户选择UI上的索引[1]（"这是第一段内容"）
      const uiSelectedIndex = 1;

      print('\n用户选择UI索引[$uiSelectedIndex]: "${filteredParagraphs[uiSelectedIndex]}"');

      // 但传递给Dialog的索引是[1]
      // Dialog使用原始内容split，索引1是空行！

      print('\n实际替换原始索引[$uiSelectedIndex]: "${rawParagraphs[uiSelectedIndex]}"');
      print('这是一个空行！用户期望的"这是第一段内容"在原始索引2！');

      const selectedIndices = [1];
      const aiGeneratedContent = ['改写后的段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: rawContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');
      print('\n替换结果:');
      resultParagraphs.asMap().forEach((i, p) => print('  [$i] "$p"'));

      print('\n❌ Bug：用户期望替换"这是第一段内容"');
      print('   实际替换了空行');
      print('   "这是第一段内容"没有被替换！');
    });
  });

  group('修复验证', () {
    test('修复方案：传递过滤后的段落列表', () {
      const rawContent = '''第一章 开始

夜幕降临，繁华的城市渐渐安静下来。

街道上的霓虹灯依旧闪烁。''';

      print('\n=== 修复方案 ===');
      print('1. reader_screen.dart 应该传递过滤后的段落给 Dialog');
      print('2. 或者 Dialog 内部使用过滤后的段落');

      // 模拟修复：使用过滤后的段落
      final filteredParagraphs = rawContent.split('\n').where((p) => p.trim().isNotEmpty).toList();
      final filteredContent = filteredParagraphs.join('\n');

      print('\n过滤后内容:');
      print(filteredContent);

      // 现在索引是正确的
      const selectedIndices = [1]; // UI索引1
      const aiGeneratedContent = ['改写后的段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent, // 使用过滤后的内容
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');
      print('\n替换结果:');
      resultParagraphs.asMap().forEach((i, p) => print('  [$i] "$p"'));

      print('\n✅ 修复成功：正确替换了"夜幕降临..."');

      expect(resultParagraphs[1], equals('改写后的段落'));
    });
  });
}
