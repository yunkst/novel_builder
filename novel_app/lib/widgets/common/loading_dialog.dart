import 'package:flutter/material.dart';
import 'base_dialog.dart';

/// 通用加载对话框
///
/// 提供标准的加载状态指示对话框，支持自定义加载信息和样式。
///
/// 功能特性：
/// - 统一的Material Design 3风格
/// - 支持自定义加载信息
/// - 支持自定义进度指示器样式
/// - 禁止返回键关闭（可通过配置修改）
/// - 继承BaseDialog，保持UI一致性
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
///
/// 带异步操作示例:
/// ```dart
/// final result = await LoadingDialog.withFuture(
///   context,
///   future: () async {
///     await Future.delayed(Duration(seconds: 2));
///     return '操作完成';
///   },
///   message: '加载数据中...',
/// );
/// ```
///
/// 自定义样式示例:
/// ```dart
/// LoadingDialog.show(
///   context,
///   message: '下载中...',
///   indicatorType: LoadingIndicatorType.circular,
///   backgroundColor: Colors.black87,
///   messageColor: Colors.white,
/// );
/// ```
class LoadingDialog extends BaseDialog {
  /// 加载提示信息
  final String message;

  /// 进度指示器类型
  final LoadingIndicatorType indicatorType;

  /// 消息文本颜色
  final Color? messageColor;

  /// 是否显示消息
  final bool showMessage;

  /// 是否允许返回键关闭
  final bool allowDismiss;

  const LoadingDialog({
    super.key,
    this.message = '处理中...',
    this.indicatorType = LoadingIndicatorType.circular,
    this.messageColor,
    this.showMessage = true,
    this.allowDismiss = false,
    super.backgroundColor,
    super.elevation,
    super.borderRadius,
  });

  /// 显示加载对话框
  ///
  /// [context] 上下文
  /// [message] 加载提示信息，默认为"处理中..."
  /// [indicatorType] 进度指示器类型
  /// [messageColor] 消息文本颜色
  /// [showMessage] 是否显示消息
  /// [allowDismiss] 是否允许返回键关闭
  /// [backgroundColor] 背景颜色
  /// [barrierDismissible] 是否允许点击外部关闭
  static void show(
    BuildContext context, {
    String message = '处理中...',
    LoadingIndicatorType indicatorType = LoadingIndicatorType.circular,
    Color? messageColor,
    bool showMessage = true,
    bool allowDismiss = false,
    Color? backgroundColor,
    bool barrierDismissible = false,
  }) {
    // 避免重复显示
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => PopScope(
        canPop: allowDismiss,
        child: LoadingDialog(
          message: message,
          indicatorType: indicatorType,
          messageColor: messageColor,
          showMessage: showMessage,
          allowDismiss: allowDismiss,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }

  /// 隐藏加载对话框
  ///
  /// [context] 上下文
  static void hide(BuildContext context) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 执行异步操作并自动管理加载对话框
  ///
  /// [context] 上下文
  /// [future] 要执行的异步操作函数
  /// [message] 加载提示信息
  /// [indicatorType] 进度指示器类型
  /// [onError] 错误处理回调，返回true表示错误已处理，不再抛出
  /// [showErrorDialog] 是否在出错时显示错误对话框
  /// [errorMessage] 自定义错误消息前缀
  static Future<T?> withFuture<T>({
    required BuildContext context,
    required Future<T> Function() future,
    String message = '处理中...',
    LoadingIndicatorType indicatorType = LoadingIndicatorType.circular,
    bool Function(dynamic error)? onError,
    bool showErrorDialog = true,
    String errorMessage = '操作失败',
  }) async {
    LoadingDialog.show(
      context,
      message: message,
      indicatorType: indicatorType,
    );

    try {
      final result = await future();
      if (!context.mounted) return result;
      LoadingDialog.hide(context);
      return result;
    } catch (e) {
      if (!context.mounted) rethrow;
      LoadingDialog.hide(context);

      // 执行错误处理回调
      if (onError?.call(e) == true) {
        return null;
      }

      // 显示错误对话框
      if (showErrorDialog) {
        _showErrorDialog(
          context,
          message: errorMessage,
          error: e.toString(),
        );
      }

      rethrow;
    }
  }

  /// 显示错误对话框
  static void _showErrorDialog(
    BuildContext context, {
    required String message,
    required String error,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.error,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Text('错误'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 构建进度指示器
    Widget indicator;
    switch (indicatorType) {
      case LoadingIndicatorType.circular:
        indicator = SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              messageColor ?? colorScheme.primary,
            ),
          ),
        );
        break;
      case LoadingIndicatorType.circularSmall:
        indicator = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              messageColor ?? colorScheme.primary,
            ),
          ),
        );
        break;
      case LoadingIndicatorType.linear:
        indicator = SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            minHeight: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              messageColor ?? colorScheme.primary,
            ),
          ),
        );
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        if (showMessage) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: messageColor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => null;
}

/// 加载指示器类型枚举
enum LoadingIndicatorType {
  /// 圆形进度指示器（标准）
  circular,

  /// 圆形进度指示器（小）
  circularSmall,

  /// 线性进度指示器
  linear,
}

/// 进度更新回调函数类型
typedef ProgressCallback = void Function(double progress);

/// 带进度的任务类型
typedef ProgressTask = Future<void> Function(ProgressCallback progress);

/// 带进度的加载对话框
///
/// 用于显示具体进度的加载对话框（0-100%）
///
/// 示例:
/// ```dart
/// await ProgressLoadingDialog.withProgress(
///   context,
///   task: (progress) async {
///     for (int i = 0; i <= 100; i++) {
///       progress(i / 100);
///       await Future.delayed(Duration(milliseconds: 50));
///     }
///   },
///   message: '下载中...',
/// );
/// ```
class ProgressLoadingDialog {
  /// 私有构造函数，防止实例化
  ProgressLoadingDialog._();

  /// 执行带进度的任务并自动显示加载对话框
  ///
  /// [context] 上下文
  /// [task] 带进度更新的异步任务
  /// [message] 加载提示信息
  /// [onComplete] 完成回调
  /// [onError] 错误回调
  static Future<void> withProgress(
    BuildContext context, {
    required ProgressTask task,
    String message = '处理中...',
    VoidCallback? onComplete,
    void Function(dynamic error)? onError,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProgressLoadingDialogWidget(
        message: message,
        task: task,
        onComplete: onComplete,
        onError: onError,
      ),
    );
  }
}

class _ProgressLoadingDialogWidget extends StatefulWidget {
  final String message;
  final ProgressTask task;
  final VoidCallback? onComplete;
  final void Function(dynamic error)? onError;

  const _ProgressLoadingDialogWidget({
    required this.message,
    required this.task,
    this.onComplete,
    this.onError,
  });

  @override
  State<_ProgressLoadingDialogWidget> createState() =>
      _ProgressLoadingDialogWidgetState();
}

class _ProgressLoadingDialogWidgetState
    extends State<_ProgressLoadingDialogWidget> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _runTask();
  }

  Future<void> _runTask() async {
    try {
      await widget.task((progress) {
        if (mounted) {
          setState(() {
            _progress = progress.clamp(0.0, 1.0);
          });
        }
      });

      if (mounted) {
        widget.onComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        widget.onError?.call(e);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 250,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _progress,
                    minHeight: 4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
