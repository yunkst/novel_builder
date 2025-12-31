import 'package:flutter/material.dart';
import '../../models/chapter.dart';

/// 删除章节确认对话框
/// 显示章节标题，要求用户确认删除操作
class DeleteChapterDialog {
  final Chapter chapter;
  final int totalChapters;

  const DeleteChapterDialog({
    required this.chapter,
    required this.totalChapters,
  });

  /// 显示删除确认对话框
  /// 返回用户是否确认删除
  Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('删除章节'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除章节 "${chapter.title}" 吗？',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '此操作无法撤销，章节内容将被永久删除。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
              ),
            ),
            if (totalChapters > 1) ...[
              const SizedBox(height: 8),
              Text(
                '删除后章节列表将重新排序。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
