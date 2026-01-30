import 'package:flutter/material.dart';

/// StreamingStatusIndicator
///
/// 职责：
/// - 显示AI流式生成的状态（生成中/完成）
/// - 支持渐变色背景
/// - 支持字符计数显示
/// - 支持加载动画
///
/// 使用方式：
/// ```dart
/// StreamingStatusIndicator(
///   isStreaming: true,
///   characterCount: 1250,
/// )
/// ```
class StreamingStatusIndicator extends StatelessWidget {
  final bool isStreaming;
  final int characterCount;
  final String? streamingText;
  final String? completedText;

  const StreamingStatusIndicator({
    super.key,
    required this.isStreaming,
    required this.characterCount,
    this.streamingText,
    this.completedText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isStreaming
              ? [
                  colorScheme.tertiary.withValues(alpha: 0.8),
                  colorScheme.tertiary,
                ]
              : [
                  colorScheme.primary.withValues(alpha: 0.8),
                  colorScheme.primary,
                ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (isStreaming ? colorScheme.tertiary : colorScheme.primary)
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：状态指示器和文本
          Row(
            children: [
              Icon(
                isStreaming ? Icons.stream : Icons.check_circle,
                size: 20,
                color: colorScheme.onPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isStreaming
                      ? (streamingText ?? '实时生成中...')
                      : (completedText ?? '生成完成'),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isStreaming) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // 第二行：字符计数
          Text(
            '已接收 $characterCount 字符',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          if (isStreaming) ...[
            const SizedBox(height: 4),
            // 第三行：提示信息（仅生成时显示）
            Text(
              '正在生成中，请稍候...',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onPrimary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
