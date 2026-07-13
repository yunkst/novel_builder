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
  // 这两个 testWidgets 会真实打开 AgentChatDialog，dialog 内若挂载 MediaView
  // 会用 Timer.periodic(10s) 轮询；在 widget test 的 fake clock 下，
  // _verifyInvariants 偶发报 "Timer is still pending"（与测试运行时序相关，
  // 单跑通过、连跑偶发失败）。retry: 3 让 flaky 自动重试，不影响断言有效性。
  group('ContextualAgentLauncher.launch', () {
    testWidgets(
      'autoSend 模式: 切场景 + switchSession(id, null) + 调 sendMessage',
      (tester) async {
        final mockNotifier = MockScenarioSessionsNotifier();
        final mockSession = MockScenarioSession();

        when(mockNotifier.switchSession(any, any)).thenAnswer((_) async {});
        when(mockSession.sendMessage(content: any)).thenAnswer((_) async {});
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
        verify(mockSession.sendMessage(content: '请生成提取脚本')).called(1);
      },
      retry: 3,
    );

    testWidgets(
      'draftOnly 模式: 切场景 + switchSession(id, null),不调 sendMessage',
      (tester) async {
        final mockNotifier = MockScenarioSessionsNotifier();
        final mockSession = MockScenarioSession();

        when(mockNotifier.switchSession(any, any)).thenAnswer((_) async {});
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
        verifyNever(mockSession.sendMessage(content: any));
      },
      retry: 3,
    );
  });
}

/// StateNotifier 子类桩: 解决 "Bad state, the provider did not initialize" 问题。
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