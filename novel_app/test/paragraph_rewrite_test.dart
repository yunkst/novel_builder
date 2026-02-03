import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/paragraph_replace_helper.dart';

/// 段落改写功能测试套件
///
/// 目标：复现并验证段落改写功能失效的问题
void main() {
  group('段落改写功能测试 - ParagraphReplaceHelper', () {
    test('基础测试：单段落替换', () {
      // 准备测试数据
      const originalContent = '''第一段内容
第二段内容
第三段内容
第四段内容
第五段内容''';

      const selectedIndices = [2]; // 选中"第三段内容"
      const aiGeneratedContent = ['这是AI改写后的第三段'];

      // 执行替换
      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      // 验证结果
      final expectedContent = '''第一段内容
第二段内容
这是AI改写后的第三段
第四段内容
第五段内容''';

      expect(result, equals(expectedContent), reason: '单段落替换应该成功');

      // 验证段落数量
      final originalParagraphs = originalContent.split('\n');
      final resultParagraphs = result.split('\n');
      expect(resultParagraphs.length, equals(originalParagraphs.length),
          reason: '替换前后段落数量应该保持一致');
    });

    test('基础测试：多段落替换（AI生成相同数量的段落）', () {
      const originalContent = '''第一段
第二段
第三段
第四段
第五段
第六段''';

      const selectedIndices = [1, 2, 3]; // 选中第二、三、四段
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

      expect(result, equals(expectedContent), reason: '多段落替换（数量相同）应该成功');

      final resultParagraphs = result.split('\n');
      expect(resultParagraphs.length, equals(6), reason: '替换后应该保持6个段落');
    });

    test('场景1：AI生成更多段落（扩写）', () {
      const originalContent = '''第一段
第二段
第三段
第四段
第五段''';

      const selectedIndices = [2]; // 选中第三段
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
      expect(resultParagraphs.length, equals(7), reason: '删除1段插入3段，应该有7个段落');

      // 验证未选中段落保持不变
      expect(resultParagraphs[0], equals('第一段'), reason: '第一段应该保持不变');
      expect(resultParagraphs[1], equals('第二段'), reason: '第二段应该保持不变');
      expect(resultParagraphs[5], equals('第四段'), reason: '第四段应该保持不变');
      expect(resultParagraphs[6], equals('第五段'), reason: '第五段应该保持不变');

      // 验证新内容插入在正确位置
      expect(resultParagraphs[2], equals('扩写段落1'), reason: '新内容的第一段应该在索引2位置');
      expect(resultParagraphs[3], equals('扩写段落2'), reason: '新内容的第二段应该在索引3位置');
      expect(resultParagraphs[4], equals('扩写段落3'), reason: '新内容的第三段应该在索引4位置');
    });

    test('场景2：AI生成更少段落（精简）', () {
      const originalContent = '''第一段
第二段
第三段
第四段
第五段''';

      const selectedIndices = [1, 2, 3]; // 选中第二、三、四段
      const aiGeneratedContent = ['精简后的段落']; // AI只生成1段

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证：5 - 3 + 1 = 3段
      expect(resultParagraphs.length, equals(3), reason: '删除3段插入1段，应该有3个段落');

      // 验证结果
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('精简后的段落'));
      expect(resultParagraphs[2], equals('第五段'));
    });

    test('场景3：选中包含空行', () {
      const originalContent = '''第一段

第二段

第三段''';

      // 注意：split('\n')会保留空字符串
      final paragraphs = originalContent.split('\n');
      print('原始段落数: ${paragraphs.length}');
      print('段落内容: $paragraphs');

      const selectedIndices = [1]; // 选中第一个空行
      const aiGeneratedContent = ['插入的新段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');
      print('结果段落数: ${resultParagraphs.length}');
      print('结果内容: $resultParagraphs');

      // 验证：空行也应该可以被替换
      expect(resultParagraphs.length, equals(paragraphs.length));
      expect(resultParagraphs[1], equals('插入的新段落'));
    });

    test('边界测试：空内容处理', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = [1];
      const aiGeneratedContent = <String>[]; // AI生成空内容

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 验证：3 - 1 + 0 = 2段（只删除，不插入）
      expect(resultParagraphs.length, equals(2), reason: '空内容应该只删除选中段落');
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('第三段'), reason: '第二段被删除，第三段上移');
    });

    test('边界测试：选中第一段', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = [0];
      const aiGeneratedContent = ['新的第一段'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs.length, equals(3));
      expect(resultParagraphs[0], equals('新的第一段'), reason: '第一段应该被替换');
      expect(resultParagraphs[1], equals('第二段'));
      expect(resultParagraphs[2], equals('第三段'));
    });

    test('边界测试：选中最后一段', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = [2];
      const aiGeneratedContent = ['新的第三段'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs.length, equals(3));
      expect(resultParagraphs[0], equals('第一段'));
      expect(resultParagraphs[1], equals('第二段'));
      expect(resultParagraphs[2], equals('新的第三段'), reason: '最后一段应该被替换');
    });

    test('边界测试：无效索引过滤', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = [0, 1, 100, -1]; // 包含无效索引
      const aiGeneratedContent = ['新段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 应该过滤掉无效索引100和-1
      // 实际删除索引0和1，插入1段：3 - 2 + 1 = 2段
      expect(resultParagraphs.length, equals(2));
      expect(resultParagraphs[0], equals('新段落'));
      expect(resultParagraphs[1], equals('第三段'));
    });

    test('边界测试：所有段落都被选中', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = [0, 1, 2];
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

    test('边界测试：空索引列表', () {
      const originalContent = '''第一段
第二段
第三段''';

      const selectedIndices = <int>[];
      const aiGeneratedContent = ['新内容'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      // 空索引列表应该返回原始内容
      expect(result, equals(originalContent));
    });

    test('验证测试：validateReplacement方法', () {
      const originalContent = '''第一段
第二段
第三段
第四段''';

      const selectedIndices = [1, 2];
      const aiGeneratedContent = ['新段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final originalParagraphs = originalContent.split('\n');
      final resultParagraphs = result.split('\n');

      final validation = ParagraphReplaceHelper.validateReplacement(
        originalParagraphs: originalParagraphs,
        updatedParagraphs: resultParagraphs,
        selectedIndices: selectedIndices,
      );

      expect(validation.isValid, isTrue, reason: validation.message);
      expect(validation.message, contains('替换验证通过'));
    });

    test('真实场景：多段落改写（可能触发Bug的场景）', () {
      // 模拟真实的长文本场景
      const originalContent = '''夜幕降临，繁华的城市渐渐安静下来。
街道上的霓虹灯依旧闪烁，但行人已经稀少。
远处传来汽车的引擎声，打破了夜的宁静。

她独自走在回家的路上，脚步有些匆忙。
路灯将她的影子拉得很长，在空旷的街道上投下斑驳的印记。
心中有一种说不出的不安，仿佛有什么事情即将发生。

突然，手机铃声响起，打破了寂静。
她停下脚步，掏出手机，看着屏幕上陌生的号码。
犹豫了片刻，最终还是接通了电话。

"喂，你是谁？"她的声音有些颤抖。
电话那头传来一阵诡异的笑声，让她的背脊一阵发凉。
"你很快就会知道的..."说完，电话就挂断了。

她站在原地，手机从手中滑落，摔在地上。
恐惧像潮水般涌上心头，让她几乎无法呼吸。
这是怎么回事？到底是谁在恶作剧？''';

      // 选中第5-7段（"她独自走着..."到"...即将发生"）
      const selectedIndices = [4, 5, 6];
      const aiGeneratedContent = [
        '她加快了脚步，心脏剧烈地跳动着。',
        '夜风吹过，让她感到一阵寒意。',
        '她决定不再犹豫，快速向家的方向跑去。',
      ];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');
      final originalParagraphs = originalContent.split('\n');

      print('原始段落数: ${originalParagraphs.length}');
      print('选中索引: $selectedIndices');
      print('AI生成段落数: ${aiGeneratedContent.length}');
      print('结果段落数: ${resultParagraphs.length}');
      print(
          '预期段落数: ${originalParagraphs.length - selectedIndices.length + aiGeneratedContent.length}');

      // 验证段落数量
      final expectedLength = originalParagraphs.length -
          selectedIndices.length +
          aiGeneratedContent.length;
      expect(resultParagraphs.length, equals(expectedLength),
          reason: '段落数量计算错误');

      // 验证前后内容保持不变
      expect(resultParagraphs[0], equals(originalParagraphs[0]),
          reason: '开篇内容应该保持不变');
      expect(resultParagraphs[3], equals(originalParagraphs[3]),
          reason: '选中前的段落应该保持不变');

      // 验证新内容插入正确
      expect(resultParagraphs[4], equals(aiGeneratedContent[0]));
      expect(resultParagraphs[5], equals(aiGeneratedContent[1]));
      expect(resultParagraphs[6], equals(aiGeneratedContent[2]));

      // 验证后续内容保持不变
      expect(resultParagraphs[7], equals(originalParagraphs[7]),
          reason: '选中后的段落应该保持不变');

      // 使用验证方法检查
      final validation = ParagraphReplaceHelper.validateReplacement(
        originalParagraphs: originalParagraphs,
        updatedParagraphs: resultParagraphs,
        selectedIndices: selectedIndices,
      );

      expect(validation.isValid, isTrue, reason: validation.message);
    });
  });

  group('Bug复现场景测试', () {
    test('Bug场景1：索引顺序混乱', () {
      const originalContent = '''段落1
段落2
段落3
段落4
段落5''';

      // 模拟UI可能返回乱序的索引
      const selectedIndices = [3, 1, 2]; // 不按顺序
      const aiGeneratedContent = ['新段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 应该正确处理乱序索引
      expect(resultParagraphs.length, equals(3), reason: '删除3段插入1段，应该有3个段落');

      // 验证结果
      expect(resultParagraphs[0], equals('段落1'));
      expect(resultParagraphs[1], equals('新段落'));
      expect(resultParagraphs[2], equals('段落5'));
    });

    test('Bug场景2：重复索引', () {
      const originalContent = '''段落1
段落2
段落3
段落4''';

      // 模拟UI可能返回重复的索引
      const selectedIndices = [1, 1, 2]; // 索引1重复
      const aiGeneratedContent = ['新段落'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      // 应该正确处理重复索引（删除索引1和2）
      // 注意：重复索引1会导致删除时索引变化
      print('结果: $resultParagraphs');

      // 这里的行为取决于实现，需要确认是否处理重复索引
      // 如果没有处理，可能会导致bug
    });

    test('Bug场景3：中文段落内容', () {
      const originalContent = '''这是一个测试段落，包含中文内容。
这是第二段，也有一些文字。
第三段的内容比较简短。''';

      const selectedIndices = [1];
      const aiGeneratedContent = ['这是替换后的新段落内容，可能包含更多文字。'];

      final result = ParagraphReplaceHelper.executeReplaceAndJoin(
        content: originalContent,
        selectedIndices: selectedIndices,
        newContent: aiGeneratedContent,
      );

      final resultParagraphs = result.split('\n');

      expect(resultParagraphs.length, equals(3));
      expect(resultParagraphs[0], equals('这是一个测试段落，包含中文内容。'));
      expect(resultParagraphs[1], equals('这是替换后的新段落内容，可能包含更多文字。'));
      expect(resultParagraphs[2], equals('第三段的内容比较简短。'));
    });
  });
}
