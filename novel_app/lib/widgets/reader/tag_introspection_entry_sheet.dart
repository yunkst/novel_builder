import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../services/logger_service.dart';
import '../../services/prompt_tag_service.dart';
import '../../core/providers/service_providers.dart';
import '../../utils/toast_utils.dart';
import 'tag_introspection_dialog.dart';

/// 标签自省入口 Sheet
///
/// 流程：输入改进要求 → 调用 AI 自省分析 → 展示分析结果 → 应用修改
class TagIntrospectionEntrySheet extends ConsumerStatefulWidget {
  /// 本次生成实际使用的 tag 详情
  final List<UsedTagDetail> usedTags;

  /// AI 生成的内容
  final String generatedContent;

  /// 关联的小说 URL（用于历史记录）
  final String novelUrl;

  /// 应用修改后的回调（可选，用于触发重新生成）
  final VoidCallback? onApplied;

  const TagIntrospectionEntrySheet({
    super.key,
    required this.usedTags,
    required this.generatedContent,
    required this.novelUrl,
    this.onApplied,
  });

  @override
  ConsumerState<TagIntrospectionEntrySheet> createState() =>
      _TagIntrospectionEntrySheetState();
}

class _TagIntrospectionEntrySheetState
    extends ConsumerState<TagIntrospectionEntrySheet> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final feedback = _feedbackController.text.trim();
    if (feedback.isEmpty) {
      ToastUtils.showWarning('请描述需要改进的地方', context: context);
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final difyService = ref.read(difyServiceProvider);

      // 格式化使用的标签展示文本
      final usedTagsText = widget.usedTags.isEmpty
          ? '（本次未使用任何标签）'
          : widget.usedTags.map((t) => t.toDisplayString()).join('\n\n');

      final problems = await difyService.introspectPromptTags(
        usedTags: usedTagsText,
        generatedContent: widget.generatedContent,
        userFeedback: feedback,
      );

      if (problems.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = '未分析出可改进的标签问题';
        });
        return;
      }

      // 关闭输入 sheet，展示分析结果
      if (mounted) {
        Navigator.pop(context);
        await showDialog<void>(
          context: context,
          builder: (_) => TagIntrospectionDialog(
            problems: problems,
            novelUrl: widget.novelUrl,
            onApplied: widget.onApplied,
          ),
        );
      }
    } catch (e, st) {
      LoggerService.instance.e(
        '标签自省失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['tag', 'introspection', 'error'],
      );
      setState(() {
        _isAnalyzing = false;
        _errorMessage = '分析失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildUsedTagsInfo(),
                    const SizedBox(height: 16),
                    _buildFeedbackInput(),
                    const SizedBox(height: 12),
                    if (_errorMessage != null) _buildErrorState(),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(Icons.psychology, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text(
            '标签自省 - 改进分析',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUsedTagsInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label_outline,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                '本次使用的标签 (${widget.usedTags.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.usedTags.isEmpty
                ? '本次未使用标签'
                : widget.usedTags.map((t) => t.name).join('、'),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '描述本次生成存在的问题',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _feedbackController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '例如：节奏太慢、对话不够干脆、打斗缺乏画面感、心理描写不足...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AI 会分析：标签的使用场景(reason)是否准确、提示词(promptText)是否清晰、是否需要补充新标签',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: context.appColors.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                  color: context.appColors.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isAnalyzing ? null : _analyze,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high, size: 18),
                label: Text(_isAnalyzing ? '分析中...' : 'AI 诊断'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
