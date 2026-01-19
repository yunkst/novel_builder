import 'package:flutter/material.dart';
import '../screens/chat_scene_management_screen.dart';

/// 聊天场景输入对话框
class ChatSceneInputDialog extends StatefulWidget {
  const ChatSceneInputDialog({super.key});

  @override
  State<ChatSceneInputDialog> createState() => _ChatSceneInputDialogState();

  /// 显示对话框并返回场景描述
  static Future<String?> show(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => const ChatSceneInputDialog(),
    );
  }
}

class _ChatSceneInputDialogState extends State<ChatSceneInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 选择预设场景
  Future<void> _selectPresetScene() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatSceneManagementScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _controller.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设定聊天场景'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请描述您想要的聊天场景：',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '场景描述',
                hintText: '例如：宫廷宴会，月下花前',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 12),

            // 选择预设场景按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _selectPresetScene,
                icon: const Icon(Icons.bookmark),
                label: const Text('选择预设场景'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('开始聊天'),
        ),
      ],
    );
  }

  void _onConfirm() {
    final scene = _controller.text.trim();
    if (scene.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入场景描述'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(scene);
  }
}
