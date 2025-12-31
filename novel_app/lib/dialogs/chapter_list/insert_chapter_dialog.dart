import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../widgets/character_selector.dart';

/// 插入章节对话框
/// 用于创建新章节或在现有章节后插入新章节
class InsertChapterDialog extends StatefulWidget {
  final Novel novel;
  final int afterIndex;
  final List<Chapter> chapters;
  final String? prefillTitle;
  final String? prefillContent;

  const InsertChapterDialog({
    required this.novel,
    required this.afterIndex,
    required this.chapters,
    this.prefillTitle,
    this.prefillContent,
    super.key,
  });

  /// 显示插入章节对话框
  /// 返回包含章节标题、内容和角色ID的Map，如果取消则返回null
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required Novel novel,
    required int afterIndex,
    required List<Chapter> chapters,
    String? prefillTitle,
    String? prefillContent,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InsertChapterDialog(
        novel: novel,
        afterIndex: afterIndex,
        chapters: chapters,
        prefillTitle: prefillTitle,
        prefillContent: prefillContent,
      ),
    );
  }

  @override
  State<InsertChapterDialog> createState() => _InsertChapterDialogState();
}

class _InsertChapterDialogState extends State<InsertChapterDialog> {
  late TextEditingController _titleController;
  late TextEditingController _userInputController;
  List<int> _selectedCharacterIds = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.prefillTitle ?? '');
    _userInputController =
        TextEditingController(text: widget.prefillContent ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _userInputController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    if (_titleController.text.trim().isNotEmpty &&
        _userInputController.text.trim().isNotEmpty) {
      Navigator.pop(context, {
        'title': _titleController.text.trim(),
        'content': _userInputController.text.trim(),
        'characterIds': _selectedCharacterIds,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.chapters.isEmpty;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_circle, color: Colors.blue),
          const SizedBox(width: 8),
          Text(isEmpty ? '创建新章节' : '插入新章节'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEmpty
                  ? '将为小说"${widget.novel.title}"创建第一章'
                  : '将在第${widget.afterIndex + 1}章"${widget.chapters[widget.afterIndex].title}"后插入新章节',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '章节标题',
                hintText: isEmpty ? '例如：第一章 故事的开始' : '例如：第十五章 意外的相遇',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userInputController,
              decoration: const InputDecoration(
                labelText: '章节内容要求',
                hintText: '描述你想要的故事情节、人物对话、场景描述等...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            const Text(
              '出场人物（可选）',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            CharacterSelector(
              novelUrl: widget.novel.url,
              initialSelectedIds: _selectedCharacterIds,
              onSelectionChanged: (selectedIds) {
                setState(() {
                  _selectedCharacterIds = selectedIds;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'AI将根据选中的角色特征来生成章节内容',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text('生成'),
        ),
      ],
    );
  }
}
