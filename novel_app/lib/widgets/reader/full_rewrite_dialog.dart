import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../models/tag_group.dart';
import '../../models/character.dart';
import '../../mixins/dify_streaming_mixin.dart';
import '../../services/logger_service.dart';
import '../../services/preferences_service.dart';
import '../../services/prompt_tag_service.dart';
import '../../widgets/streaming_status_indicator.dart';
import '../../widgets/streaming_content_display.dart';
import '../../widgets/prompt_tag_selector_sheet.dart';
import '../../widgets/selected_tags_view.dart';
import '../../widgets/reader/tag_introspection_entry_sheet.dart';
import '../../core/providers/reader_screen_providers.dart';
import '../../core/providers/database_providers.dart';
import '../../core/theme/app_colors.dart';

/// 全文重写对话框
///
/// 职责：
/// - 提供全文重写功能的完整 UI
/// - 支持用户输入重写要求
/// - 支持标签选择（手动 + P1 智能匹配）
/// - 使用 DifyStreamingMixin 进行流式生成
/// - 支持替换全文、重新生成功能
class FullRewriteDialog extends ConsumerStatefulWidget {
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
  ConsumerState<FullRewriteDialog> createState() => _FullRewriteDialogState();
}

class _FullRewriteDialogState extends ConsumerState<FullRewriteDialog>
    with DifyStreamingMixin {
  final ValueNotifier<String> _rewriteResultNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingNotifier = ValueNotifier<bool>(false);
  String _lastUserInput = '';

  // 标签选择状态
  List<TagGroup> _selectedTagGroups = [];

  // 最近一次生成使用的 tag 详情（供自省用）
  List<UsedTagDetail> _lastUsedTags = [];

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
    final result = await showDialog<_FullRewriteInputResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FullRewriteInputDialog(
        controller: userInputController,
        selectedTagGroups: _selectedTagGroups,
        onOpenTagSelector: () async {
          final groups = await showModalBottomSheet<List<TagGroup>>(
            context: dialogContext,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: PromptTagSelectorSheet(
                initialSelectedGroups: _selectedTagGroups,
              ),
            ),
          );
          return groups;
        },
      ),
    );

    if (result != null) {
      _lastUserInput = result.text;
      _selectedTagGroups = result.selectedGroups;

      // 合并标签 prompt 到用户输入
      final tagService = PromptTagService.byRef(ref);
      final mergedResult =
          await tagService.buildMergedUserInput(result.text, _selectedTagGroups);
      _lastUsedTags = mergedResult.usedTags;
      _generateFullRewrite(mergedResult.mergedInput);
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
      // 使用 Provider 获取 NovelContextBuilder
      final contextBuilder = ref.read(novelContextBuilderProvider);

      // 使用 NovelContextBuilder 统一获取上下文数据
      final context = await contextBuilder.buildContext(
        widget.novel,
        widget.chapters,
        widget.currentChapter,
        widget.content,
      );

      // 获取作家设定（与 paragraph_rewrite_dialog 对齐）
      final aiWriterSetting =
          await PreferencesService.instance.getString('ai_writer_prompt');

      // 获取角色信息（替换原来的硬编码缺失）
      final characterRepo = ref.read(characterRepositoryProvider);
      final characters =
          await characterRepo.getCharacters(widget.novel.url);
      final roles = Character.formatForAI(characters);

      // 构建全文重写的参数（包含作家设定和角色信息）
      final inputs = context.buildFullRewriteInputs(
        userInput,
        aiWriterSetting: aiWriterSetting,
        roles: roles,
      );

      // 显示结果弹窗
      _showResultDialog();

      // 使用统一的流式方法
      await callDifyStreaming(
        inputs: inputs,
        onChunk: (chunk) {
          _rewriteResultNotifier.value += chunk; // Mixin已自动处理特殊标记
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
    } catch (e, stackTrace) {
      _isGeneratingNotifier.value = false;
      _rewriteResultNotifier.value = '生成失败: $e';
      LoggerService.instance.e(
        '全文重写生成异常: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['rewrite', 'full', 'error'],
      );
    }
  }

  // 打开标签自省 Sheet
  Future<void> _showTagIntrospection() async {
    final result = _rewriteResultNotifier.value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: TagIntrospectionEntrySheet(
          usedTags: _lastUsedTags,
          generatedContent: result,
          novelUrl: widget.novel.url,
        ),
      ),
    );
  }

  // 显示重写结果弹窗
  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_stories, color: context.appColors.success),
              const SizedBox(width: 8),
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
                    Icon(Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '你可以选择替换全文、重新生成或关闭',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
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
                  label:
                      Text(isGenerating ? '生成中...' : '重新生成'),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingNotifier,
              builder: (ctx, isGenerating, child) {
                return ValueListenableBuilder<String>(
                  valueListenable: _rewriteResultNotifier,
                  builder: (ctx, value, child) {
                    return ElevatedButton.icon(
                      onPressed: (isGenerating || value.isEmpty)
                          ? null
                          : () async {
                              // 先关闭结果dialog
                              Navigator.pop(dialogContext);

                              // 执行异步操作
                              await widget.onContentReplace(value);

                              // async后使用State的context（已检查mounted）
                              if (mounted) {
                                Navigator.pop(context); // 关闭主Dialog
                              }
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('替换全文'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appColors.success,
                        foregroundColor: context.appColors.onSemantic,
                      ),
                    );
                  },
                );
              },
            ),
            // 标签自省入口：对生成结果不满意时触发 AI 诊断
            Builder(builder: (ctx) {
              return TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showTagIntrospection();
                },
                icon: const Icon(Icons.psychology, size: 18),
                label: const Text('需要改进'),
              );
            }),
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

