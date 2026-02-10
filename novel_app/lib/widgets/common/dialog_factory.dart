import 'package:flutter/material.dart';
import 'confirm_dialog.dart';
import 'input_dialog.dart';
import 'loading_dialog.dart';

/// 对话框工厂类
///
/// 提供统一的对话框创建和显示接口，简化对话框的使用。
/// 所有对话框都遵循统一的Material Design 3风格。
///
/// 功能特性：
/// - 统一的API接口
/// - 简洁的调用方式
/// - 自动处理动画和样式
/// - 支持链式调用
///
/// 示例:
/// ```dart
/// // 显示确认对话框
/// final confirmed = await DialogFactory.confirm(
///   context,
///   title: '确认删除',
///   message: '删除后无法恢复',
/// );
///
/// // 显示输入对话框
/// final input = await DialogFactory.input(
///   context,
///   title: '请输入标题',
/// );
///
/// // 显示加载对话框
/// DialogFactory.loading(context, message: '处理中...');
/// await doSomething();
/// DialogFactory.dismiss(context);
///
/// // 带异步操作的加载对话框
/// final result = await DialogFactory.loadingWithFuture(
///   context,
///   future: () => fetchData(),
///   message: '加载数据中...',
/// );
/// ```
///
/// 危险操作确认:
/// ```dart
/// final confirmed = await DialogFactory.confirmDangerous(
///   context,
///   title: '确认删除',
///   message: '此操作不可撤销',
/// );
/// ```
///
/// 多行输入:
/// ```dart
/// final input = await DialogFactory.multilineInput(
///   context,
///   title: '输入描述',
///   hint: '请输入详细描述',
///   maxLines: 5,
/// );
/// ```
class DialogFactory {
  // 私有构造函数，防止实例化
  DialogFactory._();

