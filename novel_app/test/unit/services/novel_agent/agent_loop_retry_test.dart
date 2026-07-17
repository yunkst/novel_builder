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
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'package:novel_app/services/novel_agent/agent_loop.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/utils/cancellation_token.dart';
import 'package:novel_app/utils/retry_helper.dart';
import '../../../helpers/fake_agent_scenario.dart';
import '../../../helpers/noop_llm_http_client.dart';

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
          httpClient: NoopLlmHttpClient(),
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
class _FakeScenario extends BaseFakeAgentScenario {
  final List<({String name, Map<String, dynamic> args})> executed = [];

  @override
  String buildSystemPrompt(AgentScenarioContext context) => 'sys';

  @override
  Future<String> executeTool(
    String name,
    Map<String, dynamic> args, {
    void Function(int generatedChars)? onProgress,
    String? toolCallId,
  }) async {
    executed.add((name: name, args: Map<String, dynamic>.from(args)));
    return jsonEncode({'ok': true});
  }
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

    test('RetryableHttpException(429) → round 重试 → 成功', () async {
      // 自 2026-07-17 起所有 4xx/5xx 统一重试，429/408 只是历史最先纳入白名单的两种
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(
          429, 'rate limited', '',
          retryAfterMs: 50,
        ))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['限流后恢复']),
        );
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(networkRetryPerRound: 2),
      );
      final events = await runLoop(loop);
      expect(llm.callCount, 2, reason: '429 已被 RetryableHttpException 统一兜住');
      expect(events.last, isA<AgentDoneEvent>(),
          reason: '最终应完成而非 AgentError');
    });

    test('RetryableHttpException(408) → round 重试 → 成功（Request Timeout 同 429 路径）',
        () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(
          408, 'request timeout', '',
          retryAfterMs: 50,
        ))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['timeout 后恢复']),
        );
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
      );
      final events = await runLoop(loop);
      expect(llm.callCount, 2);
      expect(events.last, isA<AgentDoneEvent>());
    });

    test('RetryableHttpException(400) → round 重试 → 成功（业务 4xx 也统一重试）',
        () async {
      // 自 2026-07-17 起所有 4xx 统一重试：这里模拟代理网关偶发 400。
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(
          400, 'bad request', '',
          retryAfterMs: 50,
        ))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['400 后恢复']),
        );
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(networkRetryPerRound: 2),
      );
      final events = await runLoop(loop);
      expect(llm.callCount, 2, reason: '400 已被 round-level 接住，不再立即报 AgentError');
      expect(events.last, isA<AgentDoneEvent>());
    });

    test('RetryableHttpException(401) → round 重试 → 成功（鉴权 4xx 也统一重试）',
        () async {
      // 模拟 token 偶发过期 → round-level 兜底重试。
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(
          401, 'unauthorized', '',
          retryAfterMs: 50,
        ))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['鉴权后恢复']),
        );
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(networkRetryPerRound: 2),
      );
      final events = await runLoop(loop);
      expect(llm.callCount, 2);
      expect(events.last, isA<AgentDoneEvent>());
    });

    test('RetryableHttpException(401) → round 重试 → 成功（鉴权 4xx 也统一重试）',
        () async {
      // 模拟 token 偶发过期 → round-level 兜底重试。
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(
          401, 'unauthorized', '',
          retryAfterMs: 50,
        ))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['鉴权后恢复']),
        );
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(networkRetryPerRound: 2),
      );
      final events = await runLoop(loop);
      expect(llm.callCount, 2);
      expect(events.last, isA<AgentDoneEvent>());
    });
  });

  group('Round-level RetryEvent + RetrySignals 接线', () {
    setUp(() => RetrySignals.instance.resetForTest());
    tearDown(() => RetrySignals.instance.resetForTest());

    test('RetryableHttpException(503) → emit RetryEvent + RetrySignals.reportRound',
        () async {
      final emitted = <AgentEvent>[];
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(503, 'mt', ''))
        ..enqueue(
          response: const _ScriptedResponse(contentChunks: ['已恢复']),
        );
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(maxRounds: 5, networkRetryPerRound: 2),
      );
      await loop.run(
        initialMessages: const [ChatMessage(role: 'user', content: 'hi')],
        systemPrompt: 'sys',
        emit: emitted.add,
      );

      final retryEvents =
          emitted.whereType<RetryEvent>().toList(growable: false);
      expect(retryEvents, hasLength(1),
          reason: 'round-level 抛错一次 → emit RetryEvent 一次');
      expect(retryEvents.first.attempt, 1);
      expect(retryEvents.first.maxAttempts, 2,
          reason: 'maxAttempts 来自 _config.networkRetryPerRound');
      expect(retryEvents.first.errorCategory, '服务端 503');

      // loop 成功结束 → AgentDoneEvent 已 clear,横幅消失。
      // (RetrySignals 在 round-level 重试前已 reportRound,但 AgentDoneEvent
      // emit 后被 clear() — 通过下方断言确认时序)
      expect(RetrySignals.instance.notifier.value, isNull,
          reason: 'AgentDoneEvent 后 RetrySignals.clear()');
    });

    test('SocketException 抛尽 → AgentErrorEvent → RetrySignals.clear()',
        () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const SocketException('a'))
        ..enqueue(throwMode: const SocketException('b'))
        ..enqueue(throwMode: const SocketException('c'));
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(networkRetryPerRound: 2),
      );
      // 先制造一个 active state,验证 loop 结束(AgentErrorEvent)时被 clear
      RetrySignals.instance.reportRound(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        error: const SocketException('before-loop'),
      );
      expect(RetrySignals.instance.notifier.value, isNotNull,
          reason: 'sanity: signal 在 loop 前是 active');

      await loop.run(
        initialMessages: const [ChatMessage(role: 'user', content: 'hi')],
        systemPrompt: 'sys',
        emit: (e) {},
      );

      expect(RetrySignals.instance.notifier.value, isNull,
          reason: 'AgentErrorEvent 后 RetrySignals.clear()');
    });

    test('成功后 AgentDoneEvent → RetrySignals.clear()', () async {
      final llm = _ScriptedErrorLlm()
        ..enqueue(throwMode: const RetryableHttpException(503, 'mt', ''))
        ..enqueue(response: const _ScriptedResponse(contentChunks: ['ok']));
      final loop = AgentLoop(
        llm: llm,
        scenario: _FakeScenario(),
        config: const AgentLoopConfig(networkRetryPerRound: 2),
      );
      await loop.run(
        initialMessages: const [ChatMessage(role: 'user', content: 'hi')],
        systemPrompt: 'sys',
        emit: (e) {},
      );

      expect(RetrySignals.instance.notifier.value, isNull,
          reason: 'AgentDoneEvent 后 RetrySignals.clear()');
    });
  });
}