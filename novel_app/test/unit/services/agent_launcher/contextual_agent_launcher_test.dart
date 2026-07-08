library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/core/providers/agent_launcher_providers.dart';
import 'package:novel_app/core/providers/agent_scenario_provider.dart';
import 'package:novel_app/core/providers/scenario_session.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/services/agent_launcher/agent_launch_request.dart';
import 'package:novel_app/services/agent_launcher/contextual_agent_launcher.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';

@GenerateNiceMocks([MockSpec<ScenarioSessionsNotifier>(), MockSpec<ScenarioSession>()])
import 'contextual_agent_launcher_test.mocks.dart';

void main() {
  group('ContextualAgentLauncher.launch', () {
    testWidgets(
      'autoSend 模式: 切场景 + switchSession(id, null) + 调 sendMessage',
      (tester) async {
        final mockNotifier = MockScenarioSessionsNotifier();
        final mockSession = MockScenarioSession();

        when(mockNotifier.switchSession(any, any)).thenAnswer((_) async {});
        when(mockSession.sendMessage(any)).thenAnswer((_) async {});
        when(mockNotifier.get(any)).thenReturn(mockSession);

        late ProviderContainer container;
        late BuildContext capturedContext;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scenarioSessionsProvider.overrideWith((ref) {
                return _StubScenarioSessionsNotifier(
                  delegate: mockNotifier,
                  ref: ref,
                );
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    capturedContext = context;
                    container = ProviderScope.containerOf(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );

        final launcher = container.read(contextualAgentLauncherProvider);
        await launcher.launch(
          capturedContext,
          AgentLaunchRequest(
            scenarioId: ScenarioIds.webviewExtract,
            context: {'currentUrl': 'https://a.com/book/1'},
            draftMessage: '请生成提取脚本',
            mode: LaunchMode.autoSend,
          ),
        );
        await tester.pump();

        expect(
          container.read(currentAgentScenarioProvider),
          ScenarioIds.webviewExtract,
        );
        verify(mockNotifier.switchSession(ScenarioIds.webviewExtract, null))
            .called(1);
        // autoSend 模式必须调 sendMessage（draftOnly 不会）。
        // 注: dialog build 也会通过 currentSessionProvider 触发 get()，
        // 所以只断言 sendMessage 调用，不严格断言 get 次数。
        verify(mockSession.sendMessage('请生成提取脚本')).called(1);
      },
    );

    testWidgets(
      'draftOnly 模式: 切场景 + switchSession(id, null),不调 sendMessage',
      (tester) async {
        final mockNotifier = MockScenarioSessionsNotifier();
        final mockSession = MockScenarioSession();

        when(mockNotifier.switchSession(any, any)).thenAnswer((_) async {});
        // dialog build 会通过 currentSessionProvider 触发 get(),返回 mockSession
        when(mockNotifier.get(any)).thenReturn(mockSession);

        late ProviderContainer container;
        late BuildContext capturedContext;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              scenarioSessionsProvider.overrideWith((ref) {
                return _StubScenarioSessionsNotifier(
                  delegate: mockNotifier,
                  ref: ref,
                );
              }),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    capturedContext = context;
                    container = ProviderScope.containerOf(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );

        final launcher = container.read(contextualAgentLauncherProvider);
        await launcher.launch(
          capturedContext,
          AgentLaunchRequest(
            scenarioId: ScenarioIds.webviewExtract,
            context: {'currentUrl': 'https://a.com/book/1'},
            draftMessage: '请生成提取脚本',
            mode: LaunchMode.draftOnly,
          ),
        );
        await tester.pump();

        expect(
          container.read(currentAgentScenarioProvider),
          ScenarioIds.webviewExtract,
        );
        verify(mockNotifier.switchSession(ScenarioIds.webviewExtract, null))
            .called(1);
        // draftOnly 模式不会调 sendMessage
        verifyNever(mockSession.sendMessage(any));
      },
    );
  });
}

/// StateNotifier 子类桩: 解决 "Bad state, the provider did not initialize" 问题。
/// `overrideWith` 期望返回的 StateNotifier 有初始 state。
/// 这个 stub 把所有方法委托给 mockito mock，但提供初始 state。
class _StubScenarioSessionsNotifier extends ScenarioSessionsNotifier {
  final MockScenarioSessionsNotifier delegate;

  _StubScenarioSessionsNotifier({required this.delegate, required Ref ref})
      : super(ref);

  @override
  Future<void> switchSession(String scenarioId, int? newSessionId) {
    return delegate.switchSession(scenarioId, newSessionId);
  }

  @override
  ScenarioSession get(String scenarioId) => delegate.get(scenarioId);
}
