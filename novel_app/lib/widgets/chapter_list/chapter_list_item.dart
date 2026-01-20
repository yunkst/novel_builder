import 'package:flutter/material.dart';
import '../../models/chapter.dart';
import 'chapter_title.dart';
import 'chapter_badge.dart';

/// 章节列表项组件（正常模式）
/// 显示章节标题、缓存状态、插入和删除操作按钮
class ChapterListItem extends StatelessWidget {
  final Chapter chapter;
  final bool isLastRead;
  final bool isUserChapter;
  final bool isCached; // 改为直接接收状态
  final bool isRead; // 是否已读
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInsert;
  final VoidCallback? onDelete;

  const ChapterListItem({
    required this.chapter,
    required this.isLastRead,
    required this.isUserChapter,
    required this.isCached,
    this.isRead = false,
    required this.onTap,
    required this.onLongPress,
    required this.onInsert,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isUserChapter ? Colors.blue.withValues(alpha: 0.05) : null,
        border: isUserChapter
            ? Border(
                left: BorderSide(
                color: Colors.blue.withValues(alpha: 0.3),
                width: 3,
              ))
            : null,
      ),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: ChapterTitle(
                title: chapter.title,
                isLastRead: isLastRead,
                isUserChapter: isUserChapter,
                isRead: isRead,
              ),
            ),
            if (isUserChapter) const ChapterBadge(),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chapter.isUserInserted && onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                onPressed: onDelete,
                tooltip: '删除此章节',
              ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.blue,
              ),
              onPressed: onInsert,
              tooltip: '在此章节后插入新章节',
            ),
            // 直接显示缓存状态，不再使用 FutureBuilder
            if (isCached)
              const Icon(
                Icons.download_done,
                color: Colors.green,
              ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
