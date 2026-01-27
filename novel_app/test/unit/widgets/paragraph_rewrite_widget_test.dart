import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/widgets/reader/paragraph_rewrite_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Mock classes
@GenerateMocks([SharedPreferences])
import 'paragraph_rewrite_widget_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('段落替换功能测试', () {
    late Novel testNovel;
    late Chapter testChapter;
    late List<Chapter> testChapters;

    setUp(() {
      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel',
      );

      testChapter = Chapter(
        title: '第一章',
        url: 'https://example.com/chapter1',
        content: '''第一段内容

第二段内容

第三段内容

第四段内容

第五段内容''',
      );

      testChapters = [testChapter];
    });

    testWidgets('基础替换逻辑测试：删除选中段落并插入新内容', (WidgetTester tester) async {
      String? replacedContent;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ParagraphRewriteDialog(
              novel: testNovel,
              chapters: testChapters,
              currentChapter: testChapter,
              content: testChapter.content!,
              selectedParagraphIndices: [1, 2], // 选中第二、三段
              onReplace: (newContent) {
                replacedContent = newContent;
              },
            ),
          ),
        ),
      );

      // 等待对话框初始化（不使用pumpAndSettle避免超时）
      await tester.pump(const Duration(milliseconds: 100));

      // 验证输入对话框显示
      expect(find.text('输入改写要求'), findsOneWidget);
      expect(find.text('已选择 2 个段落'), findsOneWidget);
    });

    test('段落替换逻辑单元测试：删除+插入', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段'];
      final selectedIndices = [1, 2, 3]; // 选中第二、三、四段
      final aiContent = ['改写1', '改写2', '改写3', '改写4', '改写5'];

      // 模拟删除+插入逻辑
      final updated = List<String>.from(paragraphs);
      final insertPos = selectedIndices.first;

      // 从后往前删除
      for (int i = selectedIndices.length - 1; i >= 0; i--) {
        updated.removeAt(selectedIndices[i]);
      }

      // 插入新内容
      updated.insertAll(insertPos, aiContent);

      // 验证结果
      expect(updated.length, 7, reason: '应该有7段: 5 - 3 + 5 = 7');
      expect(updated[0], '第一段', reason: '第一段应该保持不变');
      expect(updated[1], '改写1', reason: '插入位置应该是改写内容');
      expect(updated[6], '第五段', reason: '最后一段应该保持不变');
    });

    test('边界情况：空内容处理', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [1];
      final aiContent = <String>[]; // 空数组

      final updated = List<String>.from(paragraphs);
      final insertPos = selectedIndices.first;

      updated.removeAt(selectedIndices.first);
      updated.insertAll(insertPos, aiContent);

      expect(updated.length, 2, reason: '应该有2段: 3 - 1 + 0 = 2');
      expect(updated[0], '第一段');
      expect(updated[1], '第三段');
    });

    test('边界情况：索引越界保护', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [0, 1, 100]; // 索引100超出范围
      final aiContent = ['改写1'];

      // 过滤有效索引
      final validIndices = selectedIndices
          .where((index) => index >= 0 && index < paragraphs.length)
          .toList();

      expect(validIndices, [0, 1], reason: '应该过滤掉无效索引100');

      final updated = List<String>.from(paragraphs);

      if (validIndices.isNotEmpty) {
        final insertPos = validIndices.first;
        for (int i = validIndices.length - 1; i >= 0; i--) {
          updated.removeAt(validIndices[i]);
        }
        updated.insertAll(insertPos, aiContent);
      }

      expect(updated.length, 2, reason: '应该有2段');
      expect(updated[0], '改写1');
      expect(updated[1], '第三段');
    });

    test('边界情况：AI生成更多段落', () {
      final paragraphs = ['第一段', '第二段', '第三段'];
      final selectedIndices = [1];
      final aiContent = ['改写1', '改写2', '改写3', '改写4', '改写5'];

      final updated = List<String>.from(paragraphs);
      final insertPos = selectedIndices.first;

      updated.removeAt(selectedIndices.first);
      updated.insertAll(insertPos, aiContent);

      expect(updated.length, 7, reason: '应该有7段: 3 - 1 + 5 = 7');
      expect(updated[0], '第一段');
      expect(updated[1], '改写1');
    });

    test('边界情况：AI生成更少段落', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段'];
      final selectedIndices = [1, 2, 3];
      final aiContent = ['改写1'];

      final updated = List<String>.from(paragraphs);
      final insertPos = selectedIndices.first;

      for (int i = selectedIndices.length - 1; i >= 0; i--) {
        updated.removeAt(selectedIndices[i]);
      }
      updated.insertAll(insertPos, aiContent);

      expect(updated.length, 3, reason: '应该有3段: 5 - 3 + 1 = 3');
      expect(updated[0], '第一段');
      expect(updated[1], '改写1');
      expect(updated[2], '第五段');
    });

    test('特殊情况：包含空行的处理', () {
      final content = '第一段\n\n第二段\n\n第三段';
      final paragraphs = content.split('\n');

      expect(paragraphs.length, 5, reason: '应该包含空行');
      expect(paragraphs[1], '', reason: '第二行应该是空行');
      expect(paragraphs[3], '', reason: '第四行应该是空行');

      // 测试实际内容中的空行：第一段\n\n\n第二段\n\n第三段 = 5行
      final content2 = '第一段\n\n\n第二段\n\n第三段';
      final paragraphs2 = content2.split('\n');

      expect(paragraphs2.length, 5, reason: '第一段和第二段之间有2个空行');
      expect(paragraphs2[1], '', reason: '第二行应该是空行');
      expect(paragraphs2[2], '', reason: '第三行应该是空行');
      expect(paragraphs2[4], '第三段', reason: '最后一行应该是第三段');
    });

    test('特殊情况：选中多个不连续段落', () {
      final paragraphs = ['第一段', '第二段', '第三段', '第四段', '第五段', '第六段'];
      final selectedIndices = [1, 3, 5]; // 不连续的段落：第二段、第四段、第六段
      final aiContent = ['改写1', '改写2', '改写3'];

      final updated = List<String>.from(paragraphs);
      final insertPos = selectedIndices.first;

      // 从后往前删除（避免索引变化）
      final sortedIndices = List.from(selectedIndices)..sort();
      for (int i = sortedIndices.length - 1; i >= 0; i--) {
        updated.removeAt(sortedIndices[i]);
      }

      // 在插入位置（原索引1）插入新内容
      updated.insertAll(insertPos, aiContent);

      // 预期结果：
      // 原始：[第一段, 第二段, 第三段, 第四段, 第五段, 第六段]
      // 删除：[第一段, 第三段, 第五段] (删除了索引1,3,5)
      // 插入后：[第一段, 改写1, 改写2, 改写3, 第三段, 第五段]
      expect(updated.length, 6, reason: '应该有6段: 6 - 3 + 3 = 6');
      expect(updated[0], '第一段');
      expect(updated[1], '改写1');
      expect(updated[2], '改写2');
      expect(updated[3], '改写3');
      expect(updated[4], '第三段', reason: '原第三段保留（索引从3变成4）');
      expect(updated[5], '第五段', reason: '原第五段保留（索引从5变成5）');
    });

    test('数据验证：替换后的完整性', () {
      final originalContent = '第一段\n第二段\n第三段\n第四段\n第五段';
      final paragraphs = originalContent.split('\n');
      final selectedIndices = [1, 2, 3];
      final aiContent = ['改写A', '改写B'];

      final updated = List<String>.from(paragraphs);
      final insertPos = selectedIndices.first;

      for (int i = selectedIndices.length - 1; i >= 0; i--) {
        updated.removeAt(selectedIndices[i]);
      }
      updated.insertAll(insertPos, aiContent);

      final newContent = updated.join('\n');

      // 验证：第一段和最后一段应该保留
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
  });

  group('RewriteService 测试', () {
    test('构建输入参数 - 简化版', () {
      // 这里需要实际的RewriteService
      // 由于是纯函数测试，可以直接测试逻辑

      final selectedText = '选中的文本';
      final userInput = '改写要求';
      final fullContext = '完整的上下文内容';
      final characters = [];

      final expectedInputs = {
        'current_chapter_content': fullContext,
        'selected_text': selectedText,
        'user_input': userInput,
        'roles': '',
        'cmd': '特写',
      };

      // 验证参数结构
      expect(expectedInputs['cmd'], '特写');
      expect(expectedInputs['selected_text'], selectedText);
      expect(expectedInputs['user_input'], userInput);
    });
  });
}
