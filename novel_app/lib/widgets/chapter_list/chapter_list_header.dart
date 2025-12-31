import 'package:flutter/material.dart';
import '../../models/novel.dart';

/// 章节列表头部组件
/// 显示小说基本信息（标题、作者、章节数量）
class ChapterListHeader extends StatelessWidget {
  final Novel novel;
  final int chapterCount;

  const ChapterListHeader({
    required this.novel,
    required this.chapterCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            novel.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('作者: ${novel.author}'),
          const SizedBox(height: 4),
          Text('共 $chapterCount 章'),
        ],
      ),
    );
  }
}
