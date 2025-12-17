import 'package:flutter/material.dart';

/// 弹窗辅助工具类 - 统一管理弹窗行为，确保所有弹窗禁用空白区域点击关闭
class DialogHelper {

  /// 显示确认对话框
  ///
  /// [context] BuildContext上下文
  /// [title] 对话框标题
  /// [content] 对话框内容
  /// [confirmText] 确认按钮文本，默认为'确定'
  /// [cancelText] 取消按钮文本，默认为'取消'
  /// [isDanger] 是否为危险操作，确认按钮将显示为红色
  ///
  /// 返回用户是否点击了确认按钮
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDanger = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
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
            style: isDanger
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示输入对话框
  ///
  /// [context] BuildContext上下文
  /// [title] 对话框标题
  /// [hintText] 输入框提示文本
  /// [initialValue] 输入框初始值
  /// [confirmText] 确认按钮文本
  /// [cancelText] 取消按钮文本
  /// [validator] 输入验证函数
  ///
  /// 返回用户输入的文本，点击取消返回null
  static Future<String?> showInputDialog(
    BuildContext context, {
    required String title,
    String? hintText,
    String? initialValue,
    String confirmText = '确定',
    String cancelText = '取消',
    String? Function(String?)? validator,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
            validator: validator,
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

  /// 显示选择对话框
  ///
  /// [context] BuildContext上下文
  /// [title] 对话框标题
  /// [items] 可选择的选项列表
  /// [itemBuilder] 选项构建器函数
  /// [selectedItem] 当前选中的选项
  /// [confirmText] 确认按钮文本
  /// [cancelText] 取消按钮文本
  ///
  /// 返回用户选择的选项
  static Future<T?> showSelectionDialog<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required Widget Function(T item) itemBuilder,
    T? selectedItem,
    String confirmText = '确定',
    String cancelText = '取消',
  }) async {
    T? selected = selectedItem;

    return await showDialog<T>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
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
                  title: itemBuilder(item),
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: Theme.of(context).primaryColor,
                  ),
                  onTap: () {
                    setState(() {
                      selected = item;
                    });
                  },
                  tileColor: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
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

  /// 显示信息对话框
  ///
  /// [context] BuildContext上下文
  /// [title] 对话框标题
  /// [content] 对话框内容
  /// [confirmText] 确认按钮文本，默认为'确定'
  ///
  /// 显示纯信息内容，用户点击确认后关闭
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示自定义内容对话框
  ///
  /// [context] BuildContext上下文
  /// [title] 对话框标题
  /// [content] 自定义内容Widget
  /// [actions] 操作按钮列表
  /// [scrollable] 内容是否可滚动
  ///
  /// 提供最大的自定义能力，同时确保标准的关闭行为
  static Future<T?> showCustomDialog<T>(
    BuildContext context, {
    Widget? title,
    required Widget content,
    required List<Widget> actions,
    bool scrollable = false,
  }) async {
    return await showDialog<T>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: title,
        content: scrollable
            ? SingleChildScrollView(child: content)
            : content,
        actions: actions,
      ),
    );
  }

  /// 显示全屏自定义对话框
  ///
  /// [context] BuildContext上下文
  /// [builder] 对话框内容构建器
  ///
  /// 适用于需要全屏显示的复杂弹窗内容
  static Future<T?> showFullScreenDialog<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
  }) async {
    return await showDialog<T>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => Dialog.fullscreen(
        child: builder(context),
      ),
    );
  }
}