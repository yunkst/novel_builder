import 'package:flutter/material.dart';
import '../../models/chapter.dart';

/// 章节列表项组件（正常模式）
/// 显示章节标题、缓存状态、插入和删除操作按钮
class ChapterListItem extends StatelessWidget {
  final Chapter chapter;
  final bool isLastRead;
  final bool isUserChapter;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onInsert;
  final VoidCallback? onDelete;
  final Future<bool> Function() isChapterCached;

  const ChapterListItem({
    required this.chapter,
    required this.isLastRead,
    required this.isUserChapter,
    required this.onTap,
    required this.onLongPress,
    required this.onInsert,
    this.onDelete,
    required this.isChapterCached,
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
              child: Text(
                chapter.title,
                style: TextStyle(
                  fontWeight: isLastRead ? FontWeight.bold : FontWeight.normal,
                  color: isLastRead ? Colors.red : null,
                  fontStyle:
                      isUserChapter ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (isUserChapter)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '用户',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
            FutureBuilder<bool>(
              future: isChapterCached(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return const Icon(
                    Icons.download_done,
                    color: Colors.green,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
