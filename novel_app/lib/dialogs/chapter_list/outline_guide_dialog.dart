import 'package:flutter/material.dart';
import '../../models/outline.dart';

/// 大纲引导对话框
/// 处理按照大纲插入章节的流程
class OutlineGuideDialog {
  final Outline outline;
  final VoidCallback onManageOutline;

  const OutlineGuideDialog({
    required this.outline,
    required this.onManageOutline,
  });

  /// 显示无大纲提示对话框
  static Future<void> showNoOutlineDialog({
    required BuildContext context,
    required VoidCallback onManageOutline,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Colors.orange),
            SizedBox(width: 8),
            Text('暂无大纲'),
          ],
        ),
        content: const Text(
            '您还没有创建小说大纲，请先创建大纲后再按照大纲插入章节。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onManageOutline();
            },
            child: const Text('去创建大纲'),
          ),
        ],
      ),
    );
  }

  /// 显示大纲内容和生成细纲选项
  /// 返回true表示用户确认生成细纲，false表示取消
  static Future<bool?> showOutlinePreviewDialog({
    required BuildContext context,
    required Outline outline,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Colors.blue),
            SizedBox(width: 8),
            Text('按照大纲插入'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前大纲: ${outline.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  outline.content.length > 300
                      ? '${outline.content.substring(0, 300)}...'
                      : outline.content,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI将根据大纲和前文生成章节细纲，您可以确认或修改细纲后再生成章节内容。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('生成章节细纲'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  /// 显示生成细纲的loading对话框
  static Future<void> showGeneratingDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI正在生成章节细纲...'),
          ],
        ),
      ),
    );
  }
}
