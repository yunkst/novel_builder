/// InfoExtractionService 新方法测试
///
/// 验证 tagIntrospection 和 tagMatch 方法：
/// - 调用 LLM 并传入正确的 responseFormat
/// - system prompt 包含预期内容
/// - user prompt 包含传入的变量
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ai/info_extraction_service.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';

import '../../../helpers/prompt_recording_mock.dart';

String _norm(String? s) {
  var text = (s ?? '').replaceAll('\r\n', '\n');
  text = text.split('\n').map((line) => line.trimRight()).join('\n');
  return text.trim();
}

void main() {
  late PromptRecordingMock mockClient;
  late InfoExtractionService service;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockClient = PromptRecordingMock();
    final config = LlmConfig(
      baseUrl: 'https://mock.test/v1',
      apiKey: 'test-key',
      defaultModel: 'test-model',
    );
    service = InfoExtractionService(
      provider: LlmProvider(config, httpClient: mockClient),
      defaultModel: 'deepseek-v4-pro',
    );
  });

  /// 设置自省 mock 响应（有效 JSON），然后调用并返回 prompt 快照
  Future<PromptSnapshot> runIntrospection(
      Future<Map<String, dynamic>> Function() fn) async {
    mockClient.setMockContent(jsonEncode({
      'problems': [
        {'type': 'reason_adjust', 'analysis': 'mock'}
      ],
    }));
    await fn();
    expect(mockClient.recordedRequests, isNotEmpty,
        reason: '应至少发起一次 LLM 调用');
    return mockClient.lastSnapshot!;
  }

  /// 设置匹配 mock 响应（有效 JSON），然后调用并返回 prompt 快照
  Future<PromptSnapshot> runMatch(
      Future<Map<String, dynamic>> Function() fn) async {
    mockClient.setMockContent(jsonEncode({
      'selected_tags': [
        {'name': 'mock', 'category_id': 1, 'match_reason': 'mock'}
      ],
    }));
    await fn();
    expect(mockClient.recordedRequests, isNotEmpty,
        reason: '应至少发起一次 LLM 调用');
    return mockClient.lastSnapshot!;
  }

  group('tagIntrospection', () {
    test('传入 JSON Schema responseFormat', () async {
      final snapshot = await runIntrospection(() => service.tagIntrospection(
            usedTags: '【暴力美学】\n场景：打斗\n提示词：注重力量感',
            generatedContent: '他一拳打了过去',
            userFeedback: '打斗太干瘪，缺乏画面感',
          ));

      expect(snapshot.responseFormat, isNotNull);
      expect(snapshot.responseFormat!['type'], equals('json_schema'));
      final jsonSchema = snapshot.responseFormat!['json_schema'] as Map;
      expect(jsonSchema['name'], equals('tag_introspection'));
      expect(jsonSchema['strict'], isTrue);
    });

    test('system prompt 包含自省诊断核心指令', () async {
      final snapshot = await runIntrospection(() => service.tagIntrospection(
            usedTags: '【暴力美学】\n场景：打斗',
            generatedContent: '生成的内容',
            userFeedback: '反馈',
          ));

      expect(_norm(snapshot.systemPrompt), contains('诊断专家'));
      expect(_norm(snapshot.systemPrompt), contains('reason_adjust'));
      expect(_norm(snapshot.systemPrompt), contains('prompt_clarify'));
      expect(_norm(snapshot.systemPrompt), contains('missing_tag'));
      expect(_norm(snapshot.systemPrompt), contains('name'));
      expect(_norm(snapshot.systemPrompt), contains('reason'));
      expect(_norm(snapshot.systemPrompt), contains('promptText'));
    });

    test('user prompt 包含标签、内容和反馈', () async {
      final snapshot = await runIntrospection(() => service.tagIntrospection(
            usedTags: '【暴力美学】\n场景：打斗',
            generatedContent: '他一拳打了过去',
            userFeedback: '打斗太干瘪',
          ));

      expect(_norm(snapshot.userMessage), contains('暴力美学'));
      expect(_norm(snapshot.userMessage), contains('他一拳打了过去'));
      expect(_norm(snapshot.userMessage), contains('打斗太干瘪'));
    });

    test('model 和 maxTokens 正确', () async {
      final snapshot = await runIntrospection(() => service.tagIntrospection(
            usedTags: '标签',
            generatedContent: '内容',
            userFeedback: '反馈',
          ));

      expect(snapshot.model, equals('deepseek-v4-pro'));
      expect(snapshot.maxTokens, equals(8192));
    });
  });

  group('tagMatch', () {
    test('传入 JSON Schema responseFormat', () async {
      final snapshot = await runMatch(() => service.tagMatch(
            sceneDescription: '两人在山洞中对峙',
            availableTags: '【紧张对峙】场景：双方对峙',
          ));

      expect(snapshot.responseFormat, isNotNull);
      expect(snapshot.responseFormat!['type'], equals('json_schema'));
      final jsonSchema = snapshot.responseFormat!['json_schema'] as Map;
      expect(jsonSchema['name'], equals('tag_match'));
      expect(jsonSchema['strict'], isTrue);
    });

    test('system prompt 包含匹配核心指令', () async {
      final snapshot = await runMatch(() => service.tagMatch(
            sceneDescription: '场景',
            availableTags: '标签列表',
          ));

      expect(_norm(snapshot.systemPrompt), contains('匹配专家'));
      expect(_norm(snapshot.systemPrompt), contains('reason'));
      expect(_norm(snapshot.systemPrompt), contains('3-5'));
    });

    test('user prompt 包含场景描述和标签列表', () async {
      final snapshot = await runMatch(() => service.tagMatch(
            sceneDescription: '两人在山洞中对峙',
            availableTags: '【紧张对峙】场景：双方对峙\ncategory_id: 1',
          ));

      expect(_norm(snapshot.userMessage), contains('两人在山洞中对峙'));
      expect(_norm(snapshot.userMessage), contains('紧张对峙'));
    });
  });
}
