/// RetryEvent + subagent_state_projector/scenario_session switch 接线
///
/// 验证:
/// - RetryEvent extends AgentEvent,含 super.runId
/// - EventTagger.tag(RetryEvent(...), runId) 转发 runId
/// - SubagentStateProjector.project 接 RetryEvent 不抛(no-op 兜底)
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/novel_agent/agent_retry_event_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'package:novel_app/services/novel_agent/subagent_state_projector.dart';
import 'package:novel_app/services/novel_agent/subagent_run.dart';

void main() {
  group('RetryEvent', () {
    test('含 super.runId 转发(EventTagger 打标前置)', () {
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
      );
      expect(e.attempt, 1);
      expect(e.maxAttempts, 2);
      expect(e.delayMs, 1000);
      expect(e.errorCategory, '限流');
      expect(e.runId, isNull);
    });

    test('显式 runId', () {
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
        runId: 'sub-1',
      );
      expect(e.runId, 'sub-1');
    });
  });

  group('EventTagger.tag(RetryEvent)', () {
    test('转发 runId', () {
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
      );
      final tagged = EventTagger.tag(e, 'sub-1');
      expect(tagged, isA<RetryEvent>());
      expect(tagged.runId, 'sub-1');
    });
  });

  group('SubagentStateProjector.project(RetryEvent)', () {
    test('no-op:不抛、不改 state', () {
      // SubagentRun 实际构造需要 runId / parentSessionId / task /
      // allowedTools / toolCallId（无 scenarioId）。
      final run = SubagentRun(
        runId: 'r',
        parentSessionId: 'p',
        task: 't',
        allowedTools: const [],
        toolCallId: 'tc',
      );
      // 初始 chatState（引用快照）
      final before = run.chatState;
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
      );
      SubagentStateProjector.project(e, run);
      // 不变(no-op)
      expect(run.chatState, before);
    });
  });
}
