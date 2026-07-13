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
Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      currentChatStateProvider.overrideWithValue(
        const AgentChatState(),
      ),
      currentSessionProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// 在 dialog 内查找指定 tooltip 的 IconButton。
IconButton? _findIconButtonByTooltip(WidgetTester tester, String tooltip) {
  final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
  for (final b in buttons) {
    if (b.tooltip == tooltip) return b;
  }
  return null;
}

void main() {
  group('AgentChatDialog 上传图片入口', () {
    testWidgets('输入栏渲染 + 附件按钮，tooltip=上传图片', (tester) async {
      await tester.pumpWidget(_wrap(const AgentChatDialog()));
      await tester.pump();
      final attachBtn = _findIconButtonByTooltip(tester, '上传图片');
      expect(attachBtn, isNotNull, reason: '应存在 + 附件按钮且 tooltip 为 上传图片');
      expect(attachBtn!.onPressed, isNotNull, reason: '非上传中状态 + 按钮应可点击');
    });

    testWidgets('无文本无图时发送按钮禁用，输入文本后启用', (tester) async {
      await tester.pumpWidget(_wrap(const AgentChatDialog()));
      await tester.pump();

      // 初始：无文本无图 -> 发送按钮禁用
      var sendBtn = _findIconButtonByTooltip(tester, '发送');
      expect(sendBtn, isNotNull);
      expect(sendBtn!.onPressed, isNull, reason: '无文本无图时发送按钮应禁用');

      // 输入文本 -> 发送按钮启用（验证 _hasText || _attachedMediaId != null
      // 的 _hasText 分支未被破坏）
      await tester.enterText(find.byType(TextField), '帮我生成插图');
      await tester.pump();

      sendBtn = _findIconButtonByTooltip(tester, '发送');
      expect(sendBtn, isNotNull);
      expect(sendBtn!.onPressed, isNotNull, reason: '有文本时发送按钮应启用');
    });
  });
}
