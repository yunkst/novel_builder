import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../services/database_service.dart';
import '../../services/chapter_history_service.dart';
import '../../services/rewrite_service.dart';
import '../../core/di/api_service_provider.dart';
import '../../mixins/dify_streaming_mixin.dart';
import '../../utils/media_markup_parser.dart';
import '../../widgets/streaming_status_indicator.dart';
import '../../widgets/streaming_content_display.dart';

/// 段落改写对话框
///
/// 职责：
/// - 提供段落改写功能的完整 UI
/// - 使用 DifyStreamingMixin 进行流式生成
/// - 支持选择多个段落进行改写
/// - 支持替换原文或重新改写
class ParagraphRewriteDialog extends StatefulWidget {
  final Novel novel;
  final List<Chapter> chapters;
  final Chapter currentChapter;
  final String content;
  final List<int> selectedParagraphIndices;
  final Function(String newContent) onReplace;

  const ParagraphRewriteDialog({
    super.key,
    required this.novel,
    required this.chapters,
    required this.currentChapter,
    required this.content,
    required this.selectedParagraphIndices,
    required this.onReplace,
  });

  @override
  State<ParagraphRewriteDialog> createState() => _ParagraphRewriteDialogState();
}

class _ParagraphRewriteDialogState extends State<ParagraphRewriteDialog>
    with TickerProviderStateMixin, DifyStreamingMixin {
  final ChapterHistoryService _historyService = ChapterHistoryService(
    databaseService: DatabaseService(),
    apiService: ApiServiceProvider.instance,
  );
  final RewriteService _rewriteService = RewriteService();

  // 光标动画控制器
  late AnimationController _cursorController;
  late Animation<double> _cursorAnimation;

  // 改写结果
  String _rewriteResult = '';
  String _lastRewriteInput = '';

  @override
  void initState() {
    super.initState();

    // 初始化光标动画
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 530),
      vsync: this,
    );
    _cursorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cursorController,
      curve: Curves.easeInOut,
    ))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _cursorController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _cursorController.forward();
        }
      });
    _cursorController.forward();

    // 自动显示输入对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRewriteRequirementDialog();
    });
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  // 获取选中的文本（支持插图段落）
  String _getSelectedText(List<String> paragraphs) {
    if (widget.selectedParagraphIndices.isEmpty) return '';

    final selectedTexts = <String>[];

    for (final index in widget.selectedParagraphIndices) {
      if (index < 0 || index >= paragraphs.length) continue;

      final paragraph = paragraphs[index];

      // 如果是插图标记，转换为描述性文本
      if (MediaMarkupParser.isMediaMarkup(paragraph)) {
        final markup = MediaMarkupParser.parseMediaMarkup(paragraph).first;
        if (markup.isIllustration) {
          selectedTexts.add('[插图：此处应显示图片内容，taskId: ${markup.id}]');
        } else {
          selectedTexts.add('[${markup.type}：${markup.id}]');
        }
      } else {
        selectedTexts.add(paragraph.trim());
      }
    }

    return selectedTexts.join('\n\n'); // 用双空行分隔，保持结构清晰
  }

  // 打开改写要求输入弹窗
  Future<void> _showRewriteRequirementDialog() async {
    final paragraphs = widget.content.split('\n').where((p) => p.trim().isNotEmpty).toList();
    final selectedText = _getSelectedText(paragraphs);
    if (selectedText.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final userInputController = TextEditingController(text: _lastRewriteInput);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('输入改写要求'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已选择 ${widget.selectedParagraphIndices.length} 个段落',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userInputController,
                decoration: const InputDecoration(
                  hintText: '例如：增加细节描述、改变语气、加强情感表达等...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                maxLines: 3,
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
            onPressed: () {
              Navigator.pop(context, userInputController.text);
            },
            child: const Text('确认改写'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _lastRewriteInput = result;
      _generateRewrite(selectedText, result);
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // 生成改写内容（流式）
  Future<void> _generateRewrite(String selectedText, String userInput) async {
    try {
      // 使用 ChapterHistoryService 获取历史章节内容
      final historyChaptersContent =
          await _historyService.fetchHistoryChaptersContent(
        chapters: widget.chapters,
        currentChapter: widget.currentChapter,
        maxHistoryCount: 2,
      );

      // 特写功能不使用角色选择
      const String rolesInfo = '无特定角色出场';

      // 获取AI作家设定
      final prefs = await SharedPreferences.getInstance();
      final aiWriterSetting = prefs.getString('ai_writer_prompt') ?? '';

      // 使用 RewriteService 构建输入参数
      final inputs = _rewriteService.buildRewriteInputsWithHistory(
        selectedText: selectedText,
        userInput: userInput,
        currentChapterContent: widget.content,
        historyChaptersContent: historyChaptersContent,
        backgroundSetting: widget.novel.backgroundSetting ?? '',
        aiWriterSetting: aiWriterSetting,
        rolesInfo: rolesInfo,
      );

      // 调用 DifyStreamingMixin 的流式方法
      await callDifyStreaming(
        inputs: inputs,
        onChunk: (chunk) {
          setState(() {
            _rewriteResult += chunk;
          });
        },
        startMessage: 'AI正在改写内容...',
        completeMessage: '改写完成',
        errorMessagePrefix: '改写失败',
      );

    } catch (e) {
      debugPrint('❌ 准备改写内容时发生异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 构建闪烁光标组件
  Widget _buildCursor() {
    return AnimatedBuilder(
      animation: _cursorAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _cursorAnimation.value,
          child: Container(
            width: 2,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  // 替换选中的段落
  void _replaceSelectedParagraphs() {
    final paragraphs = widget.content.split('\n');
    final rewrittenParagraphs = _rewriteResult.split('\n');

    if (widget.selectedParagraphIndices.length != rewrittenParagraphs.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('警告：段落数量不匹配，请手动调整'),
          backgroundColor: Colors.orange,
        ),
      );
      // 继续执行，让用户手动调整
    }

    // 执行替换
    int rewriteIndex = 0;
    final updatedParagraphs = List<String>.from(paragraphs);

    for (final index in widget.selectedParagraphIndices) {
      if (index >= 0 && index < updatedParagraphs.length && rewriteIndex < rewrittenParagraphs.length) {
        final originalParagraph = updatedParagraphs[index];

        // 检查是否是插图标记
        if (MediaMarkupParser.isMediaMarkup(originalParagraph)) {
          final markup = MediaMarkupParser.parseMediaMarkup(originalParagraph).first;
          if (markup.isIllustration) {
            // 保留插图标记，询问用户是否替换
            _showIllustrationReplaceDialog(
              index: index,
              originalMarkup: originalParagraph,
              newContent: rewrittenParagraphs[rewriteIndex],
              updatedParagraphs: updatedParagraphs,
              rewriteIndex: rewriteIndex,
            );
            return; // 暂停替换，等待用户选择
          }
        }

        // 普通文本，直接替换
        updatedParagraphs[index] = rewrittenParagraphs[rewriteIndex];
      }
      rewriteIndex++;
    }

    // 完成替换
    final newContent = updatedParagraphs.join('\n');
    widget.onReplace(newContent);
    Navigator.pop(context); // 关闭改写对话框

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('段落已替换'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 显示插图替换确认对话框
  void _showIllustrationReplaceDialog({
    required int index,
    required String originalMarkup,
    required String newContent,
    required List<String> updatedParagraphs,
    required int rewriteIndex,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('插图段落处理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('检测到选中的段落包含插图标记：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                originalMarkup,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text('是否替换为新的改写内容？'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                newContent,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // 关闭确认对话框
              // 继续处理剩余段落
              _continueReplacement(
                updatedParagraphs: updatedParagraphs,
                startIndex: index + 1,
                rewriteIndex: rewriteIndex + 1,
                skipIllustration: true,
              );
            },
            child: const Text('保留插图'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext); // 关闭确认对话框
              // 替换插图并继续
              updatedParagraphs[index] = newContent;
              _continueReplacement(
                updatedParagraphs: updatedParagraphs,
                startIndex: index + 1,
                rewriteIndex: rewriteIndex + 1,
                skipIllustration: false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('替换为文本'),
          ),
        ],
      ),
    );
  }

  // 继续替换剩余段落
  void _continueReplacement({
    required List<String> updatedParagraphs,
    required int startIndex,
    required int rewriteIndex,
    required bool skipIllustration,
  }) {
    final rewrittenParagraphs = _rewriteResult.split('\n');
    int currentRewriteIndex = rewriteIndex;

    for (int i = startIndex; i < widget.selectedParagraphIndices.length && currentRewriteIndex < rewrittenParagraphs.length; i++) {
      final index = widget.selectedParagraphIndices[i];
      if (index >= 0 && index < updatedParagraphs.length) {
        final originalParagraph = updatedParagraphs[index];

        // 检查是否是插图标记
        if (MediaMarkupParser.isMediaMarkup(originalParagraph)) {
          final markup = MediaMarkupParser.parseMediaMarkup(originalParagraph).first;
          if (markup.isIllustration && !skipIllustration) {
            // 跳过插图标记
            continue;
          }
        }

        // 替换段落
        updatedParagraphs[index] = rewrittenParagraphs[currentRewriteIndex];
      }
      currentRewriteIndex++;
    }

    // 完成替换
    final newContent = updatedParagraphs.join('\n');
    widget.onReplace(newContent);
    Navigator.pop(context); // 关闭改写对话框

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('段落已替换'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 直接使用 AlertDialog，避免 Dialog 双层嵌套导致内容区域过窄
    if (_rewriteResult.isNotEmpty || isStreaming) {
      return _buildRewriteResultView();
    } else {
      return const AlertDialog(
        content: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
  }

  Widget _buildRewriteResultView() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.blue),
          SizedBox(width: 8),
          Text('改写结果'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
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
                    // 状态指示器 - 使用公共组件
                    StreamingStatusIndicator(
                      isStreaming: isStreaming,
                      characterCount: _rewriteResult.length,
                      streamingText: '实时生成中...',
                      completedText: '生成完成',
                    ),
                    const SizedBox(height: 12),
                    // 内容区域 - 使用公共组件（带光标动画）
                    SizedBox(
                      height: 250,
                      child: StreamingContentDisplay(
                        content: _rewriteResult,
                        isStreaming: isStreaming,
                        cursorWidget: isStreaming ? _buildCursor() : null,
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
                    '你可以选择替换原文、重新改写或关闭',
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
                    _rewriteResult = '';
                  });
                  _showRewriteRequirementDialog();
                },
          icon: const Icon(Icons.refresh),
          label: Text(isStreaming ? '生成中...' : '重写'),
        ),
        ElevatedButton.icon(
          onPressed: (_rewriteResult.isEmpty || isStreaming)
              ? null
              : () {
                  _replaceSelectedParagraphs();
                },
          icon: const Icon(Icons.check),
          label: const Text('替换'),
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
