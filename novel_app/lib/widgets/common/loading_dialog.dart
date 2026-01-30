import 'package:flutter/material.dart';

/// 加载对话框工具类
///
/// 提供显示和隐藏加载对话框的静态方法。
///
/// 示例:
/// ```dart
/// // 显示加载对话框
/// LoadingDialog.show(context, message: '处理中...');
///
/// // 执行异步操作
/// await someAsyncOperation();
///
/// // 隐藏加载对话框
/// LoadingDialog.hide(context);
/// ```
class LoadingDialog {
  LoadingDialog._(); // 私有构造函数，防止实例化

  /// 显示加载对话框
  ///
  /// [message] 加载提示信息，默认为"处理中..."
  static void show(
    BuildContext context, {
    String message = '处理中...',
  }) {
    // 避免重复显示
    if (Navigator.of(context).canPop()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LoadingDialogContent(message: message),
    );
  }

  /// 隐藏加载对话框
  static void hide(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

/// 加载对话框内容组件
class _LoadingDialogContent extends StatelessWidget {
  final String message;

  const _LoadingDialogContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 禁止返回键关闭
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 带异步操作的加载对话框工具类
///
/// 自动管理加载对话框的显示和隐藏。
///
/// 示例:
/// ```dart
/// final result = await LoadingDialog.withFuture(
///   context,
///   future: _loadData(),
///   message: '加载数据中...',
/// );
/// ```
class LoadingDialogFuture {
  LoadingDialogFuture._(); // 私有构造函数

  /// 执行异步操作并自动管理加载对话框
  ///
  /// [future] 要执行的异步操作
  /// [message] 加载提示信息
  /// [onError] 错误处理回调，返回true表示错误已处理，不再抛出
  static Future<T?> withFuture<T>({
    required BuildContext context,
    required Future<T> Function() future,
    String message = '处理中...',
    bool Function(dynamic error)? onError,
  }) async {
    LoadingDialog.show(context, message: message);

    try {
      final result = await future();
      if (!context.mounted) return result;
      LoadingDialog.hide(context);
      return result;
    } catch (e) {
      if (!context.mounted) rethrow;
      LoadingDialog.hide(context);

      if (onError?.call(e) == true) {
        return null;
      }
      rethrow;
    }
  }
}
