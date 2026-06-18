import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 章节生成进度对话框
/// 显示AI生成章节的实时进度，支持取消、重试、插入操作
class ChapterGenerationDialog extends StatelessWidget {
  final ValueNotifier<String> generatedContentNotifier;
  final ValueNotifier<bool> isGeneratingNotifier;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onInsert;

  const ChapterGenerationDialog({
    super.key,
    required this.generatedContentNotifier,
    required this.isGeneratingNotifier,
    required this.onCancel,
    required this.onRetry,
    required this.onInsert,
  });

  /// 显示生成进度对话框
  /// 返回用户选择的操作结果：null=取消, false=重试, true=插入
  static Future<bool?> show({
    required BuildContext context,
    required ValueNotifier<String> generatedContentNotifier,
    required ValueNotifier<bool> isGeneratingNotifier,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChapterGenerationDialog(
        generatedContentNotifier: generatedContentNotifier,
        isGeneratingNotifier: isGeneratingNotifier,
        onCancel: () => Navigator.pop(dialogContext),
        onRetry: () {
          Navigator.pop(dialogContext, false);
        },
        onInsert: () {
          Navigator.pop(dialogContext, true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: context.appColors.info),
          const SizedBox(width: 8),
          Text('生成新章节'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: generatedContentNotifier,
                  builder: (context, value, child) {
                    return Text(
                      value.isEmpty ? '正在生成中...' : value,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '生成完成后，你可以选择插入或重新生成',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('取消'),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: isGeneratingNotifier,
          builder: (context, isGenerating, child) {
            return TextButton.icon(
              onPressed: isGenerating ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(isGenerating ? '生成中' : '重试'),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: isGeneratingNotifier,
          builder: (context, isGenerating, child) {
            return ValueListenableBuilder<String>(
              valueListenable: generatedContentNotifier,
              builder: (context, value, child) {
                return ElevatedButton.icon(
                  onPressed: (isGenerating || value.isEmpty) ? null : onInsert,
                  icon: const Icon(Icons.check),
                  label: const Text('插入'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appColors.success,
                    foregroundColor: context.appColors.onSemantic,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
