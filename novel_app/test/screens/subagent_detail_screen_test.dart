import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/subagent_providers.dart';
import 'package:novel_app/screens/subagent_detail_screen.dart';
import 'package:novel_app/services/novel_agent/subagent_run.dart';
import 'package:novel_app/utils/cancellation_token.dart';

void main() {
  group('SubagentDetailScreen', () {
    testWidgets('显示 task 标题、allowedTools chips、状态', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(subagentRegistryProvider);
      final run = registry.create(
        parentSessionId: 's1',
        task: '梳理人物',
        allowedTools: const ['get_outline', 'read_chapter'],
        toolCallId: 'tc1',
      );
      run.state = SubagentRunState.running;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SubagentDetailScreen(sessionId: 's1', toolCallId: 'tc1'),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('梳理人物'), findsWidgets);
      expect(find.text('get_outline'), findsOneWidget);
      expect(find.text('read_chapter'), findsOneWidget);
      // 状态 chip 文案 'running'
      expect(find.text('running'), findsWidgets);
    });

    testWidgets('running 状态显示停止按钮，点击触发 cancel', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(subagentRegistryProvider);
      final run = registry.create(
        parentSessionId: 's1',
        task: 't',
        allowedTools: const [],
        toolCallId: 'tc1',
      );
      run.state = SubagentRunState.running;
      run.tokenSource = CancellationTokenSource();

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SubagentDetailScreen(sessionId: 's1', toolCallId: 'tc1'),
        ),
      ));
      await tester.pump();

      final stopBtn = find.byIcon(Icons.stop);
      expect(stopBtn, findsOneWidget);

      await tester.tap(stopBtn);
      await tester.pump();

      expect(run.tokenSource?.isCancelled, isTrue);
    });

    testWidgets('completed 状态不显示停止按钮', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final registry = container.read(subagentRegistryProvider);
      final run = registry.create(
        parentSessionId: 's1',
        task: 't',
        allowedTools: const [],
        toolCallId: 'tc1',
      );
      run.state = SubagentRunState.completed;

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SubagentDetailScreen(sessionId: 's1', toolCallId: 'tc1'),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsNothing);
    });

    testWidgets('run 不存在时显示占位文案', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SubagentDetailScreen(sessionId: 's1', toolCallId: 'missing'),
        ),
      ));
      await tester.pump();

      expect(find.text('子 Agent 不存在或已清理'), findsOneWidget);
    });
  });
}
