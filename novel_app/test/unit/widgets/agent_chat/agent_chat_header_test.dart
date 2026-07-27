import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_header.dart';

Widget _wrap(Widget child, {AgentChatState? state}) => MaterialApp(
      home: Scaffold(body: ProviderScope(overrides: [
        currentChatStateProvider.overrideWith((ref) => state ??
            const AgentChatState(
              scenarioId: ScenarioIds.writing,
              scenarioDisplayName: '小说写作助手',
            )),
      ], child: child)),
    );

void main() {
  testWidgets('writing 场景渲染 serif 标题 + 上下文行占位（未选小说）', (tester) async {
    await tester.pumpWidget(_wrap(const AgentChatHeader()));
    await tester.pumpAndSettle();
    expect(find.text('小说写作助手'), findsOneWidget);
    expect(find.textContaining('尚未选择小说'), findsOneWidget);
  });

  testWidgets('Header 含 历史/场景菜单/关闭 三按钮', (tester) async {
    await tester.pumpWidget(_wrap(const AgentChatHeader()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('会话历史'), findsOneWidget);
    expect(find.byTooltip('场景与设置'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
  });
}
