import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/widgets/agent_chat/agent_status_strip.dart';

const _retry = RetryState(
  level: RetryLevel.transport,
  attempt: 2,
  maxAttempts: 8,
  delayMs: 7000,
  errorCategory: RetryErrorCategory.rateLimited,
  httpStatusCode: 429,
);

void main() {
  test('idle（无 error/retry/supplement）-> null', () {
    expect(selectStatus(const AgentChatState(), null), isNull);
  });

  test('error 且 !isLoading -> error', () {
    final s = selectStatus(const AgentChatState(error: 'boom'), null);
    expect(s?.kind, AgentStatusKind.error);
    expect(s?.message, 'boom');
  });

  test('error 且 isLoading -> 不返 error（让位 retry/running）', () {
    final s = selectStatus(
        const AgentChatState(error: 'boom', isLoading: true), null);
    expect(s?.kind, isNot(AgentStatusKind.error));
  });

  test('retry 非 null -> retry，含 attempt/maxAttempts + 类别 + HTTP', () {
    final s = selectStatus(const AgentChatState(), _retry);
    expect(s?.kind, AgentStatusKind.retry);
    expect(s?.detail, contains('2/8'));
    expect(s?.detail, contains('限流'));
    expect(s?.detail, contains('HTTP 429'));
    expect(s?.countdownSeconds, 7);
  });

  test('isLoading + supplementaryCount>0 + 无 retry -> supplement', () {
    final s = selectStatus(
        const AgentChatState(isLoading: true, supplementaryCount: 3), null);
    expect(s?.kind, AgentStatusKind.supplement);
    expect(s?.message, contains('3'));
  });

  test('error 压 retry（同时存在 -> error）', () {
    final s = selectStatus(const AgentChatState(error: 'boom'), _retry);
    expect(s?.kind, AgentStatusKind.error);
  });

  test('retry 压 supplement', () {
    final s = selectStatus(
        const AgentChatState(isLoading: true, supplementaryCount: 3), _retry);
    expect(s?.kind, AgentStatusKind.retry);
  });

  test('retry round 层 -> detail 标「回合层」', () {
    final r = RetryState(
      level: RetryLevel.round,
      attempt: 1,
      maxAttempts: 3,
      delayMs: 2000,
      errorCategory: RetryErrorCategory.serverError,
      httpStatusCode: 502,
    );
    final s = selectStatus(const AgentChatState(), r);
    expect(s?.detail, contains('回合层'));
  });
}
