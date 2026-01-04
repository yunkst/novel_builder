import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../services/database_service.dart';
import '../../services/chapter_history_service.dart';
import '../../core/di/api_service_provider.dart';
import '../../mixins/dify_streaming_mixin.dart';
import '../../widgets/streaming_status_indicator.dart';
import '../../widgets/streaming_content_display.dart';

/// 全文重写对话框
///
/// 职责：
/// - 提供全文重写功能的完整 UI
/// - 支持用户输入重写要求
/// - 使用 DifyStreamingMixin 进行流式生成
/// - 支持替换全文、重新生成功能
class FullRewriteDialog extends StatefulWidget {
  final Novel novel;
  final List<Chapter> chapters;
  final Chapter currentChapter;
  final String content;
  final Future<void> Function(String newContent) onContentReplace;

  const FullRewriteDialog({
    super.key,
    required this.novel,
    required this.chapters,
    required this.currentChapter,
    required this.content,
    required this.onContentReplace,
  });

  @override
  State<FullRewriteDialog> createState() => _FullRewriteDialogState();
}

class _FullRewriteDialogState extends State<FullRewriteDialog>
    with DifyStreamingMixin {
  final ChapterHistoryService _historyService = ChapterHistoryService(
    databaseService: DatabaseService(),
    apiService: ApiServiceProvider.instance,
  );

  final ValueNotifier<String> _rewriteResultNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingNotifier = ValueNotifier<bool>(false);
  String _lastUserInput = '';

  @override
  void initState() {
    super.initState();
    // 自动显示输入对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRequirementDialog();
    });
  }

  @override
  void dispose() {
    _rewriteResultNotifier.dispose();
    _isGeneratingNotifier.dispose();
    super.dispose();
  }

  // 显示重写要求输入对话框
  Future<void> _showRequirementDialog() async {
    final userInputController = TextEditingController(text: _lastUserInput);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_stories, color: Colors.green),
            SizedBox(width: 8),
            Text('全文重写'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将对整章内容进行重写',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: userInputController,
              decoration: const InputDecoration(
                labelText: '重写要求',
                hintText: '例如：改变写作风格、增加细节描写、调整情节节奏等...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            Text(
              '提示：AI将根据你的要求重新创作整章内容',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, userInputController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('开始重写'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _lastUserInput = result;
      _generateFullRewrite(result);
    } else {
      // 用户取消，关闭Dialog
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // 生成全文重写内容（流式）
  Future<void> _generateFullRewrite(String userInput) async {
    // 初始化状态
    _rewriteResultNotifier.value = '';
    _isGeneratingNotifier.value = true;

    try {
      // 使用 ChapterHistoryService 获取历史章节内容
      final historyChaptersContent =
          await _historyService.fetchHistoryChaptersContent(
        chapters: widget.chapters,
        currentChapter: widget.currentChapter,
        maxHistoryCount: 2,
      );

      // 构建全文重写的参数
      final inputs = {
        'user_input': userInput,
        'cmd': '', // 空的cmd参数
        'history_chapters_content': historyChaptersContent,
        'current_chapter_content': widget.content,
        'choice_content': '', // 空的choice_content参数
        'ai_writer_setting': '',
        'background_setting':
            widget.novel.backgroundSetting ?? widget.novel.description ?? '',
        'next_chapter_overview': '',
        'characters_info': '',
      };

      // 显示结果弹窗
      _showResultDialog();

      // 使用统一的流式方法
      await callDifyStreaming(
        inputs: inputs,
        onChunk: (chunk) {
          _rewriteResultNotifier.value += chunk;
        },
        onComplete: (fullContent) {
          _isGeneratingNotifier.value = false;
        },
        onError: (error) {
          _isGeneratingNotifier.value = false;
          _rewriteResultNotifier.value = '生成失败: $error';
        },
        showErrorSnackBar: true,
        errorMessagePrefix: '全文重写失败',
      );
    } catch (e) {
      _isGeneratingNotifier.value = false;
      _rewriteResultNotifier.value = '生成失败: $e';
    }
  }

  // 显示重写结果弹窗
  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_stories, color: Colors.green),
              SizedBox(width: 8),
              Text('全文重写结果'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 内容区域 - 使用公共组件
                ValueListenableBuilder<String>(
                  valueListenable: _rewriteResultNotifier,
                  builder: (context, resultValue, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isGeneratingNotifier,
                      builder: (context, isGenerating, child) {
                        return Column(
                          children: [
                            // 状态指示器 - 使用公共组件
                            StreamingStatusIndicator(
                              isStreaming: isGenerating,
                              characterCount: resultValue.length,
                              streamingText: '实时生成中...',
                              completedText: '生成完成',
                            ),
                            const SizedBox(height: 12),
                            // 内容显示 - 使用公共组件
                            SizedBox(
                              height: 350,
                              child: StreamingContentDisplay(
                                content: resultValue,
                                isStreaming: isGenerating,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '你可以选择替换全文、重新生成或关闭',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingNotifier,
              builder: (context, isGenerating, child) {
                return TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _showRequirementDialog();
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中...' : '重新生成'),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingNotifier,
              builder: (context, isGenerating, child) {
                return ValueListenableBuilder<String>(
                  valueListenable: _rewriteResultNotifier,
                  builder: (context, value, child) {
                    return ElevatedButton.icon(
                      onPressed: (isGenerating || value.isEmpty)
                          ? null
                          : () async {
                              await widget.onContentReplace(value);
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                Navigator.pop(context); // 关闭主Dialog
                              }
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('替换全文'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    );
                  },
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 这个Dialog的主要UI在_showRequirementDialog和_showResultDialog中
    // 这里返回一个空的Container，因为实际UI是通过showDialog显示的
    return const SizedBox.shrink();
  }
}
