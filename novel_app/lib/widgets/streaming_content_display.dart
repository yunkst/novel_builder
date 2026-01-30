import 'package:flutter/material.dart';
import 'common/common_widgets.dart';

/// StreamingContentDisplay
///
/// 职责：
/// - 统一显示AI流式生成的内容
/// - 支持空状态、加载状态、内容显示
/// - 支持光标动画（实时生成时）
/// - 支持选择和复制
///
/// 使用方式：
/// ```dart
/// StreamingContentDisplay(
///   content: _generatedContent,
///   isStreaming: _isStreaming,
///   maxHeight: 400,
///   cursorWidget: _buildCursor(), // 可选
/// )
/// ```
class StreamingContentDisplay extends StatelessWidget {
  final String content;
  final bool isStreaming;
  final Widget? cursorWidget;
  final double maxHeight;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const StreamingContentDisplay({
    super.key,
    required this.content,
    required this.isStreaming,
    this.cursorWidget,
    this.maxHeight = 400,
    this.padding,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: borderColor ?? colorScheme.outline.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(12),
        child: content.isEmpty ? _buildPlaceholder(context) : _buildContent(context),
      ),
    );
  }

  /// 构建占位符(空状态或加载状态)
  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isStreaming) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LoadingStateWidget(
            message: '加载中...',
            centered: false,
          ),
          const SizedBox(height: 16),
          Icon(
            Icons.timer_outlined,
            size: 48,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            '等待AI生成内容...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI正在思考并生成内容，请稍候...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return EmptyStateWidget(
      message: '暂无内容',
      icon: Icons.content_paste_outlined,
      centered: false,
    );
  }

  /// 构建内容显示
  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: colorScheme.onSurface,
    );

    // 如果有光标Widget，使用 TextSpan
    if (cursorWidget != null) {
      return SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: content,
              style: textStyle,
            ),
            const WidgetSpan(child: SizedBox(width: 2)), // 小间隙
            WidgetSpan(
              child: cursorWidget!,
              alignment: PlaceholderAlignment.middle,
            ),
          ],
        ),
      );
    }

    // 否则使用普通的 SelectableText
    return SelectableText(
      content,
      style: textStyle,
    );
  }
}

/// 简化版的内容显示组件（用于不需要光标的场景）
class SimpleContentDisplay extends StatelessWidget {
  final String content;
  final double maxHeight;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const SimpleContentDisplay({
    super.key,
    required this.content,
    this.maxHeight = 400,
    this.padding,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamingContentDisplay(
      content: content,
      isStreaming: false,
      maxHeight: maxHeight,
      padding: padding,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
    );
  }
}
