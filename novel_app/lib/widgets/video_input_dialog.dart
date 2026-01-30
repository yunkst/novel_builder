import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import '../widgets/model_selector.dart';
import '../utils/toast_utils.dart';

/// 视频生成要求输入对话框
class VideoInputDialog extends StatefulWidget {
  const VideoInputDialog({super.key});

  @override
  State<VideoInputDialog> createState() => _VideoInputDialogState();

  /// 显示对话框并返回用户输入
  static Future<Map<String, String?>?> show(BuildContext context) async {
    return await showDialog<Map<String, String?>>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => const VideoInputDialog(),
    );
  }
}

class _VideoInputDialogState extends State<VideoInputDialog> {
  final _controller = TextEditingController();
  String? _selectedModel; // 从API动态获取模型列表
  final bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.video_library, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('生成视频'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '描述您想要的视频效果：',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '视频效果描述',
                hintText: '例如：角色缓缓转身，面带微笑，背景为自然风景',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              minLines: 2,
            ),

            const SizedBox(height: 12),

            // 模型选择器
            ModelSelector(
              selectedModel: _selectedModel,
              onModelChanged: (value) {
                setState(() {
                  _selectedModel = value;
                });
              },
              apiType: 'i2v',
              hintText: '选择视频生成模型',
            ),
            const SizedBox(height: 12),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      const Text(
                        '视频生成提示',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '视频生成通常需要1-3分钟，生成的视频时长约5秒，将自动循环播放。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.surface,
                    ),
                  ),
                )
              : const Text('开始生成'),
        ),
      ],
    );
  }

  void _onConfirm() {
    final input = _controller.text.trim();

    // 检查是否输入了内容
    if (input.isEmpty) {
      LoggerService.instance.w(
        '视频效果描述为空',
        category: LogCategory.ui,
        tags: ['video', 'validation', 'empty-description'],
      );
      ToastUtils.showError('请输入视频效果描述');
      return;
    }

    // 返回用户输入和模型选择
    final result = {
      'user_input': input,
      'model_name': _selectedModel,
    };
    Navigator.of(context).pop(result);
  }
}
