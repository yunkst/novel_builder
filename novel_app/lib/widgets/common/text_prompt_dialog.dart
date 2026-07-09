import 'package:flutter/material.dart';

/// 通用文本输入对话框
///
/// 用 StatefulWidget 内部管理 [TextEditingController] 生命周期（dispose 释放，
/// 避免泄漏），返回 trim 后的输入文本，null 表示用户取消。
///
/// 用法：
/// ```dart
/// final name = await TextPromptDialog.show(
///   context,
///   title: '重命名分组',
///   initialValue: currentName,
///   label: '分组名',
/// );
/// if (name != null && name.isNotEmpty) { ... }
/// ```
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    this.initialValue,
    this.label,
    this.confirmText = '保存',
    this.cancelText = '取消',
  });

  /// 弹出文本输入对话框。
  ///
  /// - 返回 trim 后的输入字符串（可能为空字符串）
  /// - 用户点击取消或关闭弹窗 → 返回 null
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialValue,
    String? label,
    String confirmText = '保存',
    String cancelText = '取消',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: title,
        initialValue: initialValue,
        label: label,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }

  final String title;
  final String? initialValue;
  final String? label;
  final String confirmText;
  final String cancelText;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text.trim();
    if (t.isNotEmpty) {
      Navigator.of(context).pop(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
