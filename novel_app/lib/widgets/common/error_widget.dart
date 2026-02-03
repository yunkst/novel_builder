import 'package:flutter/material.dart';

/// 统一的错误显示组件
///
/// 提供多种错误状态的显示样式和交互选项。
///
/// 示例:
/// ```dart
/// ErrorDisplayWidget(
///   message: '加载失败',
///   onRetry: () => retry(),
/// )
///
/// ErrorDisplayWidget.card(
///   error: error,
///   onRetry: () => retry(),
/// )
/// ```
class ErrorDisplayWidget extends StatelessWidget {
  /// 错误对象或消息
  final Object? error;

  /// 错误提示信息（如果不提供，则使用 error.toString()）
  final String? message;

  /// 重试回调函数
  final VoidCallback? onRetry;

  /// 错误图标
  final IconData? icon;

  /// 重试按钮文本
  final String retryText;

  /// 是否显示为居中布局（默认为 true）
  final bool centered;

  /// 显示模式
  final ErrorDisplayMode mode;

  const ErrorDisplayWidget({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.icon,
    this.retryText = '重试',
    this.centered = true,
    this.mode = ErrorDisplayMode.standalone,
  });

  /// 创建卡片样式的错误显示
  const ErrorDisplayWidget.card({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.icon,
    this.retryText = '重试',
  }) : centered = false,
       mode = ErrorDisplayMode.card;

  /// 创建内联样式的错误显示（用于列表项等小空间）
  const ErrorDisplayWidget.inline({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.icon,
    this.retryText = '重试',
  }) : centered = false,
       mode = ErrorDisplayMode.inline;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    switch (mode) {
      case ErrorDisplayMode.standalone:
        return centered ? Center(child: content) : content;

      case ErrorDisplayMode.card:
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        );

      case ErrorDisplayMode.inline:
        return content;
    }
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayMessage = message ?? error?.toString() ?? '发生未知错误';

    // 内联模式：简化显示
    if (mode == ErrorDisplayMode.inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.error_outline,
            size: 16,
            color: colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(retryText),
            ),
          ],
        ],
      );
    }

    // 标准模式：完整显示
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon ?? Icons.error_outline,
          size: 48,
          color: colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          mode == ErrorDisplayMode.card ? '出错了' : '加载失败',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.error.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryText),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
          ),
        ],
      ],
    );
  }
}

/// 错误显示模式
enum ErrorDisplayMode {
  /// 独立显示（默认）
  standalone,

  /// 卡片样式
  card,

  /// 内联样式
  inline,
}

/// 网络错误专用组件
///
/// 针对网络相关的错误提供专门的图标和提示。
class NetworkErrorWidget extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;

  const NetworkErrorWidget({
    super.key,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplayWidget(
      error: error,
      message: '网络连接失败，请检查网络设置',
      icon: Icons.wifi_off,
      onRetry: onRetry,
      retryText: '重新连接',
    );
  }
}

/// 超时错误专用组件
class TimeoutErrorWidget extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;

  const TimeoutErrorWidget({
    super.key,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplayWidget(
      error: error,
      message: '请求超时，请稍后重试',
      icon: Icons.access_time,
      onRetry: onRetry,
      retryText: '重试',
    );
  }
}

/// 数据解析错误专用组件
class DataParseErrorWidget extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;

  const DataParseErrorWidget({
    super.key,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplayWidget(
      error: error,
      message: '数据解析失败',
      icon: Icons.broken_image,
      onRetry: onRetry,
      retryText: '重新加载',
    );
  }
}

/// 错误详情对话框
///
/// 显示完整的错误信息和堆栈跟踪（用于调试）。
class ErrorDetailDialog extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const ErrorDetailDialog({
    super.key,
    required this.error,
    this.stackTrace,
  });

  /// 显示错误详情对话框
  static Future<void> show({
    required BuildContext context,
    required Object error,
    StackTrace? stackTrace,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDetailDialog(
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.error, color: Colors.red),
          SizedBox(width: 8),
          Text('错误详情'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '错误类型: ${error.runtimeType}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (stackTrace != null) ...[
              const SizedBox(height: 16),
              Text(
                '堆栈跟踪:',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                stackTrace.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 错误处理扩展方法
///
/// 提供便捷的错误分类和处理方法。
extension ErrorHandling on Object {
  /// 判断是否为网络错误
  bool get isNetworkError {
    return toString().contains('SocketException') ||
           toString().contains('HttpException') ||
           toString().contains('NetworkException');
  }

  /// 判断是否为超时错误
  bool get isTimeoutError {
    return toString().contains('TimeoutException');
  }

  /// 判断是否为解析错误
  bool get isParseError {
    return toString().contains('FormatException') ||
           toString().contains('ParseException');
  }

  /// 根据错误类型获取对应的错误组件
  Widget toErrorWidget({
    VoidCallback? onRetry,
    Key? key,
  }) {
    if (isNetworkError) {
      return NetworkErrorWidget(
        key: key,
        error: this,
        onRetry: onRetry,
      );
    }

    if (isTimeoutError) {
      return TimeoutErrorWidget(
        key: key,
        error: this,
        onRetry: onRetry,
      );
    }

    if (isParseError) {
      return DataParseErrorWidget(
        key: key,
        error: this,
        onRetry: onRetry,
      );
    }

    return ErrorDisplayWidget(
      key: key,
      error: this,
      onRetry: onRetry,
    );
  }
}
