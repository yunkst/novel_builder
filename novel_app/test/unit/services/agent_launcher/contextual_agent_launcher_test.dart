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
  // 会启动 Timer.periodic(10s) 轮询；测试结束前若不关闭 dialog，MediaView 不卸载、
  // timer 不 cancel，_verifyInvariants 会报 "Timer is still pending"（CI 上必现）。
  // 根治：每个用例末尾 pop dialog 并 pump 到 dismiss 完成，让 MediaView dispose 取消 timer。
  // retry: 3 作为额外保险（环境抖动时不影响断言有效性）。
  group('ContextualAgentLauncher.launch', () {
    testWidgets(
      'autoSend 模式: 切场景 + switchSession(id, null) + 调 sendMessage',
      (tester) async {
        final mockNotifier = MockScenarioSessionsNotifier();
        final mockSession = MockScenarioSession();

        when(mockNotifier.switchSession(any, any)).thenAnswer((_) async {});
        when(mockSession.sendMessage(content: anyNamed('content')))
            .thenAnswer((_) async {});
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

        // 关闭 launcher 打开的 dialog：让其中 MediaView 卸载、cancel 其
        // Timer.periodic，否则 _verifyInvariants 会因 timersPending 失败（CI 必现根因）。
        Navigator.of(capturedContext, rootNavigator: true).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
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
        verifyNever(mockSession.sendMessage(content: anyNamed('content')));

        // 关闭 launcher 打开的 dialog：让其中 MediaView 卸载、cancel 其
        // Timer.periodic，否则 _verifyInvariants 会因 timersPending 失败（CI 必现根因）。
        Navigator.of(capturedContext, rootNavigator: true).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
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