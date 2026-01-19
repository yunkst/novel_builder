import 'package:flutter/material.dart';
import '../models/chat_scene.dart';

/// 聊天场景编辑对话框
///
/// 用于新增或编辑聊天场景
class ChatSceneEditDialog extends StatefulWidget {
  final ChatScene? scene; // null表示新增，非null表示编辑

  const ChatSceneEditDialog({
    super.key,
    this.scene,
  });

  @override
  State<ChatSceneEditDialog> createState() => _ChatSceneEditDialogState();
}

class _ChatSceneEditDialogState extends State<ChatSceneEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.scene != null) {
      _titleController.text = widget.scene!.title;
      _contentController.text = widget.scene!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final scene = ChatScene(
        id: widget.scene?.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: widget.scene?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      Navigator.of(context).pop(scene);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.scene != null;

    return AlertDialog(
      title: Text(isEditing ? '编辑场景' : '新增场景'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 场景标题
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '场景标题',
                  hintText: '例如：咖啡厅约会',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入场景标题';
                  }
                  if (value.trim().isEmpty) {
                    return '标题至少需要1个字符';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 场景内容
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '场景内容',
                  hintText: '例如：午后的咖啡厅，阳光透过窗户洒在桌面上...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入场景内容';
                  }
                  if (value.trim().isEmpty) {
                    return '内容至少需要1个字符';
                  }
                  return null;
                },
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 8),

              // 提示文本
              Text(
                '提示：场景内容将作为角色聊天的背景设定',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
