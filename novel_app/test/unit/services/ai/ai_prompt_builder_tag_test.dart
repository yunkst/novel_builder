import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ai/ai_prompt_builder.dart';

/// AiPromptBuilder 标签自省和匹配功能测试
///
/// 验证：
/// - tagIntrospectionResponseSchema 结构正确
/// - tagMatchResponseSchema 结构正确
/// - 标签自省 prompt 模板渲染正确
/// - 标签匹配 prompt 模板渲染正确
void main() {
  group('AiPromptBuilder - 标签自省 Schema', () {
    test('Schema 顶层结构正确', () {
      final schema = AiPromptBuilder.tagIntrospectionResponseSchema;

      expect(schema['type'], equals('json_schema'));
      final jsonSchema = schema['json_schema'] as Map<String, dynamic>;
      expect(jsonSchema['name'], equals('tag_introspection'));
      expect(jsonSchema['strict'], isTrue);
    });

    test('Schema 包含 problems 数组', () {
      final schema = AiPromptBuilder.tagIntrospectionResponseSchema;
      final jsonSchema = schema['json_schema'] as Map<String, dynamic>;
      final innerSchema = jsonSchema['schema'] as Map<String, dynamic>;

      expect(innerSchema['type'], equals('object'));
      expect(innerSchema['additionalProperties'], isFalse);
      expect(innerSchema['required'], contains('problems'));

      final problems = innerSchema['properties']['problems'] as Map<String, dynamic>;
      expect(problems['type'], equals('array'));
    });

    test('problems items 包含三种 type enum', () {
      final schema = AiPromptBuilder.tagIntrospectionResponseSchema;
      final jsonSchema = schema['json_schema'] as Map<String, dynamic>;
      final innerSchema = jsonSchema['schema'] as Map<String, dynamic>;
      final problems = innerSchema['properties']['problems'] as Map<String, dynamic>;
      final items = problems['items'] as Map<String, dynamic>;

      final typeProp = items['properties']['type'] as Map<String, dynamic>;
      expect(typeProp['type'], equals('string'));
      expect(typeProp['enum'], containsAll(['reason_adjust', 'prompt_clarify', 'missing_tag']));
    });

    test('problems items 包含所有必要字段', () {
      final schema = AiPromptBuilder.tagIntrospectionResponseSchema;
      final jsonSchema = schema['json_schema'] as Map<String, dynamic>;
      final innerSchema = jsonSchema['schema'] as Map<String, dynamic>;
      final problems = innerSchema['properties']['problems'] as Map<String, dynamic>;
      final items = problems['items'] as Map<String, dynamic>;

      final props = items['properties'] as Map<String, dynamic>;
      expect(props.containsKey('type'), isTrue);
      expect(props.containsKey('analysis'), isTrue);
      expect(props.containsKey('tag_name'), isTrue);
      expect(props.containsKey('current_reason'), isTrue);
      expect(props.containsKey('suggested_reason'), isTrue);
      expect(props.containsKey('current_prompt'), isTrue);
      expect(props.containsKey('suggested_prompt'), isTrue);
      expect(props.containsKey('suggested_tag'), isTrue);
      expect(props.containsKey('suggested_category'), isTrue);
      expect(props.containsKey('suggested_new_reason'), isTrue);

      // required 至少包含 type 和 analysis
      final required = items['required'] as List;
      expect(required, containsAll(['type', 'analysis']));
    });
  });

  group('AiPromptBuilder - 标签匹配 Schema', () {
    test('Schema 顶层结构正确', () {
      final schema = AiPromptBuilder.tagMatchResponseSchema;

      expect(schema['type'], equals('json_schema'));
      final jsonSchema = schema['json_schema'] as Map<String, dynamic>;
      expect(jsonSchema['name'], equals('tag_match'));
      expect(jsonSchema['strict'], isTrue);
    });

    test('Schema 包含 selected_tags 数组', () {
      final schema = AiPromptBuilder.tagMatchResponseSchema;
      final jsonSchema = schema['json_schema'] as Map<String, dynamic>;
      final innerSchema = jsonSchema['schema'] as Map<String, dynamic>;

      expect(innerSchema['required'], contains('selected_tags'));

      final selectedTags =
          innerSchema['properties']['selected_tags'] as Map<String, dynamic>;
      expect(selectedTags['type'], equals('array'));
    });

    test('selected_tags items 包含必要字段', () {
      final schema = AiPromptBuilder.tagMatchResponseSchema;
      final jsonSchema = schema['json_schema'] as Map<String, dynamic>;
      final innerSchema = jsonSchema['schema'] as Map<String, dynamic>;
      final selectedTags =
          innerSchema['properties']['selected_tags'] as Map<String, dynamic>;
      final items = selectedTags['items'] as Map<String, dynamic>;

      final props = items['properties'] as Map<String, dynamic>;
      expect(props.containsKey('name'), isTrue);
      expect(props.containsKey('category_id'), isTrue);
      expect(props.containsKey('match_reason'), isTrue);

      final required = items['required'] as List;
      expect(required, containsAll(['name', 'category_id', 'match_reason']));
    });
  });

  group('AiPromptBuilder - 标签自省模板渲染', () {
    test('tagIntrospection 渲染含所有变量', () {
      final result = AiPromptBuilder.tagIntrospection(
        usedTags: '【暴力美学】\n场景：打斗\n提示词：力量感',
        generatedContent: '他一拳打了过去',
        userFeedback: '打斗太干瘪',
      );

      expect(result.system, contains('诊断专家'));
      expect(result.system, contains('reason_adjust'));
      expect(result.system, contains('prompt_clarify'));
      expect(result.system, contains('missing_tag'));

      expect(result.user, contains('暴力美学'));
      expect(result.user, contains('他一拳打了过去'));
      expect(result.user, contains('打斗太干瘪'));
    });

    test('tagIntrospection 渲染不含变量原文模板标记', () {
      final result = AiPromptBuilder.tagIntrospection(
        usedTags: '标签内容',
        generatedContent: '内容',
        userFeedback: '反馈',
      );

      expect(result.user, isNot(contains('{{ used_tags }}')));
      expect(result.user, isNot(contains('{{ generated_content }}')));
      expect(result.user, isNot(contains('{{ user_feedback }}')));
    });
  });

  group('AiPromptBuilder - 标签匹配模板渲染', () {
    test('tagMatch 渲染含所有变量', () {
      final result = AiPromptBuilder.tagMatch(
        sceneDescription: '两人在山洞中对峙',
        availableTags: '【紧张对峙】场景：双方对峙\ncategory_id: 1',
      );

      expect(result.system, contains('匹配专家'));
      expect(result.system, contains('3-5'));

      expect(result.user, contains('两人在山洞中对峙'));
      expect(result.user, contains('紧张对峙'));
    });

    test('tagMatch 渲染不含变量原文模板标记', () {
      final result = AiPromptBuilder.tagMatch(
        sceneDescription: '场景',
        availableTags: '标签',
      );

      expect(result.user, isNot(contains('{{ scene_description }}')));
      expect(result.user, isNot(contains('{{ available_tags }}')));
    });
  });

  group('Golden 文件一致性', () {
    test('标签自省 Schema 可 JSON 序列化', () {
      final schema = AiPromptBuilder.tagIntrospectionResponseSchema;
      final json = jsonEncode(schema);

      expect(json, isNotEmpty);
      // 反序列化后应一致
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['type'], equals('json_schema'));
    });

    test('标签匹配 Schema 可 JSON 序列化', () {
      final schema = AiPromptBuilder.tagMatchResponseSchema;
      final json = jsonEncode(schema);

      expect(json, isNotEmpty);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['type'], equals('json_schema'));
    });
  });
}
