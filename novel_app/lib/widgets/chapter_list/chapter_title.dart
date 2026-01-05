import 'package:flutter/material.dart';

/// 章节标题组件
///
/// 统一显示章节标题的样式逻辑
class ChapterTitle extends StatelessWidget {
  final String title;
  final bool isLastRead;
  final bool isUserChapter;

  const ChapterTitle({
    required this.title,
    required this.isLastRead,
    required this.isUserChapter,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: isLastRead ? FontWeight.bold : FontWeight.normal,
        color: isLastRead ? Colors.red : null,
        fontStyle: isUserChapter ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}
