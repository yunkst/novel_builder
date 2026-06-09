import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// TTS定时完成对话框
///
/// 当定时朗读完成时显示，提示用户已完成X章，并提供继续或关闭选项
class TtsTimerCompleteDialog extends StatelessWidget {
  /// 已完成章节数
  final int completedChapters;

  /// 当前章节索引
  final int currentChapterIndex;

  /// 继续朗读回调
  final VoidCallback onContinue;

  /// 关闭回调
  final VoidCallback onClose;

  const TtsTimerCompleteDialog({
    super.key,
    required this.completedChapters,
    required this.currentChapterIndex,
    required this.onContinue,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final currentChapterNum = currentChapterIndex + 1;

    return AlertDialog(
      icon: Icon(
        Icons.timer_outlined,
        size: 48,
        color: context.appColors.warning,
      ),
      title: const Text(
        '定时朗读完成',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.warningContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.warningContainer),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: context.appColors.onWarningContainer, size: 20),
                const SizedBox(width: 8),
                Text(
                  '已完成朗读 $completedChapters 章',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '当前: 第 $currentChapterNum 章',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            '关闭',
            style: TextStyle(fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appColors.warning,
            foregroundColor: context.appColors.onSemantic,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            '继续朗读',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
