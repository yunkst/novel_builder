/// 任务 9 单元测试：subagentRunProvider + currentSubagentRunsProvider
///
/// 覆盖：
/// 1. subagentRunProvider 按 (sessionId, runId) 反查 SubagentRun
/// 2. 不存在时返回 null
/// 3. currentSubagentRunsProvider 在 sessionId=null 时返回空列表
/// 4. currentSubagentRunsProvider 在指定 sessionId 时返回该 session 派出的所有 run
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_app/core/providers/chat_session_providers.dart';
import 'package:novel_app/core/providers/subagent_providers.dart';
import 'package:novel_app/services/novel_agent/subagent_run.dart';

void main() {
  group('subagentRunProvider', () {
    test('按 (sessionId, runId) 反查', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(subagentRegistryProvider);
      final run = registry.create(
        parentSessionId: 's1',
        task: 't',
        allowedTools: const ['get_outline'],
        toolCallId: 'tc1',
      );

      final result =
          container.read(subagentRunProvider(('s1', run.runId)));
      expect(result, isA<SubagentRun>());
      expect(result, same(run));
      expect(result!.runId, run.runId);
      expect(result.parentSessionId, 's1');
      expect(result.task, 't');
    });

    test('不存在返回 null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(subagentRunProvider(('s1', 'no'))), isNull);
      expect(
          container.read(subagentRunProvider(('ghost', 'ghost'))), isNull);
    });

    test('sessionId 维度隔离：s1 的 runId 在 s2 查不到', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(subagentRegistryProvider);
      final run = registry.create(
        parentSessionId: 's1',
        task: 't',
        allowedTools: const [],
      );

      // 同 runId 跨 session 应查不到（registry 按 sessionId 索引）
      expect(container.read(subagentRunProvider(('s2', run.runId))), isNull);
      // 但在自己 session 内能找到
      expect(container.read(subagentRunProvider(('s1', run.runId))), same(run));
    });
  });

  group('currentSubagentRunsProvider', () {
    test('无 sessionId（null）返回空列表', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // currentChatSessionIdProvider 默认 null
      expect(container.read(currentChatSessionIdProvider), isNull);
      final result = container.read(currentSubagentRunsProvider);
      expect(result, isEmpty);
    });

    test('指定 sessionId 返回该 session 派出的 run 列表（按 createdAt 升序）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 设置 currentChatSessionIdProvider = 1
      container.read(currentChatSessionIdProvider.notifier).state = 1;

      final registry = container.read(subagentRegistryProvider);
      registry.create(parentSessionId: '1', task: 'a', allowedTools: const []);
      registry.create(parentSessionId: '1', task: 'b', allowedTools: const []);
      // 别的 session 不应混入
      registry.create(parentSessionId: '2', task: 'x', allowedTools: const []);

      final result = container.read(currentSubagentRunsProvider);
      expect(result, hasLength(2));
      expect(result.map((r) => r.task).toList(), ['a', 'b']);
      expect(result.every((r) => r.parentSessionId == '1'), isTrue);
    });

    test('sessionId 切换后列表随之刷新', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(subagentRegistryProvider);
      registry.create(parentSessionId: '7', task: 'a', allowedTools: const []);

      // 切到 session=7
      container.read(currentChatSessionIdProvider.notifier).state = 7;
      final result = container.read(currentSubagentRunsProvider);
      expect(result, hasLength(1));
      expect(result.first.task, 'a');

      // 切回 null
      container.read(currentChatSessionIdProvider.notifier).state = null;
      expect(container.read(currentSubagentRunsProvider), isEmpty);
    });
  });
}