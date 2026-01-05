import 'package:flutter/material.dart';
import '../../models/chapter.dart';
import 'chapter_title.dart';
import 'chapter_badge.dart';

/// 可重排章节列表项组件（重排模式）
/// 显示章节序号、拖拽手柄，用于章节重排功能
class ReorderableChapterListItem extends StatelessWidget {
  final Chapter chapter;
  final int index;
  final bool isLastRead;
  final bool isUserChapter;

  const ReorderableChapterListItem({
    required this.chapter,
    required this.index,
    required this.isLastRead,
    required this.isUserChapter,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(chapter.url),
      decoration: BoxDecoration(
        color: isUserChapter
            ? Colors.blue.withValues(alpha: 0.05)
            : Colors.orange.withValues(alpha: 0.05),
        border: isUserChapter
            ? Border(
                left: BorderSide(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 3,
                ),
                right: BorderSide(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 1,
                ),
                top: BorderSide(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 1,
                ),
                bottom: BorderSide(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 1,
                ),
              )
            : Border.all(
                color: Colors.orange.withValues(alpha: 0.5),
                width: 1,
              ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(
          Icons.drag_handle,
          color: Colors.grey[600],
        ),
        title: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
            ),
            Expanded(
              child: ChapterTitle(
                title: chapter.title,
                isLastRead: isLastRead,
                isUserChapter: isUserChapter,
              ),
            ),
            if (isUserChapter) const ChapterBadge(),
          ],
        ),
        onTap: () {
          // 重排模式下点击不跳转
        },
      ),
    );
  }
}
