import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/outline.dart';
import '../../core/providers/database_providers.dart';
import '../../mixins/dify_streaming_mixin.dart';
import '../../utils/toast_utils.dart';

/// 创建/编辑大纲页面
/// 支持AI生成大纲和手动编辑
class CreateOutlineScreen extends ConsumerStatefulWidget {
  final String novelUrl;
  final String novelTitle;
  final String? backgroundSetting; // 小说背景设定
  final Outline? existingOutline; // 如果有，表示编辑模式

  const CreateOutlineScreen({
    super.key,
    required this.novelUrl,
    required this.novelTitle,
    this.backgroundSetting,
    this.existingOutline,
  });

  @override
  ConsumerState<CreateOutlineScreen> createState() =>
      _CreateOutlineScreenState();
}

class _CreateOutlineScreenState extends ConsumerState<CreateOutlineScreen>
    with DifyStreamingMixin {
  final _requirementController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _generatedOutline = '';
  bool _saving = false;

  bool get _isEditMode => widget.existingOutline != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      // 编辑模式：加载现有大纲
      _titleController.text = widget.existingOutline!.title;
      _contentController.text = widget.existingOutline!.content;
      _generatedOutline = widget.existingOutline!.content;
    }
  }

  @override
  void dispose() {
    _requirementController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    // mixin会自动清理流式资源
    super.dispose();
  }

  /// 生成大纲（使用Dify流式API + DifyStreamingMixin）
  Future<void> _generateOutline() async {
    if (_requirementController.text.trim().isEmpty) {
      ToastUtils.show('请先输入大纲要求');
      return;
    }

    // 清空之前的内容
    _contentController.clear();
    _generatedOutline = '';

    // 构建Dify输入参数
    final inputs = {
      'cmd': '生成大纲',
      'user_input': _requirementController.text.trim(),
      'background_setting': widget.backgroundSetting ?? '',
    };

    // 调用统一的流式方法 - 只需要10行代码！
    await callDifyStreaming(
      inputs: inputs,
      onChunk: (chunk) {
        _contentController.text += chunk; // Mixin已自动处理特殊标记
        _generatedOutline = _contentController.text;
      },
      onComplete: (fullContent) {
        // 自动填充标题（如果标题为空）
        if (_titleController.text.isEmpty && fullContent.isNotEmpty) {
          _titleController.text = _extractTitle(fullContent);
        }
      },
      startMessage: 'AI正在生成大纲...',
      completeMessage: '大纲生成完成',
      errorMessagePrefix: '生成中断',
    );
  }

  /// 重新生成大纲（使用Dify流式API + DifyStreamingMixin）
  Future<void> _regenerateOutline() async {
    // 弹出对话框获取修改意见
    final feedbackController = TextEditingController();
    final feedback = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改大纲需求'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                hintText: '请输入您的修改意见，例如：增加更多悬念、调整节奏...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, feedbackController.text),
            child: const Text('确认修改'),
          ),
        ],
      ),
    );

    // 验证用户输入
    if (feedback == null || feedback.trim().isEmpty) {
      if (mounted) {
        ToastUtils.show('已取消修改');
      }
      return;
    }

    // 清空之前的内容
    _contentController.clear();
    _generatedOutline = '';

    // 构建Dify输入参数
    final inputs = {
      'cmd': '生成大纲',
      'user_input': feedback.trim(),
      'background_setting': widget.backgroundSetting ?? '',
      'outline': widget.existingOutline?.content ?? _generatedOutline,
    };

    // 调用统一的流式方法 - 也只需要10行代码！
    await callDifyStreaming(
      inputs: inputs,
      onChunk: (chunk) {
        _contentController.text += chunk; // Mixin已自动处理特殊标记
        _generatedOutline = _contentController.text;
      },
      onComplete: (fullContent) {
        // 更新标题
        if (fullContent.isNotEmpty) {
          _titleController.text = _extractTitle(fullContent);
        }
      },
      startMessage: 'AI正在修改大纲...',
      completeMessage: '大纲修改完成',
      errorMessagePrefix: '修改中断',
    );
  }

  /// 保存大纲
  Future<void> _saveOutline() async {
    if (_titleController.text.trim().isEmpty) {
      ToastUtils.show('请输入大纲标题');
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ToastUtils.show('请输入或生成大纲内容');
      return;
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(outlineRepositoryProvider);
      final outline = Outline(
        novelUrl: widget.novelUrl,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.saveOutline(outline);

      if (mounted) {
        Navigator.pop(context, true); // 返回true表示保存成功
        ToastUtils.showSuccess(_isEditMode ? '大纲已更新' : '大纲已创建');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// 从大纲内容中提取标题
  String _extractTitle(String outline) {
    // 简单提取第一行作为标题
    final lines = outline.split('\n');
    for (var line in lines) {
      if (line.trim().isNotEmpty) {
        // 移除Markdown标题符号
        var title = line.trim().replaceAll(RegExp(r'^#+\s*'), '');
        if (title.isNotEmpty) {
          return title.length > 50 ? '${title.substring(0, 50)}...' : title;
        }
      }
    }
    return '未命名大纲';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '编辑大纲' : '创建大纲'),
        actions: [
          // 保存按钮
          if (!isStreaming)
            TextButton(
              onPressed: _saving ? null : _saveOutline,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 大纲标题输入
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '大纲标题',
                hintText: '例如：XX小说大纲',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 大纲要求输入（非编辑模式显示）
            if (!_isEditMode) ...[
              TextField(
                controller: _requirementController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '大纲要求',
                  hintText: '请简述您的大纲要求，例如：\n'
                      '一部玄幻小说，主角从废柴成长为强者，'
                      '经历冒险、友情、爱情等考验...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 生成按钮 / 取消按钮
              if (!isStreaming)
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('生成大纲'),
                  onPressed: isStreaming ? null : _generateOutline,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('取消生成'),
                        onPressed: cancelStreaming,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('AI正在生成大纲...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // 生成的大纲内容预览或编辑区域
            if (_generatedOutline.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '大纲内容',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!_isEditMode)
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('修改大纲'),
                      onPressed: isStreaming ? null : _regenerateOutline,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: '大纲内容将显示在这里，您也可以手动编辑...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 提示信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '您可以直接编辑上方的大纲内容，点击右上角的"保存"按钮即可保存。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isEditMode) ...[
              // 编辑模式直接显示编辑框
              TextField(
                controller: _contentController,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: '大纲内容',
                  hintText: '输入您的大纲内容...',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              // 空状态提示
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '输入大纲要求并点击"生成大纲"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
