import 'package:flutter/material.dart';

/// 通用输入对话框
///
/// 提供标准的单行输入对话框，支持自定义标题、提示文本、初始值和输入验证。
///
/// 示例:
/// ```dart
/// final result = await InputDialog.show(
///   context,
///   title: '输入章节标题',
///   hint: '请输入章节标题',
///   initialValue: currentTitle,
/// );
/// ```
class InputDialog extends StatefulWidget {
  /// 对话框标题
  final String title;

  /// 输入框提示文本
  final String? hint;

  /// 输入框初始值
  final String? initialValue;

  /// 最大行数，默认为1（单行输入）
  final int maxLines;

  /// 输入验证函数，返回错误提示文本，返回null表示验证通过
  final String? Function(String value)? validator;

  /// 输入框的键盘类型
  final TextInputType? keyboardType;

  /// 确认按钮文本，默认为"确定"
  final String confirmText;

  /// 取消按钮文本，默认为"取消"
  final String cancelText;

  const InputDialog({
    super.key,
    required this.title,
    this.hint,
    this.initialValue,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
    this.confirmText = '确定',
    this.cancelText = '取消',
  });

  /// 显示输入对话框并返回用户输入的内容
  ///
  /// 返回用户输入的字符串，点击取消或关闭返回 `null`
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    int maxLines = 1,
    String? Function(String value)? validator,
    TextInputType? keyboardType,
    String confirmText = '确定',
    String cancelText = '取消',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        hint: hint,
        initialValue: initialValue,
        maxLines: maxLines,
        validator: validator,
        keyboardType: keyboardType,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    final value = _controller.text.trim();

    if (widget.validator != null) {
      final error = widget.validator!(value);
      if (error != null) {
        setState(() => _errorText = error);
        return;
      }
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        autofocus: true,
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _handleConfirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
        TextButton(
          onPressed: _handleConfirm,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
