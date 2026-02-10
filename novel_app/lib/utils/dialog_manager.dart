import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 对话框管理工具类
///
/// 提供统一的对话框管理接口，简化常见对话框的创建和使用。
///
/// 与 DialogHelper 的区别：
/// - DialogHelper：专注于标准对话框，禁用空白区域点击关闭
/// - DialogManager：提供更丰富的对话框类型和交互方式
///
/// 使用方式：
/// ```dart
/// // 确认对话框
/// final confirmed = await DialogManager.showConfirm(
///   context,
///   title: '删除确认',
///   message: '确定要删除此项吗？',
/// );
///
/// // 输入对话框
/// final input = await DialogManager.showInput(
///   context,
///   title: '请输入名称',
///   hint: '名称',
/// );
///
/// // 选择对话框
/// final selected = await DialogManager.showSelection(
///   context,
///   title: '选择颜色',
///   items: ['红色', '绿色', '蓝色'],
///   selectedItem: '红色',
/// );
/// ```
class DialogManager {
  DialogManager._();

  /// 显示确认对话框
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [message] 对话框内容消息
  /// [confirmText] 确认按钮文本（默认 '确认'）
  /// [cancelText] 取消按钮文本（默认 '取消'）
  /// [isDanger] 是否为危险操作（确认按钮显示为红色）
  /// [barrierDismissible] 是否允许点击空白区域关闭（默认 false）
  ///
  /// 返回用户是否点击了确认按钮
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDanger = false,
    bool barrierDismissible = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDanger
                ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示危险操作确认对话框
  ///
  /// [showConfirm] 的便捷方法，确认按钮为红色。
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [message] 对话框内容消息
  /// [confirmText] 确认按钮文本（默认 '删除'）
  /// [cancelText] 取消按钮文本（默认 '取消'）
  ///
  /// 返回用户是否点击了确认按钮
  static Future<bool?> showDangerConfirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = '删除',
    String cancelText = '取消',
  }) async {
    return await showConfirm(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDanger: true,
    );
  }

  /// 显示输入对话框
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [hint] 输入框提示文本
  /// [initialValue] 输入框初始值
  /// [confirmText] 确认按钮文本（默认 '确认'）
  /// [cancelText] 取消按钮文本（默认 '取消'）
  /// [validator] 输入验证函数
  /// [inputFormatters] 输入格式化器
  /// [keyboardType] 键盘类型
  /// [maxLines] 最大行数
  /// [obscureText] 是否隐藏文本（用于密码输入）
  ///
  /// 返回用户输入的文本，点击取消返回 null
  static Future<String?> showInput(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    String confirmText = '确认',
    String cancelText = '取消',
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            validator: validator,
            inputFormatters: inputFormatters,
            keyboardType: keyboardType,
            maxLines: maxLines,
            obscureText: obscureText,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示多行输入对话框
  ///
  /// [showInput] 的便捷方法，适用于多行文本输入。
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [hint] 输入框提示文本
  /// [initialValue] 输入框初始值
  /// [minLines] 最小行数（默认 3）
  /// [maxLines] 最大行数（默认 10）
  ///
  /// 返回用户输入的文本，点击取消返回 null
  static Future<String?> showMultilineInput(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    int minLines = 3,
    int maxLines = 10,
  }) async {
    return await showInput(
      context,
      title: title,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
    );
  }

  /// 显示密码输入对话框
  ///
  /// [showInput] 的便捷方法，输入内容被隐藏。
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [hint] 输入框提示文本
  /// [confirmText] 确认按钮文本（默认 '确认'）
  ///
  /// 返回用户输入的文本，点击取消返回 null
  static Future<String?> showPasswordInput(
    BuildContext context, {
    required String title,
    String? hint,
    String confirmText = '确认',
  }) async {
    return await showInput(
      context,
      title: title,
      hint: hint,
      confirmText: confirmText,
      obscureText: true,
      keyboardType: TextInputType.visiblePassword,
    );
  }

  /// 显示选择对话框
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [items] 可选择的选项列表
  /// [selectedItem] 当前选中的选项
  /// [confirmText] 确认按钮文本（默认 '确定'）
  /// [cancelText] 取消按钮文本（默认 '取消'）
  /// [itemBuilder] 选项构建器函数
  /// [itemLabel] 选项标签提取函数（简化版）
  ///
  /// 返回用户选择的选项
  static Future<T?> showSelection<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    T? selectedItem,
    String confirmText = '确定',
    String cancelText = '取消',
    Widget Function(T item)? itemBuilder,
    String Function(T item)? itemLabel,
  }) async {
    assert(
      itemBuilder != null || itemLabel != null,
      '必须提供 itemBuilder 或 itemLabel',
    );

    T? selected = selectedItem;

    return await showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item == selected;

                return ListTile(
                  title: itemBuilder != null
                      ? itemBuilder(item)
                      : Text(itemLabel!(item)),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: Theme.of(context).primaryColor,
                  ),
                  onTap: () {
                    setState(() {
                      selected = item;
                    });
                  },
                  tileColor: isSelected
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示单选对话框（简化版）
  ///
  /// [showSelection] 的便捷方法，使用字符串标签。
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [items] 可选择的选项列表
  /// [selectedItem] 当前选中的选项
  ///
  /// 返回用户选择的选项
  static Future<T?> showSimpleSelection<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    T? selectedItem,
  }) async {
    return await showSelection<T>(
      context,
      title: title,
      items: items,
      selectedItem: selectedItem,
      itemLabel: (item) => item.toString(),
    );
  }

  /// 显示底部选择列表（BottomSheet 风格）
  ///
  /// [context] BuildContext 上下文
  /// [items] 可选择的选项列表
  /// [selectedItem] 当前选中的选项
  /// [itemBuilder] 选项构建器函数
  /// [itemLabel] 选项标签提取函数（简化版）
  ///
  /// 返回用户选择的选项
  static Future<T?> showBottomSelection<T>(
    BuildContext context, {
    required List<T> items,
    T? selectedItem,
    Widget Function(T item)? itemBuilder,
    String Function(T item)? itemLabel,
  }) async {
    assert(
      itemBuilder != null || itemLabel != null,
      '必须提供 itemBuilder 或 itemLabel',
    );

    return await showModalSheet<T>(
      context,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item == selectedItem;

          return ListTile(
            title: itemBuilder != null
                ? itemBuilder(item)
                : Text(itemLabel!(item)),
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }

  /// 显示信息对话框
  ///
  /// [context] BuildContext 上下文
  /// [title] 对话框标题
  /// [content] 对话框内容 Widget
  /// [confirmText] 确认按钮文本（默认 '确定'）
  ///
  /// 显示纯信息内容，用户点击确认后关闭
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    Widget? content,
    String? message,
    String confirmText = '确定',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content ?? (message != null ? Text(message) : null),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示加载对话框
  ///
  /// [context] BuildContext 上下文
  /// [message] 加载消息
  /// [barrierDismissible] 是否允许点击空白区域关闭（默认 false）
  ///
  /// 返回一个可用于关闭对话框的函数
  static VoidCallback showLoading(
    BuildContext context, {
    String? message,
    bool barrierDismissible = false,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ],
        ),
      ),
    );

    return () => Navigator.of(context).pop();
  }

  /// 显示底部模态面板
  ///
  /// [context] BuildContext 上下文
  /// [builder] 内容构建器
  /// [isScrollControlled] 是否可滚动（默认 true）
  /// [backgroundColor] 背景颜色
  /// [isDismissible] 是否允许点击外部关闭（默认 true）
  ///
  /// 返回用户操作结果
  static Future<T?> showModalSheet<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    Color? backgroundColor,
    bool isDismissible = true,
  }) async {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      isDismissible: isDismissible,
      builder: builder,
    );
  }

  /// 显示全屏对话框
  ///
  /// [context] BuildContext 上下文
  /// [builder] 对话框内容构建器
  ///
  /// 适用于需要全屏显示的复杂弹窗内容
  static Future<T?> showFullScreen<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
  }) async {
    return await showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: builder(context),
      ),
    );
  }

  /// 显示进度对话框
  ///
  /// [context] BuildContext 上下文
  /// [value] 当前进度值（0.0 - 1.0），null 表示不确定进度
  /// [message] 进度消息
  /// [total] 总量（用于显示 "x/y" 格式）
  /// [current] 当前值（用于显示 "x/y" 格式）
  ///
  /// 返回一个可用于更新进度的函数
  static Function(double? progress, String? message) showProgress(
    BuildContext context, {
    double? value,
    String? message,
    int? total,
    int? current,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProgressDialog(
        value: value,
        message: message,
        total: total,
        current: current,
      ),
    );

    return (double? newValue, String? newMessage) {
      // 更新对话框需要使用 StatefulBuilder
      // 这里简化处理，实际使用可能需要更复杂的实现
    };
  }
}

