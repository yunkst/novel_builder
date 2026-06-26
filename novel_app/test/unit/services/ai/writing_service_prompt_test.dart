/// WritingService prompt 漂移检测测试
///
/// 跑 WritingService 的 createChapter 方法，断言产出的 prompt 与 golden 一致。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ai/writing_service.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';

import '../../../helpers/prompt_recording_mock.dart';

const _goldenDir = 'test/golden/dsl_prompts';

Future<Map<String, dynamic>> _readGolden(String name) async {
  final file = File('$_goldenDir/$name.json');
  if (!await file.exists()) return {};
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

/// 规范化 prompt 文本：CRLF→LF，strip 前后空白，strip 每行尾部空白
String _norm(String? s) {
  var text = (s ?? '').replaceAll('\r\n', '\n');
  text = text.split('\n').map((line) => line.trimRight()).join('\n');
  return text.trim();
}

/// 比较规范化后的 prompt 内容 + 精确比较 model/temperature/maxTokens
void expectPromptMatch(PromptSnapshot snapshot, Map<String, dynamic> golden) {
  expect(_norm(snapshot.systemPrompt), _norm(golden['system_prompt'] as String?),
      reason: 'system_prompt 内容漂移');
  expect(_norm(snapshot.userMessage), _norm(golden['user_message'] as String?),
      reason: 'user_message 内容漂移');
  expect(snapshot.model, equals(golden['model']));
  expect(snapshot.temperature, equals(golden['temperature']));
  expect(snapshot.maxTokens, equals(golden['max_tokens']));
}

void main() {
  late PromptRecordingMock mockClient;
  late WritingService service;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockClient = PromptRecordingMock();
    final config = LlmConfig(
      baseUrl: 'https://mock.test/v1',
      apiKey: 'test-key',
      defaultModel: 'test-model',
    );
    service = WritingService(
      provider: LlmProvider(config, httpClient: mockClient),
      defaultModel: 'deepseek-v4-pro',
    );
  });

  /// 消费 stream 并返回最后一次 LLM 调用的 snapshot
  Future<PromptSnapshot> runAndSnapshot(Stream<String> stream) async {
    mockClient.clear();
    await for (final _ in stream) {}
    expect(mockClient.recordedRequests, isNotEmpty,
        reason: 'WritingService 应至少发起一次 LLM 调用');
    return mockClient.lastSnapshot!;
  }

  group('WritingService prompt 漂移检测', () {
    test('createChapter: cmd="" 新建章节', () async {
      final snapshot = await runAndSnapshot(service.createChapter(
        aiWriterSetting: '文风偏古风，注重意境描写',
        backgroundSetting: '修仙世界，主角李明是青云门弟子',
        historyChaptersContent: '上一章：李明来到一座荒山，发现了一处隐秘洞穴。',
        roles: '李明：青云门弟子，性格坚毅',
        nextChapterOverview: '',
        userInput: '创建新章节，主角独自在山洞中修炼，突破瓶颈',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_empty_create'));
    });

    test('createOutlineDraft: cmd="生成细纲"', () async {
      final snapshot = await runAndSnapshot(service.createOutlineDraft(
        historyChaptersContent: '',
        outline: '第一卷：踏上征途',
        outlineItem: '',
        userInput: '为下一章生成细纲',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_generate_sub_outline'));
    });
  });
}