import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 通用输入对话框
///
/// 提供标准的输入对话框，支持单行/多行输入、输入验证、自定义键盘类型等功能。
///
/// 功能特性：
/// - 统一的Material Design 3风格
/// - 支持单行和多行输入
/// - 支持输入验证和错误提示
/// - 支持自定义键盘类型
/// - 自动聚焦输入框
/// - 支持提交快捷键（Ctrl+Enter / Enter）
/// - 继承BaseDialog，保持UI一致性
///
/// 示例:
/// ```dart
/// final result = await InputDialog.show(
///   context,
///   title: '输入章节标题',
///   hint: '请输入章节标题',
///   initialValue: currentTitle,
/// );
/// if (result != null) {
///   print('用户输入: $result');
/// }
/// ```
///
/// 多行输入示例:
/// ```dart
/// final result = await InputDialog.show(
///   context,
///   title: '输入描述',
///   hint: '请输入详细描述',
///   maxLines: 5,
///   minLines: 3,
/// );
/// ```
///
/// 带验证示例:
/// ```dart
/// final result = await InputDialog.show(
///   context,
///   title: '输入URL',
///   hint: '请输入有效的URL',
///   keyboardType: TextInputType.url,
///   validator: (value) {
///     if (value.isEmpty) return 'URL不能为空';
///     if (!Uri.tryParse(value).hasAbsolutePath) return 'URL格式不正确';
///     return null;
///   },
/// );
/// ```
class InputDialog extends StatefulWidget {
  /// 对话框标题
  final String title;

  /// 输入框提示文本
  final String? hint;

  /// 输入框初始值
  final String? initialValue;

  /// 输入框帮助文本（显示在输入框下方）
  final String? helperText;

  /// 最大行数，默认为1（单行输入）
  final int maxLines;

  /// 最小行数（仅在maxLines>1时有效）
  final int? minLines;

  /// 输入验证函数，返回错误提示文本，返回null表示验证通过
  final String? Function(String value)? validator;

  /// 输入框的键盘类型
  final TextInputType? keyboardType;

  /// 文本输入格式（如限制数字、邮箱等）
  final List<TextInputFormatter>? inputFormatters;

  /// 确认按钮文本，默认为"确定"
  final String confirmText;

  /// 取消按钮文本，默认为"取消"
  final String cancelText;

  /// 输入框的前缀图标
  final IconData? prefixIcon;

  /// 输入框的后缀图标
  final Widget? suffixIcon;

  /// 是否自动聚焦
  final bool autofocus;

  /// 是否显示计数器（当前字数/最大字数）
  final bool showCounter;

  /// 最大字符数限制
  final int? maxLength;

  /// 输入框的边框样式
  final InputBorder? border;

  const InputDialog({
    super.key,
    required this.title,
    this.hint,
    this.initialValue,
    this.helperText,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.confirmText = '确定',
    this.cancelText = '取消',
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = true,
    this.showCounter = false,
    this.maxLength,
    this.border,
  });

  @override
  State<InputDialog> createState() => _InputDialogState();

