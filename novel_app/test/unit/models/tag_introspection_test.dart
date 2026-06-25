import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/tag_introspection.dart';

/// TagIntrospectionProblem 和 TagMatchResult 模型测试
///
/// 验证自省问题和匹配结果的 fromJson 解析：
/// - 三种问题类型的正确解析
/// - 缺失字段的容错处理
/// - 类型判断快捷方法
/// - 匹配结果解析
void main() {
  group('TagIntrospectionProblem', () {
    test('reason_adjust 类型正确解析', () {
      final json = {
        'type': 'reason_adjust',
        'tag_name': '暴力美学',
        'current_reason': '打斗场景',
        'suggested_reason': '打斗、冲突、力量对抗',
        'analysis': '当前场景描述太窄，应扩展到更多对抗形式',
      };

      final problem = TagIntrospectionProblem.fromJson(json);

      expect(problem.type, 'reason_adjust');
      expect(problem.tagName, '暴力美学');
      expect(problem.currentReason, '打斗场景');
      expect(problem.suggestedReason, '打斗、冲突、力量对抗');
      expect(problem.analysis, '当前场景描述太窄，应扩展到更多对抗形式');
      expect(problem.isReasonAdjust, isTrue);
      expect(problem.isPromptClarify, isFalse);
      expect(problem.isMissingTag, isFalse);
      expect(problem.typeLabel, '使用场景调整');
    });

    test('prompt_clarify 类型正确解析', () {
      final json = {
        'type': 'prompt_clarify',
        'tag_name': '紧张对峙',
        'current_prompt': '营造紧张氛围',
        'suggested_prompt': '使用短句和断句加速节奏，通过环境破坏来侧面展现紧张感',
        'analysis': '提示词过于笼统，LLM 无法准确执行',
      };

      final problem = TagIntrospectionProblem.fromJson(json);

      expect(problem.type, 'prompt_clarify');
      expect(problem.tagName, '紧张对峙');
      expect(problem.currentPrompt, '营造紧张氛围');
      expect(problem.suggestedPrompt,
          '使用短句和断句加速节奏，通过环境破坏来侧面展现紧张感');
      expect(problem.isPromptClarify, isTrue);
      expect(problem.typeLabel, '提示词优化');
    });

    test('missing_tag 类型正确解析', () {
      final json = {
        'type': 'missing_tag',
        'suggested_tag': '画面感',
        'suggested_new_reason': '需要感官描写的场景',
        'suggested_prompt': '融入五感细节，特别是视觉和听觉',
        'suggested_category': '场景',
        'analysis': '用户提到缺乏画面感，但标签库中没有相关标签',
      };

      final problem = TagIntrospectionProblem.fromJson(json);

      expect(problem.type, 'missing_tag');
      expect(problem.suggestedTag, '画面感');
      expect(problem.suggestedNewReason, '需要感官描写的场景');
      expect(problem.suggestedCategory, '场景');
      expect(problem.isMissingTag, isTrue);
      expect(problem.typeLabel, '建议新增标签');
    });

    test('空字符串字段返回 null', () {
      final json = {
        'type': 'reason_adjust',
        'tag_name': '',
        'analysis': '分析',
      };

      final problem = TagIntrospectionProblem.fromJson(json);

      expect(problem.tagName, isNull); // 空字符串 → null
      expect(problem.analysis, '分析');
    });

    test('null 字段返回 null', () {
      final json = {
        'type': 'prompt_clarify',
        'analysis': '分析内容',
      };

      final problem = TagIntrospectionProblem.fromJson(json);

      expect(problem.tagName, isNull);
      expect(problem.currentPrompt, isNull);
      expect(problem.suggestedPrompt, isNull);
    });

    test('兼容 analysis 字段名映射（analysis 优先于 reason）', () {
      final json = {
        'type': 'reason_adjust',
        'reason': '旧字段',
        'analysis': '新字段',
        'tag_name': '标签',
      };

      final problem = TagIntrospectionProblem.fromJson(json);

      expect(problem.analysis, '新字段');
    });
  });

  group('TagMatchResult', () {
    test('正确解析匹配结果', () {
      final json = {
        'name': '紧张对峙',
        'category_id': 1,
        'match_reason': '当前场景涉及双方对峙',
      };

      final result = TagMatchResult.fromJson(json);

      expect(result.name, '紧张对峙');
      expect(result.categoryId, 1);
      expect(result.matchReason, '当前场景涉及双方对峙');
    });

    test('缺失字段容错处理', () {
      final json = <String, dynamic>{};

      final result = TagMatchResult.fromJson(json);

      expect(result.name, '');
      expect(result.categoryId, 0);
      expect(result.matchReason, '');
    });

    test('category_id 为 num 类型时正确转 int', () {
      final json = {
        'name': '测试',
        'category_id': 3.0, // JSON 数字可能解析为 double
        'match_reason': '理由',
      };

      final result = TagMatchResult.fromJson(json);

      expect(result.categoryId, 3);
    });
  });
}