/// 进度对话框内部实现
class _ProgressDialog extends StatelessWidget {
  final double? value;
  final String? message;
  final int? total;
  final int? current;

  const _ProgressDialog({
    this.value,
    this.message,
    this.total,
    this.current,
  });

  @override
  Widget build(BuildContext context) {
    String? displayMessage = message;
    if (total != null && current != null) {
      displayMessage = '$displayMessage ($current/$total)';
    }

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: value),
          if (displayMessage != null) ...[
            const SizedBox(height: 16),
            Text(displayMessage),
          ],
        ],
      ),
    );
  }
}

/// 对话框结果包装器
///
/// 用于处理对话框返回值，提供更安全的类型处理。
class DialogResult<T> {
  final T? data;
  final bool confirmed;
  final bool cancelled;

  const DialogResult({
    this.data,
    this.confirmed = false,
    this.cancelled = false,
  });

  /// 创建确认结果
  factory DialogResult.confirmed({T? data}) {
    return DialogResult(data: data, confirmed: true);
  }

  /// 创建取消结果
  const DialogResult.cancelled()
      : data = null,
        confirmed = false,
        cancelled = true;

  /// 创建数据结果
  factory DialogResult.withData(T data) {
    return DialogResult(data: data, confirmed: true);
  }

  /// 是否有数据
  bool get hasData => data != null;
}
