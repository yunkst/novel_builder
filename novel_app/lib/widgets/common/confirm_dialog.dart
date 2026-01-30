import 'package:flutter/material.dart';

/// 通用确认对话框
///
/// 提供标准的确认/取消对话框，支持自定义标题、内容、按钮文本和图标。
///
/// 示例:
/// ```dart
/// final confirmed = await ConfirmDialog.show(
///   context,
///   title: '确认删除',
///   message: '删除后无法恢复，是否继续？',
///   confirmText: '删除',
///   cancelText: '取消',
///   icon: Icons.delete,
/// );
/// ```
class ConfirmDialog extends StatelessWidget {
  /// 对话框标题
  final String title;

  /// 对话框内容信息（可选）
  final String? message;

  /// 确认按钮文本，默认为"确认"
  final String confirmText;

  /// 取消按钮文本，默认为"取消"
  final String cancelText;

  /// 对话框图标（可选）
  final IconData? icon;

  /// 确认按钮的颜色，默认使用主题色
  final Color? confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmText = '确认',
    this.cancelText = '取消',
    this.icon,
    this.confirmColor,
  });

  /// 显示确认对话框并返回用户选择
  ///
  /// 返回 `true` 表示用户点击确认，`false` 表示点击取消，`null` 表示对话框被关闭
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = '确认',
    String cancelText = '取消',
    IconData? icon,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              color: confirmColor ?? colorScheme.primary,
              size: 28,
            )
          : null,
      title: Text(title),
      content: message != null ? Text(message!) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmText,
            style: TextStyle(
              color: confirmColor ?? colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
