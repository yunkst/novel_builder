/// WritingService prompt 漂移检测测试
///
/// 跑 WritingService 的 9 个方法，断言产出的 prompt 与 test/golden/dsl_prompts/*.json 一致。
/// 规范化比较（CRLF→LF + trim）以消除 Jinja 渲染的换行差异。
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
    test('fullRewrite: cmd="" 全文重写', () async {
      final snapshot = await runAndSnapshot(service.fullRewrite(
        aiWriterSetting: '文风偏古风，注重意境描写',
        backgroundSetting: '修仙世界，主角李明是青云门弟子',
        historyChaptersContent: '上一章：李明告别了师父，踏上了寻找天书的旅程。',
        currentChapterContent: '月光洒在古道上，李明独自前行。远处的灯火若隐若现，他加快了脚步。',
        roles: '李明：青云门弟子，性格坚毅；师父：已故，留下遗言',
        nextChapterOverview: '',
        userInput: '请重写这一章的结尾，让主角在雨夜中遇到神秘老人',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_empty_rewrite'));
    });

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

    test('closeup: cmd="特写"', () async {
      final snapshot = await runAndSnapshot(service.closeup(
        aiWriterSetting: '文风偏古风',
        backgroundSetting: '修仙世界',
        historyChaptersContent: '',
        currentChapterContent: '李明盘膝而坐，灵力在体内流转。',
        roles: '',
        nextChapterOverview: '',
        userInput: '描写李明突破时体内灵力奔涌的感觉',
        choiceContent: '', // 特写场景 choice_content 为空
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_closeup'));
    });

    test('summarize: cmd="总结"', () async {
      final snapshot = await runAndSnapshot(service.summarize(
        currentChapterContent: '李明在山洞中修炼，突破至筑基期。他感受到灵力质变，体内经脉全部打通。',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_summary'));
    });

    test('sceneDescription: cmd="场景描写"', () async {
      final snapshot = await runAndSnapshot(service.sceneDescription(
        currentChapterContent: '李明走进洞穴，四周漆黑一片。',
        roles: '李明：青云门弟子',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_scene_description'));
    });

    test('generateOutline: cmd="生成大纲"', () async {
      final snapshot = await runAndSnapshot(service.generateOutline(
        backgroundSetting: '修仙世界，主角李明是青云门弟子，寻找天书',
        outline: '',
        userInput: '为这部小说生成全书大纲',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_generate_outline'));
    });

    test('generateSubOutline: cmd="生成细纲"', () async {
      final snapshot = await runAndSnapshot(service.generateSubOutline(
        historyChaptersContent: '',
        outline: '第一卷：踏上征途',
        outlineItem: '',
        userInput: '为下一章生成细纲',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_generate_sub_outline'));
    });

    test('chat: cmd="聊天"', () async {
      final snapshot = await runAndSnapshot(service.chat(
        roles: '李明：青云门弟子',
        scene: '',
        chatHistory: '',
        userInput: '你觉得李明接下来会遇到什么挑战？',
        choiceContent: '',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_chat'));
    });

    test('settingSummary: cmd="设定总结"', () async {
      final snapshot = await runAndSnapshot(service.settingSummary(
        backgroundSetting: '修仙世界，有五大宗门，灵气分九品',
      ));
      expectPromptMatch(snapshot, await _readGolden('cmd_setting_summary'));
    });
  });
}
