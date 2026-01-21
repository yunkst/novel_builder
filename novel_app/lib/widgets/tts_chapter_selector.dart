import 'package:flutter/material.dart';
import '../models/chapter.dart';

/// TTS章节选择器组件
class TtsChapterSelector extends StatefulWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final ValueChanged<Chapter> onChapterSelected;

  const TtsChapterSelector({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onChapterSelected,
  });

  @override
  State<TtsChapterSelector> createState() => _TtsChapterSelectorState();
}

class _TtsChapterSelectorState extends State<TtsChapterSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<Chapter> _filteredChapters = [];

  @override
  void initState() {
    super.initState();
    _filteredChapters = widget.chapters;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterChapters(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChapters = widget.chapters;
      } else {
        _filteredChapters = widget.chapters
            .where((chapter) =>
                chapter.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // 顶部拖动条
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      '选择章节',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // 搜索框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索章节...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: _filterChapters,
                ),
              ),

              // 章节列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredChapters.length,
                  itemBuilder: (context, index) {
                    final chapter = _filteredChapters[index];
                    final originalIndex = widget.chapters.indexOf(chapter);
                    final isCurrent = originalIndex == widget.currentIndex;

                    return ListTile(
                      leading: isCurrent
                          ? Icon(
                              Icons.graphic_eq,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : Text('${originalIndex + 1}'),
                      title: Text(
                        chapter.title,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      trailing: isCurrent
                          ? Icon(
                              Icons.play_circle_filled,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () {
                        widget.onChapterSelected(chapter);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
