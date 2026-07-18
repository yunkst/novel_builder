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

/// 在 dialog 内查找包含指定文本的 TextButton（适用于 TextButton.icon）。
/// 注意：find.byType(TextButton) 匹配的是 runtimeType，TextButton.icon 的
/// runtimeType 是 _TextButtonWithIcon（extends TextButton），byType 无法匹配。
/// 必须使用 byWidgetPredicate + is 检查 + ancestor 查找子文本。
TextButton? _findTextButtonByText(WidgetTester tester, String text) {
  final finder = find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((w) => w is TextButton),
  );
  final elements = finder.evaluate().toList();
  if (elements.isEmpty) return null;
  return elements.first.widget as TextButton;
}

void main() {
  // 输入栏右侧二态按钮（A 方案，2026-07-18）：
  //   有文本 OR 有图     -> 发送（运行中为"补充到下一轮"）
  //   完全空 (无文无图)  -> 添加图片
  // 停止操作已迁移至输入栏上方的独立停止条 _buildStopBar。
  group('AgentChatDialog 输入栏二态按钮 + 停止条', () {
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

    testWidgets('LLM 运行时显示停止条（_buildStopBar），不在右下角', (tester) async {
      await tester.pumpWidget(
        _wrap(state: const AgentChatState(isLoading: true)),
      );
      await tester.pump();

      // 停止条存在：_buildStopBar 内有一个 TextButton.icon 标签为「停止」
      expect(_findTextButtonByText(tester, '停止'), isNotNull,
          reason: '运行中应显示停止条，包含一个 TextButton「停止」');

      // 右下角不再有停止按钮（_TrailingMode.stop 已移除）
      expect(_findIconButtonByTooltip(tester, '停止'), isNull,
          reason: '右下角不应再有停止 IconButton');

      // 右下角空状态应显示添加图片按钮（A 方案二态）
      expect(_findIconButtonByTooltip(tester, '添加图片'), isNotNull);

      // 运行中输入文字后：右下角切为发送（补充到下一轮），停止条仍在
      await tester.enterText(find.byType(TextField), '排队等待的消息');
      await tester.pump();
      expect(_findTextButtonByText(tester, '停止'), isNotNull,
          reason: '停止条在输入文字后仍应存在');
      expect(_findIconButtonByTooltip(tester, '补充到下一轮'), isNotNull,
          reason: '运行中有文本时右下角应显示补充到下一轮');
    });

    testWidgets('session 为 null 时停止条仍渲染但停止按钮禁用', (tester) async {
      // 通过 override currentSessionProvider 返回 null 模拟无 session
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWith((ref) => null),
          ],
          child: _wrap(state: const AgentChatState(isLoading: true)),
        ),
      );
      await tester.pump();

      // 停止条存在
      final stopBtn = _findTextButtonByText(tester, '停止');
      expect(stopBtn, isNotNull);
      // onPressed 为 null → 按钮禁用
      expect(stopBtn!.onPressed, isNull,
          reason: 'session 为 null 时停止按钮应被禁用');
    });

    testWidgets('运行中 + 补充计数 > 0 时，停止条和补充条同时显示且补充条无停止按钮',
        (tester) async {
      await tester.pumpWidget(
        _wrap(state: const AgentChatState(
          isLoading: true,
          supplementaryCount: 3,
        )),
      );
      await tester.pump();

      // 停止条存在（仅停止条中有一个 TextButton「停止」）
      expect(_findTextButtonByText(tester, '停止'), isNotNull,
          reason: '仅停止条中有停止按钮，补充条已移除停止按钮');

      // 补充条文字可见
      expect(find.text('已补充 3 条消息，将在下一轮处理'), findsOneWidget);
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
