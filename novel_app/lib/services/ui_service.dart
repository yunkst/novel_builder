/// UI服务层 - 对话框和Toast管理
///
/// 此文件提供UI交互服务，将对话框和Toast逻辑从UI层分离。
///
/// **架构原则**:
/// - UI层只触发事件
/// - 业务逻辑由 Riverpod Notifier 处理
/// - UI副作用通过 ref.listen 监听状态触发
library;

import 'package:flutter/material.dart';
import '../models/ai_companion_response.dart';
import '../widgets/reader/ai_companion_confirm_dialog.dart';

/// 对话框服务
///
/// 提供统一的对话框显示接口，方便测试和复用。
class DialogService {
  /// 显示AI伴读确认对话框
  ///
  /// [context] BuildContext
  /// [response] AI伴读响应数据
  /// 返回用户是否确认（true=确认，false=取消，null=对话框关闭）
  Future<bool?> showAICompanionConfirmDialog(
    BuildContext context,
    AICompanionResponse response,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AICompanionConfirmDialog(
        response: response,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  /// 显示通用确认对话框
  ///
  /// [context] BuildContext
  /// [title] 对话框标题
  /// [content] 对话框内容
  /// [confirmText] 确认按钮文本（默认"确认"）
  /// [cancelText] 取消按钮文本（默认"取消"）
  /// 返回用户是否确认（true=确认，false=取消，null=对话框关闭）
  Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确认',
    String cancelText = '取消',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示信息对话框
  ///
  /// [context] BuildContext
  /// [title] 对话框标题
  /// [content] 对话框内容
  Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