// ============================================================================
// 全文重写输入对话框（含标签选择）
// ============================================================================

/// 全文重写输入结果
class _FullRewriteInputResult {
  final String text;
  final List<TagGroup> selectedGroups;

  const _FullRewriteInputResult({
    required this.text,
    required this.selectedGroups,
  });
}

/// 全文重写输入对话框
///
/// 包含重写要求输入 + 标签选择入口，参照 ParagraphRewriteDialog 的 _RewriteInputDialog
class _FullRewriteInputDialog extends StatefulWidget {
  final TextEditingController controller;
  final List<TagGroup> selectedTagGroups;
  final Future<List<TagGroup>?> Function() onOpenTagSelector;

  const _FullRewriteInputDialog({
    required this.controller,
    required this.selectedTagGroups,
    required this.onOpenTagSelector,
  });

  @override
  State<_FullRewriteInputDialog> createState() =>
      _FullRewriteInputDialogState();
}

class _FullRewriteInputDialogState extends State<_FullRewriteInputDialog> {
  List<TagGroup> _currentSelectedGroups = [];

  @override
  void initState() {
    super.initState();
    _currentSelectedGroups = List.from(widget.selectedTagGroups);
  }

  Future<void> _openTagSelector() async {
    final groups = await widget.onOpenTagSelector();
    if (groups != null && mounted) {
      setState(() {
        _currentSelectedGroups = groups;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_stories, color: context.appColors.success),
          const SizedBox(width: 8),
          const Text('全文重写'),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              labelText: '重写要求',
              hintText: '例如：改变写作风格、增加细节描写、调整情节节奏等...',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标签选择按钮
                  IconButton(
                    icon: const Icon(Icons.label_outline, size: 20),
                    tooltip: '选择标签',
                    onPressed: _openTagSelector,
                  ),
                ],
              ),
            ),
            autofocus: true,
            maxLines: 4,
          ),
          // 已选标签展示
          if (_currentSelectedGroups.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectedTagsView(
              groups: _currentSelectedGroups,
              onRemove: (group) {
                setState(() {
                  _currentSelectedGroups = _currentSelectedGroups
                      .where((g) =>
                          !(g.categoryId == group.categoryId &&
                              g.name == group.name))
                      .toList();
                });
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '提示：AI将根据你的要求重新创作整章内容',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            Navigator.pop(
              context,
              _FullRewriteInputResult(
                text: widget.controller.text,
                selectedGroups: _currentSelectedGroups,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appColors.success,
            foregroundColor: context.appColors.onSemantic,
          ),
          child: const Text('开始重写'),
        ),
      ],
    );
  }
}
