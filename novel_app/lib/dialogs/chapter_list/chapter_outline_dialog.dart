import 'package:flutter/material.dart';
import '../../models/outline.dart';
import '../../controllers/chapter_list/outline_integration_handler.dart';
import '../../utils/toast_utils.dart';

/// 章节细纲编辑对话框
/// 显示AI生成的章节细纲，允许用户编辑或重新生成
class ChapterOutlineDialog extends StatefulWidget {
  final ChapterOutlineDraft draft;
  final String novelUrl;
  final OutlineIntegrationHandler outlineHandler;

  const ChapterOutlineDialog({
    required this.draft,
    required this.novelUrl,
    required this.outlineHandler,
    super.key,
  });

  /// 显示章节细纲对话框
  /// 返回用户确认后的细纲，如果取消则返回null
  static Future<ChapterOutlineDraft?> show({
    required BuildContext context,
    required ChapterOutlineDraft draft,
    required String novelUrl,
    required OutlineIntegrationHandler outlineHandler,
  }) {
    return showDialog<ChapterOutlineDraft>(
      context: context,
      builder: (context) => ChapterOutlineDialog(
        draft: draft,
        novelUrl: novelUrl,
        outlineHandler: outlineHandler,
      ),
    );
  }

  @override
  State<ChapterOutlineDialog> createState() => _ChapterOutlineDialogState();
}

class _ChapterOutlineDialogState extends State<ChapterOutlineDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late ChapterOutlineDraft _currentDraft;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _currentDraft = widget.draft;
    _titleController = TextEditingController(text: _currentDraft.title);
    _contentController = TextEditingController(text: _currentDraft.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _regenerateOutline() async {
    setState(() => _isRegenerating = true);

    try {
      final outline = await widget.outlineHandler.getOutline(widget.novelUrl);
      if (outline != null && mounted) {
        final newDraft = await widget.outlineHandler.regenerateChapterOutline(
          novelUrl: widget.novelUrl,
          mainOutline: outline.content,
          previousChapters: [],
          feedback: _contentController.text,
          currentDraft: _currentDraft,
        );

        setState(() {
          _titleController.text = newDraft.title;
          _contentController.text = newDraft.content;
          _currentDraft = newDraft;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('重新生成失败: $e', context: context);
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  void _handleConfirm() {
    if (_titleController.text.trim().isNotEmpty &&
        _contentController.text.trim().isNotEmpty) {
      final confirmedDraft = ChapterOutlineDraft(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        keyPoints: _currentDraft.keyPoints,
      );
      Navigator.pop(context, confirmedDraft);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: Colors.blue),
          SizedBox(width: 8),
          Text('章节细纲'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请确认或编辑章节细纲',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '章节标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '细纲内容',
                border: OutlineInputBorder(),
              ),
            ),
            if (_currentDraft.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '关键要点：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ..._currentDraft.keyPoints.map((point) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text(
                      '• $point',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRegenerating ? null : _regenerateOutline,
          child: _isRegenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('重新生成'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text('确认并生成章节'),
        ),
      ],
    );
  }
}
