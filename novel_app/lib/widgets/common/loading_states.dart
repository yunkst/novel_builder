import 'package:flutter/material.dart';

/// 加载状态组件
///
/// 用于显示加载中的占位组件，可配合CircularProgressIndicator使用。
///
/// 示例:
/// ```dart
/// LoadingStateWidget(message: '正在加载章节列表...')
/// ```
class LoadingStateWidget extends StatelessWidget {
  /// 加载提示信息
  final String? message;

  /// 是否显示为居中布局（默认为true）
  final bool centered;

  const LoadingStateWidget({
    super.key,
    this.message,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );

    if (centered) {
      return Center(child: content);
    }
    return content;
  }
}

/// 错误状态组件
///
/// 用于显示错误状态和重试选项。
///
/// 示例:
/// ```dart
/// ErrorStateWidget(
///   message: '加载失败',
///   onRetry: () => retry(),
/// )
/// ```
class ErrorStateWidget extends StatelessWidget {
  /// 错误提示信息
  final String message;

  /// 重试回调函数
  final VoidCallback? onRetry;

  /// 错误图标
  final IconData? icon;

  /// 重试按钮文本
  final String retryText;

  /// 是否显示为居中布局（默认为true）
  final bool centered;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.retryText = '重试',
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon ?? Icons.error_outline,
          size: 48,
          color: colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryText),
          ),
        ],
      ],
    );

    if (centered) {
      return Center(child: content);
    }
    return content;
  }
}

/// 空状态组件
///
/// 用于显示空数据状态的占位组件。
///
/// 示例:
/// ```dart
/// EmptyStateWidget(
///   message: '暂无章节',
///   icon: Icons.menu_book,
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// 空状态提示信息
  final String message;

  /// 空状态图标
  final IconData? icon;

  /// 是否显示为居中布局（默认为true）
  final bool centered;

  /// 操作按钮文本（可选）
  final String? actionText;

  /// 操作按钮回调（可选）
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon,
    this.centered = true,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon ?? Icons.inbox_outlined,
          size: 48,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        if (actionText != null && onAction != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: Text(actionText!),
          ),
        ],
      ],
    );

    if (centered) {
      return Center(child: content);
    }
    return content;
  }
}