  /// 显示输入对话框并返回用户输入的内容
  ///
  /// 返回用户输入的字符串，点击取消或关闭返回 `null`
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [hint] 输入框提示文本
  /// - [initialValue] 输入框初始值
  /// - [helperText] 输入框帮助文本
  /// - [maxLines] 最大行数，默认为1
  /// - [minLines] 最小行数
  /// - [validator] 输入验证函数
  /// - [keyboardType] 键盘类型
  /// - [inputFormatters] 文本输入格式
  /// - [confirmText] 确认按钮文本
  /// - [cancelText] 取消按钮文本
  /// - [prefixIcon] 输入框前缀图标
  /// - [suffixIcon] 输入框后缀图标
  /// - [autofocus] 是否自动聚焦
  /// - [showCounter] 是否显示字数统计
  /// - [maxLength] 最大字符数限制
  /// - [border] 输入框边框样式
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    String? helperText,
    int maxLines = 1,
    int? minLines,
    String? Function(String value)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String confirmText = '确定',
    String cancelText = '取消',
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool autofocus = true,
    bool showCounter = false,
    int? maxLength,
    InputBorder? border,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => InputDialog(
        title: title,
        hint: hint,
        initialValue: initialValue,
        helperText: helperText,
        maxLines: maxLines,
        minLines: minLines,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        confirmText: confirmText,
        cancelText: cancelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        autofocus: autofocus,
        showCounter: showCounter,
        maxLength: maxLength,
        border: border,
      ),
    );
  }
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

    // 执行验证
    if (widget.validator != null) {
      final error = widget.validator!(value);
      if (error != null) {
        setState(() => _errorText = error);
        return;
      }
    }

    Navigator.of(context).pop(value);
  }

  void _handleChanged(String value) {
    // 清除错误提示
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  void _handleSubmitted(String value) {
    // 多行输入时，使用Ctrl+Enter提交
    if (widget.maxLines > 1) {
      // 检测Ctrl+Enter或Cmd+Enter
      final isControlPressed = HardwareKeyboard.instance.logicalKeysPressed.any(
        (key) =>
            key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight ||
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight,
      );

      if (isControlPressed) {
        _handleConfirm();
      }
    } else {
      // 单行输入直接提交
      _handleConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 输入框
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helperText,
              errorText: _errorText,
              border: widget.border ?? const OutlineInputBorder(),
              prefixIcon:
                  widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
              suffixIcon: widget.suffixIcon,
              // 字数统计
              counterText: widget.showCounter
                  ? '${_controller.text.length}${widget.maxLength != null ? ' / ${widget.maxLength}' : ''}'
                  : null,
            ),
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            autofocus: widget.autofocus,
            maxLength: widget.maxLength,
            onChanged: _handleChanged,
            onSubmitted: _handleSubmitted,
          ),
          // 多行输入提示
          if (widget.maxLines > 1) ...[
            const SizedBox(height: 8),
            Text(
              '提示: 使用 Ctrl+Enter 快速提交',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

/// 通用多行输入对话框
///
/// 专门用于多行文本输入的便捷类
///
/// 示例:
/// ```dart
/// final result = await MultilineInputDialog.show(
///   context,
///   title: '输入描述',
///   hint: '请输入详细描述',
///   initialLines: 3,
///   maxLines: 8,
/// );
/// ```
class MultilineInputDialog {
  /// 显示多行输入对话框
  ///
  /// [context] 上下文
  /// [title] 对话框标题
  /// [hint] 输入框提示文本
  /// [initialValue] 输入框初始值
  /// [initialLines] 初始行数，默认为3
  /// [maxLines] 最大行数，默认为8
  /// [minLines] 最小行数，默认为1
  /// [validator] 输入验证函数
  /// [confirmText] 确认按钮文本
  /// [cancelText] 取消按钮文本
  /// [showCounter] 是否显示字数统计
  /// [maxLength] 最大字符数限制
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    int initialLines = 3,
    int maxLines = 8,
    int minLines = 1,
    String? Function(String value)? validator,
    String confirmText = '确定',
    String cancelText = '取消',
    bool showCounter = false,
    int? maxLength,
  }) {
    return InputDialog.show(
      context,
      title: title,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      minLines: minLines,
      validator: validator,
      confirmText: confirmText,
      cancelText: cancelText,
      showCounter: showCounter,
      maxLength: maxLength,
    );
  }
}

/// 通用数字输入对话框
///
/// 专门用于数字输入的便捷类
///
/// 示例:
/// ```dart
/// final result = await NumberInputDialog.show(
///   context,
///   title: '输入数量',
///   hint: '请输入数量',
///   initialValue: '1',
///   validator: (value) {
///     final num = int.tryParse(value);
///     if (num == null || num < 1) return '请输入有效的数字';
///     if (num > 100) return '数量不能超过100';
///     return null;
///   },
/// );
/// ```
class NumberInputDialog {
  /// 显示数字输入对话框
  ///
  /// [context] 上下文
  /// [title] 对话框标题
  /// [hint] 输入框提示文本
  /// [initialValue] 输入框初始值
  /// [isDecimal] 是否允许小数
  /// [minValue] 最小值（可选）
  /// [maxValue] 最大值（可选）
  /// [validator] 自定义验证函数
  /// [confirmText] 确认按钮文本
  /// [cancelText] 取消按钮文本
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    bool isDecimal = false,
    num? minValue,
    num? maxValue,
    String? Function(String value)? validator,
    String confirmText = '确定',
    String cancelText = '取消',
  }) {
    return InputDialog.show(
      context,
      title: title,
      hint: hint,
      initialValue: initialValue,
      keyboardType:
          isDecimal ? TextInputType.number : TextInputType.numberWithOptions(),
      validator: (value) {
        // 先执行自定义验证
        if (validator != null) {
          final error = validator(value);
          if (error != null) return error;
        }

        // 执行数字范围验证
        if (value.isEmpty) return null;
        final number = isDecimal ? double.tryParse(value) : int.tryParse(value);
        if (number == null) return '请输入有效的数字';

        if (minValue != null && number < minValue) {
          return '数值不能小于 $minValue';
        }
        if (maxValue != null && number > maxValue) {
          return '数值不能大于 $maxValue';
        }

        return null;
      },
      confirmText: confirmText,
      cancelText: cancelText,
      prefixIcon: Icons.numbers,
    );
  }
}
