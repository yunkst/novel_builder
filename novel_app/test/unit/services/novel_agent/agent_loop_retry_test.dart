/// AgentLoop round-level 网络重试单元测试
///
/// 验证 PR2 引入的 round-level 重试：
/// - 瞬态网络错误（SocketException / RetryableHttpException / TimeoutException）
///   触发 round 重试，最终成功 → AgentDoneEvent
/// - 非瞬态错误（FormatException）→ 立即终止，emit AgentErrorEvent
/// - 超过 networkRetryPerRound → 终止
/// - 重试退避期间收到 CancellationToken → 优雅结束
///
/// 沿用 agent_loop_cancel_test.dart 的 Fake 模式，扩展 enqueue(throwMode: ...)
/// 以支持"某轮直接抛错而非 yield"。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/novel_agent/agent_loop_retry_test.dart
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'package:novel_app/services/novel_agent/agent_loop.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/utils/cancellation_token.dart';
import 'package:novel_app/utils/retry_helper.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// 可注入"抛错"脚本的假 LLM Provider
class _ScriptedErrorLlm extends LlmProvider {
  _ScriptedErrorLlm()
      : super(
          const LlmConfig(
            baseUrl: 'http://localhost',
            apiKey: 'test',
            defaultModel: 'test-model',
          ),
          httpClient: _NoopHttpClient(),
        );

  final List<_ScriptedItem> _script = [];
  int callCount = 0;

  /// 入队一条脚本：throwMode 非 null 表示该轮直接抛错；否则按 response yield
  void enqueue({Object? throwMode, _ScriptedResponse? response}) {
    assert(throwMode != null || response != null,
        'throwMode 与 response 至少一个非空');
    _script.add(_ScriptedItem(throwMode: throwMode, response: response));
  }

  @override
  Stream<LlmStreamChunk> chatStreamWithTools({
    required List<ChatMessage> messages,
    String? model,
    int? maxTokens,
    double? temperature,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
  }) async* {
    callCount++;
    if (_script.isEmpty) {
      throw StateError('_ScriptedErrorLlm 脚本已耗尽');
    }
    final item = _script.removeAt(0);
    if (item.throwMode != null) {
      // 短暂延迟模拟网络抖动后抛错
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await Future<void>.error(item.throwMode!);
      return;
    }
    final resp = item.response!;
    for (final chunk in resp.contentChunks) {
      yield LlmStreamChunk(contentChunk: chunk);
    }
    if (resp.toolCallDeltas != null) {
      yield LlmStreamChunk(
        toolCallDeltas: resp.toolCallDeltas!,
        finishReason: 'tool_calls',
      );
    } else {
      yield const LlmStreamChunk(finishReason: 'stop');
    }
  }
}

class _ScriptedItem {
  final Object? throwMode;
  final _ScriptedResponse? response;
  const _ScriptedItem({this.throwMode, this.response});
}

class _ScriptedResponse {
  final List<String> contentChunks;
  final List<Map<String, dynamic>>? toolCallDeltas;
  const _ScriptedResponse({
    this.contentChunks = const [],
    this.toolCallDeltas,
  });
}

/// 无参可调的最小假场景
class _FakeScenario with AgentScenarioCleanupMixin implements AgentScenario {
  @override
  final String id = 'fake';

  @override
  final String displayName = 'Fake';

  @override
  final List<Map<String, dynamic>> tools = const [];

  final List<({String name, Map<String, dynamic> args})> executed = [];

  @override
  String buildSystemPrompt(AgentScenarioContext context) => 'sys';

  @override
  Future<List<String>> getMemories() async => const [];

  @override
  Future<MemoryPatchResult> patchMemory(int? index, String newText) async =>
      MemoryPatchResult.error('x', const []);

  @override
  Future<String?> onNoToolCalls(List<ChatMessage> messages) async => null;

  @override
  Future<String> executeTool(
    String name,
    Map<String, dynamic> args, {
    void Function(int generatedChars)? onProgress,
  }) async {
    executed.add((name: name, args: Map<String, dynamic>.from(args)));
    return jsonEncode({'ok': true});
  }
}

class _NoopHttpClient implements LlmHttpClient {
  @override
  Future<String> postJson(
          String url, Map<String, String> headers, String body) =>
      throw UnimplementedError();

  @override
  Stream<String> postJsonStream(
          String url, Map<String, String> headers, String body) =>
      throw UnimplementedError();
}

