import 'package:flutter/material.dart';
import '../../models/chapter.dart';
import 'chapter_title.dart';
import 'chapter_badge.dart';

/// 可重排章节列表项组件（重排模式）
/// 显示章节序号、拖拽手柄，用于章节重排功能
/// 支持显示AI伴读状态（紫色边框）
class ReorderableChapterListItem extends StatelessWidget {
  final Chapter chapter;
  final int index;
  final bool isLastRead;
  final bool isUserChapter;
  final bool isCached; // 是否已缓存
  final bool isRead; // 是否已读
  final bool isAccompanied; // 是否已AI伴读

  const ReorderableChapterListItem({
    required this.chapter,
    required this.index,
    required this.isLastRead,
    required this.isUserChapter,
    required this.isCached,
    this.isRead = false,
    this.isAccompanied = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey(chapter.url),
      decoration: BoxDecoration(
        // 背景色优先级: 已伴读 > 用户插入
        color: isAccompanied
            ? colorScheme.tertiary.withValues(alpha: 0.05)
            : (isUserChapter
                ? colorScheme.primary.withValues(alpha: 0.05)
                : colorScheme.tertiary.withValues(alpha: 0.05)),
        border: isAccompanied
            ? Border(
                // 已伴读: 紫色左边框 + 橙色外框
                left: BorderSide(
                  color: colorScheme.tertiary.withValues(alpha: 0.3),
                  width: 3,
                ),
                right: BorderSide(
                  color: colorScheme.tertiary.withValues(alpha: 0.5),
                  width: 1,
                ),
                top: BorderSide(
                  color: colorScheme.tertiary.withValues(alpha: 0.5),
                  width: 1,
                ),
                bottom: BorderSide(
                  color: colorScheme.tertiary.withValues(alpha: 0.5),
                  width: 1,
                ),
              )
            : (isUserChapter
                ? Border(
                    // 用户插入: 蓝色左边框 + 橙色外框
                    left: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    right: BorderSide(
                      color: colorScheme.tertiary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    top: BorderSide(
                      color: colorScheme.tertiary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: colorScheme.tertiary.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  )
                : Border.all(
                    // 普通: 橙色外框
                    color: colorScheme.tertiary.withValues(alpha: 0.5),
                    width: 1,
                  )),
      ),
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(
          Icons.drag_handle,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: colorScheme.tertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary.withValues(alpha: 0.8),
                ),
              ),
            ),
            Expanded(
              child: ChapterTitle(
                title: chapter.title,
                isLastRead: isLastRead,
                isUserChapter: isUserChapter,
                isRead: isRead, // 传入已读状态
              ),
            ),
            if (isUserChapter) const ChapterBadge(),
            if (isCached) Icon(Icons.offline_pin, size: 16, color: colorScheme.primary),
          ],
        ),
        onTap: () {
          // 重排模式下点击不跳转
        },
      ),
    );
  }
}