  /// 显示确认对话框
  ///
  /// 返回 `true` 表示确认，`false` 表示取消，`null` 表示关闭
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [message] 对话框内容
  /// - [confirmText] 确认按钮文本，默认"确认"
  /// - [cancelText] 取消按钮文本，默认"取消"
  /// - [icon] 对话框图标
  /// - [confirmColor] 确认按钮颜色
  /// - [isDangerous] 是否为危险操作
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    IconData? icon,
    Color? confirmColor,
    bool isDangerous = false,
  }) {
    return ConfirmDialog.show(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      confirmColor: confirmColor,
      isDangerous: isDangerous,
    );
  }

  /// 显示危险操作确认对话框
  ///
  /// 用于删除、清空等危险操作的确认
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [message] 对话框内容
  /// - [confirmText] 确认按钮文本，默认"删除"
  /// - [cancelText] 取消按钮文本，默认"取消"
  /// - [icon] 对话框图标，默认Icons.warning
  static Future<bool?> confirmDangerous(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '删除',
    String cancelText = '取消',
    IconData icon = Icons.warning,
  }) {
    return ConfirmDialogDangerous.show(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
    );
  }

  /// 显示信息确认对话框
  ///
  /// 用于一般信息确认操作
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [message] 对话框内容
  /// - [confirmText] 确认按钮文本，默认"确定"
  /// - [cancelText] 取消按钮文本，默认"取消"
  /// - [icon] 对话框图标，默认Icons.info_outline
  static Future<bool?> confirmInfo(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '确定',
    String cancelText = '取消',
    IconData icon = Icons.info_outline,
  }) {
    return ConfirmDialogInfo.show(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
    );
  }

  /// 显示输入对话框
  ///
  /// 返回用户输入的内容，取消或关闭返回 `null`
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [hint] 输入框提示文本
  /// - [initialValue] 输入框初始值
  /// - [maxLines] 最大行数，默认1
  /// - [validator] 输入验证函数
  /// - [keyboardType] 键盘类型
  /// - [confirmText] 确认按钮文本，默认"确定"
  /// - [cancelText] 取消按钮文本，默认"取消"
  static Future<String?> input(
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
    return InputDialog.show(
      context,
      title: title,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  /// 显示多行输入对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [hint] 输入框提示文本
  /// - [initialValue] 输入框初始值
  /// - [initialLines] 初始行数，默认3
  /// - [maxLines] 最大行数，默认8
  /// - [validator] 输入验证函数
  /// - [confirmText] 确认按钮文本，默认"确定"
  /// - [cancelText] 取消按钮文本，默认"取消"
  static Future<String?> multilineInput(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    int initialLines = 3,
    int maxLines = 8,
    String? Function(String value)? validator,
    String confirmText = '确定',
    String cancelText = '取消',
  }) {
    return MultilineInputDialog.show(
      context,
      title: title,
      hint: hint,
      initialValue: initialValue,
      initialLines: initialLines,
      maxLines: maxLines,
      validator: validator,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  /// 显示数字输入对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [hint] 输入框提示文本
  /// - [initialValue] 输入框初始值
  /// - [isDecimal] 是否允许小数
  /// - [minValue] 最小值
  /// - [maxValue] 最大值
  /// - [validator] 自定义验证函数
  /// - [confirmText] 确认按钮文本，默认"确定"
  /// - [cancelText] 取消按钮文本，默认"取消"
  static Future<String?> numberInput(
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
    return NumberInputDialog.show(
      context,
      title: title,
      hint: hint,
      initialValue: initialValue,
      isDecimal: isDecimal,
      minValue: minValue,
      maxValue: maxValue,
      validator: validator,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  /// 显示加载对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [message] 加载提示信息，默认"处理中..."
  /// - [indicatorType] 进度指示器类型
  /// - [allowDismiss] 是否允许返回键关闭
  static void loading(
    BuildContext context, {
    String message = '处理中...',
    LoadingIndicatorType indicatorType = LoadingIndicatorType.circular,
    bool allowDismiss = false,
  }) {
    LoadingDialog.show(
      context,
      message: message,
      indicatorType: indicatorType,
      allowDismiss: allowDismiss,
    );
  }

  /// 隐藏加载对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  static void dismiss(BuildContext context) {
    LoadingDialog.hide(context);
  }

  /// 显示加载对话框并执行异步操作
  ///
  /// 自动管理加载对话框的显示和隐藏
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [future] 要执行的异步操作
  /// - [message] 加载提示信息
  /// - [onError] 错误处理回调
  static Future<T?> loadingWithFuture<T>({
    required BuildContext context,
    required Future<T> Function() future,
    String message = '处理中...',
    bool Function(dynamic error)? onError,
  }) {
    return LoadingDialog.withFuture(
      context: context,
      future: future,
      message: message,
      onError: onError,
    );
  }

  /// 显示带进度的加载对话框
  ///
  /// 用于显示具体进度的加载任务
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [task] 带进度更新的异步任务
  /// - [message] 加载提示信息
  /// - [onComplete] 完成回调
  /// - [onError] 错误回调
  static Future<void> loadingWithProgress({
    required BuildContext context,
    required ProgressTask task,
    String message = '处理中...',
    VoidCallback? onComplete,
    void Function(dynamic error)? onError,
  }) {
    return ProgressLoadingDialog.withProgress(
      context,
      task: task,
      message: message,
      onComplete: onComplete,
      onError: onError,
    );
  }

  /// 显示成功提示对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题，默认"成功"
  /// - [message] 提示信息
  /// - [confirmText] 确认按钮文本，默认"确定"
  static Future<void> success(
    BuildContext context, {
    String title = '成功',
    required String message,
    String confirmText = '确定',
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示错误提示对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题，默认"错误"
  /// - [message] 错误信息
  /// - [confirmText] 确认按钮文本，默认"确定"
  static Future<void> error(
    BuildContext context, {
    String title = '错误',
    required String message,
    String confirmText = '确定',
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示警告提示对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题，默认"警告"
  /// - [message] 警告信息
  /// - [confirmText] 确认按钮文本，默认"我知道了"
  static Future<void> warning(
    BuildContext context, {
    String title = '警告',
    required String message,
    String confirmText = '我知道了',
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示信息提示对话框
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [title] 对话框标题
  /// - [message] 提示信息
  /// - [confirmText] 确认按钮文本，默认"确定"
  /// - [icon] 对话框图标
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '确定',
    IconData? icon,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: icon != null
            ? Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              )
            : null,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示底部动作面板
  ///
  /// 类似iOS的ActionSheet
  ///
  /// 参数说明：
  /// - [context] 上下文
  /// - [items] 动作项列表
  /// - [cancelText] 取消按钮文本，默认"取消"
  /// - [title] 面板标题（可选）
  static Future<T?> showActionSheet<T>({
    required BuildContext context,
    required List<ActionSheetItem<T>> items,
    String cancelText = '取消',
    String? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant,
                  ),
                ],
                // 动作项
                ...items.map((item) {
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop(item.value);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          if (item.icon != null) ...[
                            Icon(
                              item.icon,
                              color: item.iconColor ?? colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              item.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: item.isDangerous
                                    ? colorScheme.error
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // 取消按钮
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant,
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    child: Text(
                      cancelText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 动作面板项
///
/// 用于底部动作面板的动作项定义
class ActionSheetItem<T> {
  /// 显示文本
  final String label;

  /// 图标
  final IconData? icon;

  /// 图标颜色
  final Color? iconColor;

  /// 是否为危险操作
  final bool isDangerous;

  /// 返回值
  final T value;

  const ActionSheetItem({
    required this.label,
    this.icon,
    this.iconColor,
    this.isDangerous = false,
    required this.value,
  });
}
