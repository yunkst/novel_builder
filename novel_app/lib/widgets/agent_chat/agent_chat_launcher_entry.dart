/// Agent 对话框编程式展开入口
///
/// 从 [AgentFloatingButton._showChatDialog] 抽出的公共函数，
/// 供 ContextualAgentLauncher 等非悬浮按钮入口复用。
library;

import 'package:flutter/material.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_dialog.dart';

class AgentChatLauncherEntry {
  AgentChatLauncherEntry._();

  /// 打开 AgentChatDialog
  ///
  /// [initialDraft] 非空时预填输入框（draftOnly 模式用）。
  static void open(BuildContext context, {String? initialDraft}) {
    showDialog(
      context: context,
      builder: (context) => AgentChatDialog(initialDraft: initialDraft),
    );
  }
}
