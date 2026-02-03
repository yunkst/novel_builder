import 'package:flutter/material.dart';

/// 统一的加载指示器组件
///
/// 提供多种加载状态的显示样式。
///
/// 示例:
/// ```dart
/// LoadingWidget()
/// LoadingWidget(message: '正在加载章节...')
/// LoadingWidget.circular(size: 30)
/// LoadingWidget.custom(
///   child: Text('自定义加载中...'),
/// )
/// ```
class LoadingWidget extends StatelessWidget {
  /// 加载提示信息
  final String? message;

  /// 加载指示器大小
  final double? size;

  /// 加载指示器颜色
  final Color? color;

  /// 是否显示为居中布局（默认为 true）
  final bool centered;

  /// 加载指示器类型
  final LoadingType type;

  /// 自定义加载组件（当 type 为 LoadingType.custom 时使用）
  final Widget? customChild;

  const LoadingWidget({
    super.key,
    this.message,
    this.size,
    this.color,
    this.centered = true,
    this.type = LoadingType.circular,
    this.customChild,
  });

  /// 创建圆形进度指示器
  const LoadingWidget.circular({
    super.key,
    this.message,
    this.size,
    this.color,
    this.centered = true,
  }) : type = LoadingType.circular,
       customChild = null;

  /// 创建线性进度指示器
  const LoadingWidget.linear({
    super.key,
    this.message,
    this.size,
    this.color,
    this.centered = true,
  }) : type = LoadingType.linear,
       customChild = null;

  /// 创建自定义加载组件
  const LoadingWidget.custom({
    super.key,
    required Widget child,
    this.centered = true,
  }) : type = LoadingType.custom,
       customChild = child,
       message = null,
       size = null,
       color = null;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (centered) {
      return Center(child: content);
    }
    return content;
  }

  Widget _buildContent(BuildContext context) {
    switch (type) {
      case LoadingType.circular:
        return _buildCircular(context);

      case LoadingType.linear:
        return _buildLinear(context);

      case LoadingType.custom:
        return customChild!;
    }
  }

  /// 构建圆形进度指示器
  Widget _buildCircular(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size != null && size! < 30 ? 3 : 4,
            color: indicatorColor,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建线性进度指示器
  Widget _buildLinear(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size ?? 200,
          child: LinearProgressIndicator(
            color: indicatorColor,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

/// 加载指示器类型
enum LoadingType {
  /// 圆形进度指示器
  circular,

  /// 线性进度指示器
  linear,

  /// 自定义组件
  custom,
}

/// 小型加载指示器（用于按钮等小空间）
class SmallLoadingWidget extends StatelessWidget {
  final Color? color;
  final double size;

  const SmallLoadingWidget({
    super.key,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.onPrimary;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: indicatorColor,
      ),
    );
  }
}

/// 全屏加载遮罩
///
/// 通常用于 Dialog 或 Overlay 中。
///
/// 示例:
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (context) => FullScreenLoadingWidget(
///     message: '正在保存...',
///   ),
/// );
/// ```
class FullScreenLoadingWidget extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;

  const FullScreenLoadingWidget({
    super.key,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface.withValues(alpha: 0.9);

    return Container(
      color: bgColor,
      child: Center(
        child: LoadingWidget(
          message: message,
          size: 40,
        ),
      ),
    );
  }
}
