import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/tag_introspection.dart';

/// DifyCreativeService 解析方法测试
///
/// _parseIntrospectionOutput / _parseMatchOutput / _decodeContentMap
/// 是 private 方法，通过间接方式测试解析逻辑。
///
/// 这里独立测试 JSON 解析逻辑，验证各种输出格式的兼容性。
void main() {
  group('标签自省输出解析', () {
    test('content 为 JSON 字符串时正确解析', () {
      // 模拟 executeBlocking 返回 {'content': jsonString}
      final json = jsonEncode({
        'problems': [
          {
            'type': 'reason_adjust',
            'tag_name': '暴力美学',
            'current_reason': '打斗场景',
            'suggested_reason': '打斗、冲突、力量对抗',
            'analysis': '场景描述太窄',
          },
        ],
      });
      final outputs = {'content': json};

      final parsed = _decodeContentMap(outputs);
      final problemsRaw = parsed['problems'] as List;

      final problems = problemsRaw
          .map((m) =>
              TagIntrospectionProblem.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(problems, hasLength(1));
      expect(problems.first.type, 'reason_adjust');
      expect(problems.first.tagName, '暴力美学');
      expect(problems.first.suggestedReason, '打斗、冲突、力量对抗');
    });

    test('content 为 Map 时正确解析', () {
      // 模拟旧 Dify 路径返回已解析的 Map
      final outputs = {
        'content': {
          'problems': [
            {
              'type': 'prompt_clarify',
              'tag_name': '紧张对峙',
              'current_prompt': '营造氛围',
              'suggested_prompt': '使用短句和断句加速节奏',
              'analysis': '提示词太笼统',
            },
          ],
        },
      };

      final parsed = _decodeContentMap(outputs);
      final problemsRaw = parsed['problems'] as List;

      final problems = problemsRaw
          .map((m) =>
              TagIntrospectionProblem.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(problems, hasLength(1));
      expect(problems.first.type, 'prompt_clarify');
      expect(problems.first.currentPrompt, '营造氛围');
    });

    test('problems 为空数组时返回空列表', () {
      final json = jsonEncode({'problems': []});
      final outputs = {'content': json};

      final parsed = _decodeContentMap(outputs);
      final problemsRaw = parsed['problems'] as List;

      expect(problemsRaw, isEmpty);
    });

    test('混合类型问题正确解析', () {
      final json = jsonEncode({
        'problems': [
          {
            'type': 'reason_adjust',
            'tag_name': '暴力美学',
            'suggested_reason': '新场景',
            'analysis': '原因1',
          },
          {
            'type': 'missing_tag',
            'suggested_tag': '画面感',
            'suggested_new_reason': '需要感官描写',
            'suggested_prompt': '五感细节',
            'suggested_category': '场景',
            'analysis': '原因2',
          },
        ],
      });
      final outputs = {'content': json};

      final parsed = _decodeContentMap(outputs);
      final problemsRaw = parsed['problems'] as List;

      final problems = problemsRaw
          .map((m) =>
              TagIntrospectionProblem.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(problems, hasLength(2));
      expect(problems[0].isReasonAdjust, isTrue);
      expect(problems[1].isMissingTag, isTrue);
      expect(problems[1].suggestedTag, '画面感');
    });
  });

  group('标签匹配输出解析', () {
    test('content 为 JSON 字符串时正确解析', () {
      final json = jsonEncode({
        'selected_tags': [
          {
            'name': '紧张对峙',
            'category_id': 1,
            'match_reason': '当前场景涉及对峙',
          },
          {
            'name': '暴力美学',
            'category_id': 1,
            'match_reason': '场景包含冲突元素',
          },
        ],
      });
      final outputs = {'content': json};

      final parsed = _decodeContentMap(outputs);
      final selectedRaw = parsed['selected_tags'] as List;

      final results = selectedRaw
          .map((m) => TagMatchResult.fromJson(m as Map<String, dynamic>))
          .toList();

      expect(results, hasLength(2));
      expect(results[0].name, '紧张对峙');
      expect(results[0].categoryId, 1);
      expect(results[1].name, '暴力美学');
    });

    test('selected_tags 为空数组时返回空列表', () {
      final json = jsonEncode({'selected_tags': []});
      final outputs = {'content': json};

      final parsed = _decodeContentMap(outputs);
      final selectedRaw = parsed['selected_tags'] as List;

      expect(selectedRaw, isEmpty);
    });
  });

  group('_decodeContentMap 容错', () {
    test('content 为 String 时 jsonDecode', () {
      final outputs = {'content': '{"key": "value"}'};
      final parsed = _decodeContentMap(outputs);
      expect(parsed['key'], 'value');
    });

    test('content 为 Map 时直接返回', () {
      final outputs = {
        'content': {'key': 'value'}
      };
      final parsed = _decodeContentMap(outputs);
      expect(parsed['key'], 'value');
    });

    test('content 为非法 JSON 字符串时回退到 outputs', () {
      final outputs = {'content': 'not-json', 'fallback': 'data'};
      final parsed = _decodeContentMap(outputs);
      expect(parsed['fallback'], 'data');
    });
  });
}

/// 复制 DifyCreativeService._decodeContentMap 的逻辑用于独立测试
Map<String, dynamic> _decodeContentMap(Map<String, dynamic> outputs) {
  final content = outputs['content'];
  if (content is Map<String, dynamic>) {
    return content;
  }
  if (content is String) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
  }
  return outputs;
}
