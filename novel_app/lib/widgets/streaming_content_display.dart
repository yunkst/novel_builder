import 'package:flutter/material.dart';

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
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[800],
        border: Border.all(
          color: borderColor ?? Colors.grey[700]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(12),
        child: content.isEmpty ? _buildPlaceholder() : _buildContent(),
      ),
    );
  }

  /// 构建占位符（空状态或加载状态）
  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isStreaming) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Icon(
            isStreaming ? Icons.timer_outlined : Icons.content_paste_outlined,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            isStreaming ? '等待AI生成内容...' : '暂无内容',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          if (isStreaming) ...[
            const SizedBox(height: 8),
            Text(
              'AI正在思考并生成内容，请稍候...',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建内容显示
  Widget _buildContent() {
    final textStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: Colors.white,
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
