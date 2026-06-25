import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/prompt_tag.dart';

/// PromptTag 模型 - reason 字段测试
///
/// 验证 PromptTag 模型的 reason 字段：
/// - 默认值为空字符串
/// - toMap / fromMap 正确序列化
/// - fromMap 兼容 null reason（旧数据升级场景）
/// - copyWith 正确处理 reason
void main() {
  final now = DateTime(2026, 6, 23, 10, 0);

  group('PromptTag - reason 字段', () {
    test('reason 默认值为空字符串', () {
      final tag = PromptTag(
        categoryId: 1,
        name: '紧张对峙',
        promptText: '使用短句和断句来营造紧张氛围',
        createdAt: now,
        updatedAt: now,
      );

      expect(tag.reason, '');
    });

    test('toMap 包含 reason 字段', () {
      final tag = PromptTag(
        categoryId: 1,
        name: '紧张对峙',
        reason: '双方对峙、谈判僵局',
        promptText: '使用短句和断句来营造紧张氛围',
        createdAt: now,
        updatedAt: now,
      );

      final map = tag.toMap();

      expect(map['reason'], '双方对峙、谈判僵局');
    });

    test('fromMap 正确解析 reason 字段', () {
      final map = {
        'id': 1,
        'category_id': 1,
        'name': '暴力美学',
        'reason': '打斗、冲突、力量对抗',
        'prompt_text': '描写打斗时注重力量感和冲击力',
        'sort_order': 0,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      };

      final tag = PromptTag.fromMap(map);

      expect(tag.reason, '打斗、冲突、力量对抗');
    });

    test('fromMap 兼容 null reason（旧数据升级场景）', () {
      final map = {
        'id': 1,
        'category_id': 1,
        'name': '暴力美学',
        // 没有 reason 字段（v27 升级到 v28 的旧数据）
        'prompt_text': '描写打斗时注重力量感和冲击力',
        'sort_order': 0,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      };

      final tag = PromptTag.fromMap(map);

      expect(tag.reason, '');
    });

    test('copyWith 更新 reason', () {
      final original = PromptTag(
        id: 1,
        categoryId: 1,
        name: '暴力美学',
        reason: '打斗场景',
        promptText: '描写打斗时注重力量感',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(reason: '打斗、冲突、力量对抗');

      expect(updated.reason, '打斗、冲突、力量对抗');
      expect(updated.name, '暴力美学'); // 其他字段保持不变
      expect(updated.promptText, '描写打斗时注重力量感');
    });

    test('copyWith 不传 reason 时保持原值', () {
      final original = PromptTag(
        id: 1,
        categoryId: 1,
        name: '暴力美学',
        reason: '打斗、冲突、力量对抗',
        promptText: '描写打斗时注重力量感',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(promptText: '新的提示词');

      expect(updated.reason, '打斗、冲突、力量对抗'); // reason 保持不变
      expect(updated.promptText, '新的提示词');
    });
  });
}