Future<List<AgentEvent>> runLoop(
  AgentLoop loop, {
  CancellationToken? token,
}) async {
  final events = <AgentEvent>[];
  await loop.run(
    initialMessages: const [ChatMessage(role: 'user', content: 'hi')],
    systemPrompt: 'sys',
    emit: events.add,
    cancellationToken: token,
  );
  return events;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentLoop round-level 重试', () {
    test('SocketException → round 重试 → 第 2 次成功 → AgentDoneEvent', () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const SocketException('连接被重置'))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['完成']),
        );
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(
          maxRounds: 5,
          // 缩短退避以提速测试
          networkRetryPerRound: 2,
        ),
      );
      final events = await runLoop(loop);
      expect(llm.callCount, 2, reason: '首次抛错 → 重试 → 第二次成功');
      expect(events.last, isA<AgentDoneEvent>());
    });

    test('RetryableHttpException(503) → round 重试 → 成功', () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(503, 'mt', ''))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['已恢复']),
        );
      final loop = AgentLoop(llm: llm, scenario: _FakeScenario());
      final events = await runLoop(loop);
      expect(llm.callCount, 2);
      expect(events.last, isA<AgentDoneEvent>());
    });

    test('TimeoutException → 判为瞬态 → round 重试 → 成功', () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(
          throwMode: TimeoutException(
            'stream timeout',
            const Duration(milliseconds: 1),
          ),
        )
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['恢复了']),
        );
      final loop = AgentLoop(llm: llm, scenario: _FakeScenario());
      final events = await runLoop(loop);
      expect(llm.callCount, 2);
      expect(events.last, isA<AgentDoneEvent>());
    });

    test('FormatException → 立即终止 → AgentErrorEvent，callCount=1', () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const FormatException('JSON 损坏'));
      final loop = AgentLoop(llm: llm, scenario: _FakeScenario());
      final events = await runLoop(loop);
      expect(llm.callCount, 1, reason: '非瞬态错误不重试');
      expect(events.last, isA<AgentErrorEvent>());
      expect((events.last as AgentErrorEvent).error, contains('JSON 损坏'));
    });

    test('连续 3 次 SocketException → 超 networkRetryPerRound=2 → 终止',
        () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const SocketException('x'))
        ..enqueue(throwMode: const SocketException('x'))
        ..enqueue(throwMode: const SocketException('x'));
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(networkRetryPerRound: 2),
      );
      final events = await runLoop(loop);
      // 首次 + 2 次重试 = 3 次 LLM 调用均失败
      expect(llm.callCount, 3);
      expect(events.last, isA<AgentErrorEvent>());
    });

    test('重试退避期间收到取消 → 优雅结束（AgentDoneEvent），第 2 轮不调用',
        () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const SocketException('x'));
      final loop = AgentLoop(llm: llm, scenario: _FakeScenario());
      final token = CancellationToken();

      final events = <AgentEvent>[];
      // 异步在短延迟后取消（在 round_retry 退避等待期间）
      final runFuture = loop.run(
        initialMessages: const [ChatMessage(role: 'user', content: 'hi')],
        systemPrompt: 'sys',
        emit: events.add,
        cancellationToken: token,
      );
      Future<void>.delayed(
        const Duration(milliseconds: 50),
        () => token.cancel(reason: '测试取消'),
      );
      await runFuture;

      expect(token.isCancelled, true);
      expect(events.last, isA<AgentDoneEvent>(),
          reason: '退避期间取消应优雅结束而非 AgentError');
      // 第 1 次抛错 → 退避等待 → 取消 → 不再调第 2 次
      expect(llm.callCount, 1);
    });

    test('重试成功后 roundRetryCount 重置（连续两轮瞬态错误均能恢复）',
        () async {
      // 第 1 轮：抛错 → 重试 → 成功（带 tool_call）
      // 第 2 轮（工具返回后）：抛错 → 重试 → 成功（文本结束）
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const SocketException('round0 失败'))
        ..enqueue(
          response: const _ScriptedResponse(
            toolCallDeltas: [
              {
                'index': 0,
                'id': 'c1',
                'function': {'name': 'foo', 'arguments': '{}'},
              },
            ],
          ),
        )
        ..enqueue(throwMode: const SocketException('round1 失败'))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['最终完成']),
        );
      final scenario = _FakeScenario();
      final loop = AgentLoop(
        llm: llm,
        scenario: scenario,
        config: const AgentLoopConfig(maxRounds: 10, networkRetryPerRound: 2),
      );
      final events = await runLoop(loop);
      // 4 次 LLM 调用：round0 失败+成功，round1 失败+成功
      expect(llm.callCount, 4);
      // 工具被调用过
      expect(scenario.executed, hasLength(1));
      expect(events.last, isA<AgentDoneEvent>());
    });
  });
}