import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/paragraph_replace_helper.dart';

/// 段落改写功能修正版测试
///
/// 只测试实际可能的场景（连续段落选择）
void main() {
  group('段落改写功能测试 - 实际场景（连续段落）', () {
    test('基础测试：单段落替换', () {
      const originalContent = '''第一段内容
第二段内容
第三段内容
第四段内容
第五段内容''';

      const selectedIndices = [2]; // 选中"第三段内容"
      const aiGeneratedContent = ['这是AI改写后的第三段'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final expectedContent = '''第一段内容
第二段内容
这是AI改写后的第三段
第四段内容
第五段内容''';

      expect(result, equals(expectedContent),
          reason: '单段落替换应该成功');
    });

    test('基础测试：连续多段落替换', () {
      const originalContent = '''第一段
第二段
第三段
第四段
第五段
第六段''';

      const selectedIndices = [1, 2, 3]; // 选中第二、三、四段（连续）
      const aiGeneratedContent = ['改写第二段', '改写第三段', '改写第四段'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final expectedContent = '''第一段
改写第二段
改写第三段
改写第四段
第五段
第六段''';

      expect(result, equals(expectedContent),
          reason: '连续多段落替换应该成功');
    });

    test('场景1：AI生成更多段落（扩写）', () {
      const originalContent = '''第一段
第二段
第三段
第四段
第五段''';

      const selectedIndices = [2]; // 选中第三段（单段落）
      const aiGeneratedContent = [
        '扩写段落1',
        '扩写段落2',
        '扩写段落3',
      ]; // AI生成3段

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证：5 - 1 + 3 = 7段
      expect(resultParagraphs.length, equals(7),
          reason: '删除1段插入3段，应该有7个段落');

      // 验证未选中段落保持不变
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('第二段'));
      expect(resultParagraphs[5], equals('第四段'));
      expect(resultParagraphs[6], equals('第五段'));

      // 验证新内容插入在正确位置
      expect(resultParagraphs[2], equals('扩写段落1'));
      expect(resultParagraphs[3], equals('扩写段落2'));
      expect(resultParagraphs[4], equals('扩写段落3'));
    });

    test('场景2：AI生成更少段落（精简）', () {
      const originalContent = '''第一段
第二段
第三段
第四段
第五段''';

      const selectedIndices = [1, 2, 3]; // 选中第二、三、四段（连续）
      const aiGeneratedContent = ['精简后的段落']; // AI只生成1段

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证：5 - 3 + 1 = 3段
      expect(resultParagraphs.length, equals(3));

      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('精简后的段落'));
      expect(resultParagraphs[2], equals('第五段'));
    });

    test('场景3：连续段落扩写', () {
      const originalContent = '''第一段
第二段
第三段
第四段
第五段
第六段
第七段''';

      // 选中连续的段落：1、2、3
      const selectedIndices = [1, 2, 3];
      const aiGeneratedContent = ['新1', '新2', '新3', '新4', '新5'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      print('原始: [第一段, 第二段, 第三段, 第四段, 第五段, 第六段, 第七段]');
      print('选中: $selectedIndices');
      print('结果: ${resultParagraphs.join(', ')}');
      print('预期: [第一段, 新1, 新2, 新3, 新4, 新5, 第五段, 第六段, 第七段]');

      // 验证：7 - 3 + 5 = 9段
      expect(resultParagraphs.length, equals(9));

      // 验证结果
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('新1'));
      expect(resultParagraphs[2], equals('新2'));
      expect(resultParagraphs[3], equals('新3'));
      expect(resultParagraphs[4], equals('新4'));
      expect(resultParagraphs[5], equals('新5'));
      expect(resultParagraphs[6], equals('第五段')); // 关键验证
      expect(resultParagraphs[7], equals('第六段'));
      expect(resultParagraphs[8], equals('第七段'));
    });

    test('边界测试：选中第一段（连续）', () {
      const originalContent = '''第一段
第二段
第三段
第四段''';

      // UI保证：如果选中第一段，后续必须是连续的
      const selectedIndices = [0, 1]; // 选中第一、二段
      const aiGeneratedContent = ['新1', '新2'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs.length, equals(4));
      expect(resultParagraphs[0], equals('新1'));
      expect(resultParagraphs[1], equals('新2'));
      expect(resultParagraphs[2], equals('第三段'));
      expect(resultParagraphs[3], equals('第四段'));
    });

    test('边界测试：选中最后几段（连续）', () {
      const originalContent = '''第一段
第二段
第三段
第四段''';

      const selectedIndices = [2, 3]; // 选中第三、四段
      const aiGeneratedContent = ['新1'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs.length, equals(3));
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('第二段'));
      expect(resultParagraphs[2], equals('新1'));
    });

    test('边界测试：空内容处理', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = [1];
      const aiGeneratedContent = <String>[];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证：3 - 1 + 0 = 2段（只删除，不插入）
      expect(resultParagraphs.length, equals(2));
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('第三段'));
    });

    test('边界测试：所有段落都被选中（连续）', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = [0, 1, 2]; // 全部选中（连续）
      const aiGeneratedContent = ['全新内容1', '全新内容2'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证：3 - 3 + 2 = 2段
      expect(resultParagraphs.length, equals(2));
      expect(resultParagraphs[0], equals('全新内容1'));
      expect(resultParagraphs[1], equals('全新内容2'));
    });

    test('真实场景：小说章节连续段落改写', () {
      // 模拟真实的小说章节内容
      const chapterContent = '''夜幕降临，繁华的城市渐渐安静下来。
街道上的霓虹灯依旧闪烁，但行人已经稀少。
远处传来汽车的引擎声，打破了夜的宁静。

她独自走在回家的路上，脚步有些匆忙。
路灯将她的影子拉得很长，在空旷的街道上投下斑驳的印记。
心中有一种说不出的不安，仿佛有什么事情即将发生。

突然，手机铃声响起，打破了寂静。''';

      // 用户选中第1-3段（连续）
      const selectedIndices = [1, 2, 3];
      const aiRewrite = [
        '改写后的第一段：霓虹灯闪烁得更加耀眼。',
        '改写后的第二段：寂静的夜晚被引擎声打破。',
        '改写后的第三段：这声音在夜空中回荡。',
      ];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: chapterContent,
        selectedIndices: selectedIndices,
        newContent: aiRewrite,
      );

      final resultParagraphs = result.split('\n');
      final originalParagraphs = chapterContent.split('\n');

      print('\n=== 真实场景测试 ===');
      print('原始段落数: ${originalParagraphs.length}');
      print('选中索引: $selectedIndices (连续)');
      print('AI生成段落数: ${aiRewrite.length}');
      print('结果段落数: ${resultParagraphs.length}');

      // 验证段落数量
      final expectedLength =
          originalParagraphs.length - selectedIndices.length + aiRewrite.length;
      expect(resultParagraphs.length, equals(expectedLength));

      // 验证第0段（未选中）
      expect(resultParagraphs[0], equals(originalParagraphs[0]),
          reason: '开篇内容应该保持不变');

      // 验证新内容插入正确
      expect(resultParagraphs[1], equals(aiRewrite[0]));
      expect(resultParagraphs[2], equals(aiRewrite[1]));
      expect(resultParagraphs[3], equals(aiRewrite[2]));

      // 验证后续内容保持不变
      expect(resultParagraphs[4], equals(originalParagraphs[4]),
          reason: '选中后的段落应该保持不变');
    });
  });

  group('段落改写功能测试 - 实际Bug调查', () {
    test('调查：用户反馈的Bug可能是什么', () {
      print('\n=== Bug调查 ===');
      print('根据UI代码分析，用户只能选择连续的段落');
      print('如果尝试选择不连续段落，UI会自动重置为最后一个点击的段落');
      print('');
      print('可能的Bug场景：');
      print('1. 单段落选择后，AI生成多个段落');
      print('2. 连续多段落选择后，AI生成不同数量的段落');
      print('3. 空内容的边界处理');
      print('4. 索引越界或空索引列表');
      print('');

      const originalContent = '''段落1
段落2
段落3
段落4
段落5''';

      // 场景1：单段落选择，AI生成多个段落
      final test1 = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: [2],
        newContent: ['新1', '新2', '新3'],
      );

      print('场景1: 单段落[2] → 生成3段');
      print('  结果: ${test1.split('\n').join(', ')}');
      print('  预期: [段落1, 段落2, 新1, 新2, 新3, 段落4, 段落5]');

      expect(test1.split('\n').length, equals(7));
      expect(test1.split('\n')[2], equals('新1'));
      expect(test1.split('\n')[3], equals('新2'));
      expect(test1.split('\n')[4], equals('新3'));
      expect(test1.split('\n')[5], equals('段落4'),
          reason: '这是关键：段落4应该在索引5位置');
    });
  });
}
