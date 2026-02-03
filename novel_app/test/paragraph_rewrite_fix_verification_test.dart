import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/paragraph_replace_helper.dart';

/// 段落改写功能修复验证测试
///
/// 验证修复方案：传递过滤后的内容可以解决索引不匹配问题
void main() {
  group('Bug修复验证', () {
    test('修复方案：传递过滤后的段落列表', () {
      // 模拟原始内容（包含空行）
      const rawContent = '''第一章 开始

夜幕降临，繁华的城市渐渐安静下来。

街道上的霓虹灯依旧闪烁，但行人已经稀少。

她独自走在回家的路上。''';

      print('\n=== 修复方案 ===');
      print('问题：UI层过滤空段落，用户看到的索引与原始内容不匹配');
      print('方案：在reader_screen.dart中传递过滤后的内容给Dialog');

      // 1. 模拟UI层过滤
      final rawParagraphs = rawContent.split('\n');
      print('\n原始段落数: ${rawParagraphs.length}');

      final filteredParagraphs =
          rawParagraphs.where((p) => p.trim().isNotEmpty).toList();
      print('过滤后段落数: ${filteredParagraphs.length}');

      // 2. 构建过滤后的内容
      final filteredContent = filteredParagraphs.join('\n');
      print('\n过滤后内容:');
      print(filteredContent);

      // 3. 用户选择UI上的索引[1, 2]（"夜幕降临..." 和 "街道上的..."）
      const selectedIndices = [1, 2]; // UI索引
      const aiGeneratedContent = ['改写段落1', '改写段落2'];

      print('\n用户选择的索引: $selectedIndices');
      print('选中的段落:');
      for (final index in selectedIndices) {
        print('  [$index] "${filteredParagraphs[index]}"');
      }

      // 4. 使用过滤后的内容执行替换（修复方案）
      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent, // 关键：使用过滤后的内容
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');
      print('\n替换结果:');
      for (int i = 0; i < resultParagraphs.length; i++) {
        print('  [$i] "${resultParagraphs[i]}"');
      }

      // 5. 验证修复成功
      expect(resultParagraphs[1], equals('改写段落1'),
          reason: '应该正确替换索引1的段落');
      expect(resultParagraphs[2], equals('改写段落2'),
          reason: '应该正确替换索引2的段落');

      print('\n✅ 修复成功：索引匹配，正确替换了用户选择的段落');
      print('   原始: "夜幕降临..." → 替换为: "改写段落1"');
      print('   原始: "街道上的..." → 替换为: "改写段落2"');
    });

    test('场景1：原始内容包含空行 - 修复后', () {
      const rawContent = '''第一章 开始

夜幕降临，繁华的城市渐渐安静下来。

街道上的霓虹灯依旧闪烁，但行人已经稀少。

她独自走在回家的路上。''';

      // 过滤空行
      final filteredContent =
          rawContent.split('\n').where((p) => p.trim().isNotEmpty).join('\n');

      // 用户选择UI索引[1, 2]
      const selectedIndices = [1, 2];
      const aiGeneratedContent = ['改写段落1', '改写段落2'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证替换正确
      expect(resultParagraphs[0], equals('第一章 开始'));
      expect(resultParagraphs[1], equals('改写段落1'));
      expect(resultParagraphs[2], equals('改写段落2'));
      expect(resultParagraphs[3], equals('她独自走在回家的路上。'));

      print('\n✅ 场景1修复成功：正确替换了"夜幕降临..."和"街道上的..."');
    });

    test('场景2：连续空行 - 修复后', () {
      const rawContent = '''第一段

第二段


第三段

第四段''';

      // 过滤空行
      final filteredContent =
          rawContent.split('\n').where((p) => p.trim().isNotEmpty).join('\n');

      // 用户选择UI索引[1, 2]（第二段和第三段）
      const selectedIndices = [1, 2];
      const aiGeneratedContent = ['X', 'Y'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证替换正确
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('X'));
      expect(resultParagraphs[2], equals('Y'));
      expect(resultParagraphs[3], equals('第四段'));

      print('\n✅ 场景2修复成功：正确替换了第二段和第三段');
    });

    test('场景3：段落前有空行 - 修复后', () {
      const rawContent = '''第一章

这是第一段内容。

这是第二段内容。''';

      // 过滤空行
      final filteredContent =
          rawContent.split('\n').where((p) => p.trim().isNotEmpty).join('\n');

      // 用户选择UI索引[1]（"这是第一段内容"）
      const selectedIndices = [1];
      const aiGeneratedContent = ['改写后的段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证替换正确
      expect(resultParagraphs[0], equals('第一章'));
      expect(resultParagraphs[1], equals('改写后的段落'));
      expect(resultParagraphs[2], equals('这是第二段内容。'));

      print('\n✅ 场景3修复成功：正确替换了"这是第一段内容"');
    });

    test('边界测试：单段落选择', () {
      const rawContent = '''第一段

第二段

第三段''';

      final filteredContent =
          rawContent.split('\n').where((p) => p.trim().isNotEmpty).join('\n');

      const selectedIndices = [1];
      const aiGeneratedContent = ['新第二段'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('新第二段'));
      expect(resultParagraphs[2], equals('第三段'));

      print('\n✅ 单段落替换成功');
    });

    test('边界测试：AI生成更多段落', () {
      const rawContent = '''第一段
第二段
第三段''';

      final filteredContent =
          rawContent.split('\n').where((p) => p.trim().isNotEmpty).join('\n');

      const selectedIndices = [1];
      const aiGeneratedContent = ['新1', '新2', '新3'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs.length, equals(5));
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('新1'));
      expect(resultParagraphs[2], equals('新2'));
      expect(resultParagraphs[3], equals('新3'));
      expect(resultParagraphs[4], equals('第三段'));

      print('\n✅ AI生成更多段落成功');
    });

    test('边界测试：AI生成更少段落', () {
      const rawContent = '''第一段
第二段
第三段
第四段''';

      final filteredContent =
          rawContent.split('\n').where((p) => p.trim().isNotEmpty).join('\n');

      const selectedIndices = [1, 2];
      const aiGeneratedContent = ['新段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs.length, equals(3));
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('新段落'));
      expect(resultParagraphs[2], equals('第四段'));

      print('\n✅ AI生成更少段落成功');
    });
  });

  group('修复验证：实际应用场景', () {
    test('完整工作流：从用户选择到替换', () {
      // 模拟完整的用户操作流程
      const chapterContent = '''第一章 开始

夜幕降临，繁华的城市渐渐安静下来。

街道上的霓虹灯依旧闪烁，但行人已经稀少。

她独自走在回家的路上。''';

      print('\n=== 完整工作流测试 ===');

      // 步骤1：UI层过滤
      final paragraphs = chapterContent.split('\n');
      final filteredParagraphs =
          paragraphs.where((p) => p.trim().isNotEmpty).toList();

      print('1. UI层过滤: ${paragraphs.length} → ${filteredParagraphs.length} 段');

      // 步骤2：用户选择
      const selectedIndices = [1, 2];
      print('2. 用户选择索引: $selectedIndices');

      // 步骤3：构建过滤后的内容
      final filteredContent = filteredParagraphs.join('\n');
      print('3. 传递过滤后的内容给Dialog');

      // 步骤4：AI生成
      const aiContent = ['改写后的夜景描写', '改写后的街道描写'];
      print('4. AI生成 ${aiContent.length} 段内容');

      // 步骤5：执行替换
      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: filteredContent,
        selectedIndices: selectedIndices,
        newContent: aiContent,
      );

      final resultParagraphs = result.split('\n');
      print('5. 替换完成: ${filteredParagraphs.length} → ${resultParagraphs.length} 段');

      // 验证结果
      expect(resultParagraphs[0], equals('第一章 开始'));
      expect(resultParagraphs[1], equals('改写后的夜景描写'));
      expect(resultParagraphs[2], equals('改写后的街道描写'));
      expect(resultParagraphs[3], equals('她独自走在回家的路上。'));

      print('\n✅ 完整工作流验证成功');
      print('   用户看到的内容与替换结果完全匹配');
    });
  });
}
