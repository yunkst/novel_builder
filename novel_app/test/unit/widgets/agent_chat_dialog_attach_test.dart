library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_dialog.dart';

/// 测试辅助：用安全 overrides 包装 AgentChatDialog，避免 ScenarioSessionsNotifier
/// 在初始化阶段触发 "modify other providers" 断言（dialog build 时会
/// read currentSessionProvider，懒创建会立即 setState 触发跨 provider 修改）。
Widget _wrap({AgentChatState? state}) {
  return ProviderScope(
    overrides: [
      currentChatStateProvider.overrideWithValue(
        state ?? const AgentChatState(),
      ),
      currentSessionProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      home: Scaffold(body: const AgentChatDialog()),
    ),
  );
}

/// 在 dialog 内查找指定 tooltip 的 IconButton。
IconButton? _findIconButtonByTooltip(WidgetTester tester, String tooltip) {
  for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
    if (b.tooltip == tooltip) return b;
  }
  return null;
}

void main() {
  // 输入栏重构（2026-07-16）后右侧三态按钮的状态机：
  //   isLoading (运行中)  -> 停止
  //   有文本 OR 有图     -> 发送
  //   完全空 (无文无图)  -> 添加图片
  group('AgentChatDialog 输入栏三态按钮', () {
    testWidgets('完全空时显示「添加图片」按钮，可点击', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      final attachBtn = _findIconButtonByTooltip(tester, '添加图片');
      expect(attachBtn, isNotNull, reason: '空状态右侧应显示 + 添加图片按钮');
      expect(attachBtn!.onPressed, isNotNull, reason: '非上传中 + 按钮应可点击');
      // 此时不应有发送/停止按钮
      expect(_findIconButtonByTooltip(tester, '发送'), isNull);
      expect(_findIconButtonByTooltip(tester, '停止'), isNull);
    });

    testWidgets('输入文本后切换为「发送」按钮，可点击', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.enterText(find.byType(TextField), '帮我生成插图');
      // 等待 AnimatedSwitcher 的 attach→send 过渡完全结束，否则淡出中的
      // 旧「添加图片」按钮仍挂在 tree 里，导致「已消失」断言误判。
      await tester.pumpAndSettle();

      final sendBtn = _findIconButtonByTooltip(tester, '发送');
      expect(sendBtn, isNotNull, reason: '有文本时右侧应显示发送按钮');
      expect(sendBtn!.onPressed, isNotNull, reason: '有文本发送按钮应可点击');
      // 此时添加图片按钮消失
      expect(_findIconButtonByTooltip(tester, '添加图片'), isNull);
    });

    testWidgets('LLM 运行时显示「停止」按钮，运行态覆盖文本/图片态',
        (tester) async {
      await tester.pumpWidget(
        _wrap(state: const AgentChatState(isLoading: true)),
      );
      await tester.pump();
      final stopBtn = _findIconButtonByTooltip(tester, '停止');
      expect(stopBtn, isNotNull, reason: '运行中右侧应显示停止按钮');
      expect(stopBtn!.onPressed, isNotNull, reason: '停止按钮应可点击');
      expect(_findIconButtonByTooltip(tester, '发送'), isNull);
      expect(_findIconButtonByTooltip(tester, '添加图片'), isNull);

      // 运行中输入文字也不应让按钮切到发送态（运行态最高优先级）
      await tester.enterText(find.byType(TextField), '排队等待的消息');
      await tester.pump();
      expect(_findIconButtonByTooltip(tester, '停止'), isNotNull,
          reason: '运行态期间即便有文本仍应是停止按钮');
      expect(_findIconButtonByTooltip(tester, '发送'), isNull);
    });

    testWidgets('运行中文本框可输入（enabled=true）', (tester) async {
      await tester.pumpWidget(
        _wrap(state: const AgentChatState(isLoading: true)),
      );
      await tester.pump();
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue,
          reason: '运行中输入框应仍可输入（用于排队下一条消息）');
    });
  });
}
