import 'package:flutter/material.dart';

/// 角色创建输入对话框
class CharacterInputDialog extends StatefulWidget {
  /// 是否有大纲可用于生成角色
  final bool hasOutline;

  const CharacterInputDialog({
    super.key,
    this.hasOutline = false,
  });

  @override
  State<CharacterInputDialog> createState() => _CharacterInputDialogState();

  /// 显示对话框并返回用户输入和开关状态
  /// 返回格式: {'userInput': String, 'useOutline': bool}
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    bool hasOutline = false,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => CharacterInputDialog(
        hasOutline: hasOutline,
      ),
    );
  }
}

class _CharacterInputDialogState extends State<CharacterInputDialog> {
  final _controller = TextEditingController();
  bool _useOutline = true; // 默认开启大纲生成

  @override
  void initState() {
    super.initState();
    // 如果没有大纲，强制关闭开关
    if (!widget.hasOutline) {
      _useOutline = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI创建角色'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 从大纲生成开关（仅当有大纲时显示）
            if (widget.hasOutline) ...[
              SwitchListTile(
                title: const Text(
                  '从大纲生成角色',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  '利用已有大纲生成更符合故事设定的角色',
                  style: TextStyle(fontSize: 12),
                ),
                value: _useOutline,
                onChanged: (value) {
                  setState(() {
                    _useOutline = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeTrackColor: Colors.blue.withValues(alpha: 0.5),
                activeThumbColor: Colors.blue,
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              '请描述您想要创建的角色：',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '角色描述',
                hintText: widget.hasOutline && _useOutline
                    ? '例如：生成故事中的主要配角'
                    : '例如：一个勇敢的骑士，忠诚而正直',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 16),
            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '创作提示',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '描述角色的性格、外貌、职业、背景等特点，越详细越好。AI将根据您的描述生成完整的角色信息。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
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
          child: const Text('AI生成'),
        ),
      ],
    );
  }

  void _onConfirm() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入角色描述'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 返回用户输入和开关状态
    Navigator.of(context).pop({
      'userInput': input,
      'useOutline': _useOutline,
    });
  }
}
