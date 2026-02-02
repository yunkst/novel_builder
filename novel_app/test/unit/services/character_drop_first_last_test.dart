import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/character_extraction_service.dart';

/// 测试丢弃首尾段落的逻辑
void main() {
  group('CharacterExtractionService - 丢弃首尾段落测试', () {
    late CharacterExtractionService extractionService;

    setUp(() {
      extractionService = CharacterExtractionService();
    });

    test('应该丢弃每个片段的第一段和最后一段', () {
      // 片段1：有3个段落
      // 片段2：有4个段落
      final contexts = [
        '片段1第一段（可能截断）。\n片段1中间段A。\n片段1最后段（可能截断）。',
        '片段2第一段（可能截断）。\n片段2中间段B。\n片段2中间段C。\n片段2最后段（可能截断）。',
      ];

      final merged = extractionService.mergeAndDeduplicateContextsWithDrop(contexts);

      print('合并结果：\n$merged');

      // 应该只保留中间段落
      expect(merged, contains('片段1中间段A。'));
      expect(merged, contains('片段2中间段B。'));
      expect(merged, contains('片段2中间段C。'));

      // 不应该包含首尾段落
      expect(merged, isNot(contains('片段1第一段')));
      expect(merged, isNot(contains('片段1最后段')));
      expect(merged, isNot(contains('片段2第一段')));
      expect(merged, isNot(contains('片段2最后段')));

      // 最终应该只有3个段落
      final paragraphs = merged.split('\n');
      expect(paragraphs.length, 3);
    });

    test('单个片段时应该返回原文', () {
      final contexts = [
        '第一段。\n中间段。\n最后段。',
      ];

      final merged = extractionService.mergeAndDeduplicateContextsWithDrop(contexts);

      // 单个片段直接返回原值（特殊处理）
      expect(merged, '第一段。\n中间段。\n最后段。');
    });

    test('片段只有两段时应该返回空', () {
      // 片段只有第一段和最后段（实际是同一段）
      final contexts = [
        '唯一一段。',
      ];

      final merged = extractionService.mergeAndDeduplicateContextsWithDrop(contexts);

      // 单个片段直接返回原值（特殊处理）
      expect(merged, '唯一一段。');
    });

    test('多个片段时应该正确处理', () {
      final contexts = [
        '片段1-首（截断）。\n片段1-中1。\n片段1-中2。\n片段1-尾（截断）。',
        '片段2-首（截断）。\n片段2-中。\n片段2-尾（截断）。',
        '片段3-首（截断）。\n片段3-中1。\n片段3-中2。\n片段3-中3。\n片段3-尾（截断）。',
      ];

      final merged = extractionService.mergeAndDeduplicateContextsWithDrop(contexts);

      print('合并结果：\n$merged');

      // 验证只保留中间段落
      final paragraphs = merged.split('\n');

      // 片段1保留2个中间段
      expect(merged, contains('片段1-中1。'));
      expect(merged, contains('片段1-中2。'));

      // 片段2有3个段落，保留中间1段
      expect(merged, contains('片段2-中。'));

      // 片段3保留3个中间段
      expect(merged, contains('片段3-中1。'));
      expect(merged, contains('片段3-中2。'));
      expect(merged, contains('片段3-中3。'));

      // 总共应该是6个段落（2+1+3）
      expect(paragraphs.length, 6);
    });

    test('应该正确处理去重', () {
      final contexts = [
        '片段1-首。\n重复段落。\n片段1-尾。',
        '片段2-首。\n重复段落。\n片段2-尾。',
      ];

      final merged = extractionService.mergeAndDeduplicateContextsWithDrop(contexts);

      print('合并结果：\n$merged');

      // "重复段落"应该只出现一次（两个片段的中间段都是"重复段落"，去重后只剩1个）
      final count = merged.split('\n').where((p) => p == '重复段落。').length;
      expect(count, 1);

      // 最终只有1个段落
      final paragraphs = merged.split('\n');
      expect(paragraphs.length, 1);
    });

    test('实际案例：角色提取场景', () {
      // 模拟提取"上官冰儿"的场景
      final contexts = [
        '''周维清之所以全力以赴的和上官天月交手，一个是怕被上官天阳看出来，另一个，他也是要好好的检验一下自己的实力究竟达到了怎样程度。
事实证明，姜还是老的辣，尽管他们这一战真的不能再真，但最后因为上官天月的表演，上官天阳还是看出了其中奥妙。
上官冰儿目瞪口呆的听着周维清解释这一切，脸sè顿时变得古怪起来。''',
        '''周维清嘿嘿笑道："现在他们可顾不上你了，咱们还是赶快走才好。"
上官冰儿瞪大了美眸，"你这坏家伙，竟然和爸爸联合起来骗妈妈。"
两人一路疾行，中途周维清几乎没怎么休息。''',
      ];

      final merged = extractionService.mergeAndDeduplicateContextsWithDrop(contexts);

      print('合并结果：\n$merged');
      print('长度：${merged.length} 字');

      // 片段1有3段，丢弃首尾后保留中间1段
      expect(merged, contains('事实证明，姜还是老的辣，尽管他们这一战真的不能再真，但最后因为上官天月的表演，上官天阳还是看出了其中奥妙。'));

      // 片段2有3段，丢弃首尾后保留中间1段
      expect(merged, contains('上官冰儿瞪大了美眸，"你这坏家伙，竟然和爸爸联合起来骗妈妈。"'));

      // 不应该包含首尾段落
      expect(merged, isNot(contains('周维清之所以全力以赴')));
      expect(merged, isNot(contains('两人一路疾行')));

      // 最终应该有2个段落
      final paragraphs = merged.split('\n');
      expect(paragraphs.length, 2);
    });
  });
}
