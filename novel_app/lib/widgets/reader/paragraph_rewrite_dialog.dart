import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../services/novel_context_service.dart';
import '../../services/rewrite_service.dart';
import '../../mixins/dify_streaming_mixin.dart';
import '../../utils/media_markup_parser.dart';
import '../../utils/paragraph_replace_helper.dart';
import '../../widgets/streaming_status_indicator.dart';
import '../../widgets/streaming_content_display.dart';
import '../../utils/toast_utils.dart';

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
  final NovelContextBuilder _contextBuilder = NovelContextBuilder();
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
    final paragraphs =
        widget.content.split('\n').where((p) => p.trim().isNotEmpty).toList();
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
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
      // 使用 NovelContextBuilder 统一获取上下文数据
      final novelContext = await _contextBuilder.buildContext(
        widget.novel,
        widget.chapters,
        widget.currentChapter,
        widget.content,
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
        currentChapterContent: novelContext.currentChapterContent,
        historyChaptersContent: novelContext.historyChaptersContent,
        backgroundSetting: novelContext.backgroundSetting,
        aiWriterSetting: aiWriterSetting,
        rolesInfo: rolesInfo,
      );

      // 调用 DifyStreamingMixin 的流式方法
      await callDifyStreaming(
        inputs: inputs,
        onChunk: (chunk) {
          setState(() {
            _rewriteResult += chunk; // Mixin已自动处理特殊标记
          });
        },
        startMessage: 'AI正在改写内容...',
        completeMessage: '改写完成',
        errorMessagePrefix: '改写失败',
      );
    } catch (e) {
      debugPrint('❌ 准备改写内容时发生异常: $e');
      if (mounted) {
        ToastUtils.showError('操作失败: $e');
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  // 替换选中的段落（新逻辑：删除选中段落 + 插入AI生成内容）
  void _replaceSelectedParagraphs() {
    // ⚠️ 重要：必须过滤空段落，与UI层保持一致
    // UI层（reader_screen.dart）使用的是过滤后的段落列表
    // 如果不在这里过滤，会导致索引不匹配
    final paragraphs = widget.content
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final rewrittenParagraphs = _rewriteResult.split('\n');

    // 显示操作信息（可选）
    if (rewrittenParagraphs.isNotEmpty) {
      debugPrint(
          '📝 准备替换: 删除 ${widget.selectedParagraphIndices.length} 段，插入 ${rewrittenParagraphs.length} 段');
    }

    final updatedParagraphs = List<String>.from(paragraphs);

    // 检查选中段落中是否包含插图标记
    bool hasIllustration = false;

    for (final index in widget.selectedParagraphIndices) {
      if (index >= 0 && index < updatedParagraphs.length) {
        final paragraph = updatedParagraphs[index];
        if (MediaMarkupParser.isMediaMarkup(paragraph)) {
          final markup = MediaMarkupParser.parseMediaMarkup(paragraph).first;
          if (markup.isIllustration) {
            hasIllustration = true;
            break;
          }
        }
      }
    }

    // 如果包含插图，询问用户如何处理
    if (hasIllustration) {
      _showIllustrationReplaceDialog(
        updatedParagraphs: updatedParagraphs,
        rewrittenParagraphs: rewrittenParagraphs,
      );
      return; // 等待用户选择
    }

    // 无插图，直接执行删除+插入
    _executeDeleteAndInsert(updatedParagraphs, widget.selectedParagraphIndices,
        rewrittenParagraphs);
  }

  // 执行删除和插入操作（优化版：使用工具类）
  void _executeDeleteAndInsert(
    List<String> updatedParagraphs,
    List<int> indicesToDelete,
    List<String> contentToInsert,
  ) {
    if (indicesToDelete.isEmpty) {
      debugPrint('⚠️ 没有要删除的段落');
      return;
    }

    final originalLength = widget.content.split('\n').length;

    // 使用工具类执行替换
    final resultParagraphs = ParagraphReplaceHelper.executeReplace(
      paragraphs: updatedParagraphs,
      selectedIndices: indicesToDelete,
      newContent: contentToInsert,
    );

    // 验证替换结果
    final validation = ParagraphReplaceHelper.validateReplacement(
      originalParagraphs: widget.content.split('\n'),
      updatedParagraphs: resultParagraphs,
      selectedIndices: indicesToDelete,
    );

    if (!validation.isValid) {
      debugPrint('⚠️ ${validation.message}');
    }

    // 完成替换
    final newContent = resultParagraphs.join('\n');
    final newLength = resultParagraphs.length;

    widget.onReplace(newContent);
    Navigator.pop(context); // 关闭改写对话框

    ToastUtils.showSuccess(
        '已删除 ${indicesToDelete.length} 段，插入 ${contentToInsert.length} 段（章节长度: $originalLength → $newLength）');
  }

  // 显示插图替换确认对话框（适配新逻辑：删除+插入）
  void _showIllustrationReplaceDialog({
    required List<String> updatedParagraphs,
    required List<String> rewrittenParagraphs,
  }) {
    // 查找所有插图索引
    final illustrationIndices = <int>[];
    final illustrationMarkups = <String>[];

    for (final index in widget.selectedParagraphIndices) {
      if (index >= 0 && index < updatedParagraphs.length) {
        final paragraph = updatedParagraphs[index];
        if (MediaMarkupParser.isMediaMarkup(paragraph)) {
          final markup = MediaMarkupParser.parseMediaMarkup(paragraph).first;
          if (markup.isIllustration) {
            illustrationIndices.add(index);
            illustrationMarkups.add(paragraph);
          }
        }
      }
    }

    // 显示对话框
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('插图段落处理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('检测到选中的区域中包含 ${illustrationIndices.length} 个插图标记'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: illustrationMarkups
                    .map((markup) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            markup,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('是否继续删除并替换？'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.3),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '将删除 ${widget.selectedParagraphIndices.length} 段（包含插图），插入 ${rewrittenParagraphs.length} 段AI生成内容',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // 关闭确认对话框

              // 保留插图：从选中索引中移除插图索引
              final nonIllustrationIndices = widget.selectedParagraphIndices
                  .where((index) => !illustrationIndices.contains(index))
                  .toList();

              if (nonIllustrationIndices.isEmpty) {
                // 如果全部都是插图，提示用户
                ToastUtils.showWarning('所有选中的段落都是插图，已取消操作');
                return;
              }

              // 只删除非插图段落
              _executeDeleteAndInsert(updatedParagraphs, nonIllustrationIndices,
                  rewrittenParagraphs);
            },
            child: const Text('保留插图并跳过'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext); // 关闭确认对话框

              // 删除所有选中段落（包含插图）
              _executeDeleteAndInsert(updatedParagraphs,
                  widget.selectedParagraphIndices, rewrittenParagraphs);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('删除插图并替换'),
          ),
        ],
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
      title: Row(
        children: [
          Icon(Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('改写结果'),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12)),
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
                Icon(Icons.info_outline,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '你可以选择替换原文、重新改写或关闭',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
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
