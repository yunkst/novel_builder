import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../services/api_service_wrapper.dart';
import '../../services/database_service.dart';
import '../../core/di/api_service_provider.dart';
import '../../mixins/dify_streaming_mixin.dart';

/// 章节总结对话框
///
/// 职责：
/// - 提供章节总结功能的完整 UI
/// - 使用 DifyStreamingMixin 进行流式生成
/// - 支持重新总结和复制功能
class ChapterSummaryDialog extends StatefulWidget {
  final Novel novel;
  final List<Chapter> chapters;
  final Chapter currentChapter;
  final String content;

  const ChapterSummaryDialog({
    super.key,
    required this.novel,
    required this.chapters,
    required this.currentChapter,
    required this.content,
  });

  @override
  State<ChapterSummaryDialog> createState() => _ChapterSummaryDialogState();
}

class _ChapterSummaryDialogState extends State<ChapterSummaryDialog>
    with DifyStreamingMixin {
  final ApiServiceWrapper _apiService = ApiServiceProvider.instance;
  final DatabaseService _databaseService = DatabaseService();

  String _summaryResult = '';
  final bool _showConfirmDialog = true;

  @override
  void initState() {
    super.initState();
    // 自动显示确认对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSummarizeConfirmDialog();
    });
  }

  // 显示总结确认对话框
  Future<void> _showSummarizeConfirmDialog() async {
    if (!_showConfirmDialog) {
      // 如果不需要确认，直接开始生成
      _generateSummarize();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.summarize, color: Colors.orange),
            SizedBox(width: 8),
            Text('章节总结'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将对当前章节内容进行总结',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '提示：AI将提取章节的核心内容和关键情节',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('开始总结'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _generateSummarize();
    } else {
      if (mounted) {
        Navigator.pop(context); // 关闭整个 Dialog
      }
    }
  }

  // 生成章节总结（流式）
  Future<void> _generateSummarize() async {
    try {
      final List<String> historyChaptersContent = [];
      final currentIndex =
          widget.chapters.indexWhere((c) => c.url == widget.currentChapter.url);

      // 获取历史章节内容（最多前2章）
      if (currentIndex > 1) {
        final prevChapter2 = widget.chapters[currentIndex - 2];
        final content =
            await _databaseService.getCachedChapter(prevChapter2.url) ??
                await _apiService.getChapterContent(prevChapter2.url);
        historyChaptersContent.add('历史章节: ${prevChapter2.title}\n\n$content');
      }
      if (currentIndex > 0) {
        final prevChapter1 = widget.chapters[currentIndex - 1];
        final content =
            await _databaseService.getCachedChapter(prevChapter1.url) ??
                await _apiService.getChapterContent(prevChapter1.url);
        historyChaptersContent.add('历史章节: ${prevChapter1.title}\n\n$content');
      }

      // 构建总结的参数
      final inputs = {
        'user_input': '总结',
        'cmd': '总结',
        'history_chapters_content': historyChaptersContent.join('\n\n'),
        'current_chapter_content': widget.content,
        'choice_content': '',
        'ai_writer_setting': '',
        'background_setting':
            widget.novel.backgroundSetting ?? widget.novel.description ?? '',
        'next_chapter_overview': '',
        'characters_info': '',
      };

      // 调用 DifyStreamingMixin 的流式方法
      await callDifyStreaming(
        inputs: inputs,
        onChunk: (chunk) {
          setState(() {
            _summaryResult += chunk;
          });
        },
        startMessage: 'AI正在总结章节...',
        completeMessage: '总结完成',
        errorMessagePrefix: '总结失败',
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('准备总结时出错: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 显示生成结果或确认对话框
    if (_showConfirmDialog) {
      return const SizedBox.shrink(); // 确认对话框通过 showDialog 显示
    }

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_summaryResult.isNotEmpty || isStreaming)
              _buildSummaryResultView()
            else
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryResultView() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.summarize, color: Colors.orange),
          SizedBox(width: 8),
          Text('章节总结'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                border: Border.all(color: Colors.grey[700]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 状态指示器
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isStreaming
                              ? [Colors.orange.shade600, Colors.orange.shade800]
                              : [Colors.green.shade600, Colors.green.shade800],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isStreaming ? Icons.stream : Icons.check_circle,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isStreaming ? '实时生成中...' : '生成完成',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (isStreaming)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withValues(alpha: 0.8)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '已接收 ${_summaryResult.length} 字符',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 内容区域
                    Container(
                      constraints: const BoxConstraints(
                        maxHeight: 350,
                        minHeight: 100,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade700.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: _summaryResult.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isStreaming) ...[
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.grey.shade400),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    isStreaming ? '等待AI生成总结...' : '暂无内容',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: SelectableText(
                                  _summaryResult,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '您可以查看总结内容或关闭',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: isStreaming
              ? null
              : () {
                  setState(() {
                    _summaryResult = '';
                  });
                  _generateSummarize();
                },
          icon: const Icon(Icons.refresh),
          label: Text(isStreaming ? '生成中...' : '重新总结'),
        ),
        TextButton.icon(
          onPressed: _summaryResult.isEmpty
              ? null
              : () {
                  // 复制到剪贴板
                  Clipboard.setData(ClipboardData(text: _summaryResult));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制到剪贴板'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
          icon: const Icon(Icons.copy),
          label: const Text('复制'),
        ),
        TextButton(
          onPressed: () {
            if (isStreaming) {
              cancelStreaming(reason: '用户取消');
            }
            Navigator.pop(context);
          },
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
