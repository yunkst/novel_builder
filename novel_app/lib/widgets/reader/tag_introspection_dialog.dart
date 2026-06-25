import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/tag_introspection.dart';
import '../../models/prompt_tag.dart';
import '../../models/prompt_tag_category.dart';
import '../../repositories/prompt_tag_history_repository.dart';
import '../../core/providers/database_providers.dart';
import '../../utils/toast_utils.dart';

/// 用户编辑后的 problem 数据
///
/// AI 建议值可被用户修改，_applyChanges 使用此结构中的值。
class _EditedProblem {
  final TagIntrospectionProblem original;

  /// 用户编辑后的 suggestedReason（reason_adjust 时）
  String editedSuggestedReason;

  /// 用户编辑后的 suggestedPrompt（prompt_clarify / missing_tag 时）
  String editedSuggestedPrompt;

  /// 用户编辑后的 suggestedTag（missing_tag 时）
  String editedSuggestedTag;

  /// 用户编辑后的 suggestedNewReason（missing_tag 时）
  String editedSuggestedNewReason;

  /// 用户编辑后的 suggestedCategory（missing_tag 时）
  String editedSuggestedCategory;

  _EditedProblem.fromProblem(this.original)
      : editedSuggestedReason = original.suggestedReason ?? '',
        editedSuggestedPrompt = original.suggestedPrompt ?? '',
        editedSuggestedTag = original.suggestedTag ?? '',
        editedSuggestedNewReason = original.suggestedNewReason ?? '',
        editedSuggestedCategory = original.suggestedCategory ?? '';
}

/// 标签自省结果展示 Dialog
///
/// 逐条展示 AI 分析出的问题，用户可确认/编辑/跳过，
/// 确认后自动更新 tag 库并记录修改历史。
class TagIntrospectionDialog extends ConsumerStatefulWidget {
  final List<TagIntrospectionProblem> problems;
  final String novelUrl;
  final VoidCallback? onApplied;

  const TagIntrospectionDialog({
    super.key,
    required this.problems,
    required this.novelUrl,
    this.onApplied,
  });

  @override
  ConsumerState<TagIntrospectionDialog> createState() =>
      _TagIntrospectionDialogState();
}

class _TagIntrospectionDialogState
    extends ConsumerState<TagIntrospectionDialog> {
  /// 每条问题的确认状态
  late List<bool> _confirmed;

  /// 每条问题的编辑后数据
  late List<_EditedProblem> _edited;

  @override
  void initState() {
    super.initState();
    _confirmed = List.filled(widget.problems.length, true); // 默认全选
    _edited = widget.problems.map(_EditedProblem.fromProblem).toList();
  }

  Future<void> _applyChanges() async {
    final tagRepo = ref.read(promptTagRepositoryProvider);
    final historyRepo = ref.read(promptTagHistoryRepositoryProvider);
    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    final now = DateTime.now();
    int applied = 0;

    for (int i = 0; i < widget.problems.length; i++) {
      if (!_confirmed[i]) continue;
      final edited = _edited[i];
      final problem = edited.original;

      try {
        switch (problem.type) {
          case 'reason_adjust':
            if (problem.tagName != null &&
                edited.editedSuggestedReason.isNotEmpty) {
              // 查找 tag 并更新 reason
              final tags = await tagRepo.search(problem.tagName!);
              for (final tag in tags) {
                await tagRepo.save(tag.copyWith(
                  reason: edited.editedSuggestedReason,
                  updatedAt: now,
                ));
                await historyRepo.insert(PromptTagHistoryEntry(
                  tagId: tag.id ?? 0,
                  novelUrl: widget.novelUrl,
                  changeType: 'reason_adjust',
                  oldValue: tag.reason,
                  newValue: edited.editedSuggestedReason,
                  reason: problem.analysis,
                  createdAt: now,
                ));
              }
              applied++;
            }
            break;

          case 'prompt_clarify':
            if (problem.tagName != null &&
                edited.editedSuggestedPrompt.isNotEmpty) {
              final tags = await tagRepo.search(problem.tagName!);
              for (final tag in tags) {
                await tagRepo.save(tag.copyWith(
                  promptText: edited.editedSuggestedPrompt,
                  updatedAt: now,
                ));
                await historyRepo.insert(PromptTagHistoryEntry(
                  tagId: tag.id ?? 0,
                  novelUrl: widget.novelUrl,
                  changeType: 'prompt_clarify',
                  oldValue: tag.promptText,
                  newValue: edited.editedSuggestedPrompt,
                  reason: problem.analysis,
                  createdAt: now,
                ));
              }
              applied++;
            }
            break;

          case 'missing_tag':
            if (edited.editedSuggestedTag.isNotEmpty &&
                edited.editedSuggestedPrompt.isNotEmpty) {
              // 确保分类存在
              int categoryId;
              final categoryName = edited.editedSuggestedCategory.isEmpty
                  ? '风格'
                  : edited.editedSuggestedCategory;
              final categories = await categoryRepo.getAll();
              final existing =
                  categories.where((c) => c.name == categoryName).toList();
              if (existing.isNotEmpty) {
                categoryId = existing.first.id!;
              } else {
                categoryId = await categoryRepo.save(PromptTagCategory(
                  name: categoryName,
                  sortOrder: categories.length,
                  createdAt: now,
                  updatedAt: now,
                ));
              }

              final newTagId = await tagRepo.save(PromptTag(
                categoryId: categoryId,
                name: edited.editedSuggestedTag,
                reason: edited.editedSuggestedNewReason,
                promptText: edited.editedSuggestedPrompt,
                createdAt: now,
                updatedAt: now,
              ));

              await historyRepo.insert(PromptTagHistoryEntry(
                tagId: newTagId,
                novelUrl: widget.novelUrl,
                changeType: 'created',
                newValue:
                    '${edited.editedSuggestedTag}: ${edited.editedSuggestedPrompt}',
                reason: problem.analysis,
                createdAt: now,
              ));
              applied++;
            }
            break;
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError('应用修改失败: $e', context: context);
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
      if (applied > 0) {
        ToastUtils.showSuccess('已应用 $applied 条修改', context: context);
        widget.onApplied?.call();
      } else {
        ToastUtils.showWarning('没有可应用的修改', context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.psychology, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('AI 诊断结果'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.problems.length,
          itemBuilder: (context, index) {
            return _ProblemCard(
              edited: _edited[index],
              confirmed: _confirmed[index],
              onConfirmChanged: (v) {
                setState(() => _confirmed[index] = v);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton.icon(
          onPressed: _applyChanges,
          icon: const Icon(Icons.check, size: 18),
          label: Text('应用修改 (${_confirmed.where((c) => c).length})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appColors.success,
            foregroundColor: context.appColors.onSemantic,
          ),
        ),
      ],
    );
  }
}

/// 单条问题卡片（支持编辑建议值）
class _ProblemCard extends StatefulWidget {
  final _EditedProblem edited;
  final bool confirmed;
  final ValueChanged<bool> onConfirmChanged;

  const _ProblemCard({
    required this.edited,
    required this.confirmed,
    required this.onConfirmChanged,
  });

  @override
  State<_ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<_ProblemCard> {
  late TextEditingController _suggestedReasonController;
  late TextEditingController _suggestedPromptController;
  late TextEditingController _suggestedTagController;
  late TextEditingController _suggestedNewReasonController;
  late TextEditingController _suggestedCategoryController;

  @override
  void initState() {
    super.initState();
    final e = widget.edited;
    _suggestedReasonController =
        TextEditingController(text: e.editedSuggestedReason);
    _suggestedPromptController =
        TextEditingController(text: e.editedSuggestedPrompt);
    _suggestedTagController =
        TextEditingController(text: e.editedSuggestedTag);
    _suggestedNewReasonController =
        TextEditingController(text: e.editedSuggestedNewReason);
    _suggestedCategoryController =
        TextEditingController(text: e.editedSuggestedCategory);
  }

  @override
  void dispose() {
    _suggestedReasonController.dispose();
    _suggestedPromptController.dispose();
    _suggestedTagController.dispose();
    _suggestedNewReasonController.dispose();
    _suggestedCategoryController.dispose();
    super.dispose();
  }

  Color _typeColor() {
    switch (widget.edited.original.type) {
      case 'reason_adjust':
        return Colors.orange;
      case 'prompt_clarify':
        return Colors.blue;
      case 'missing_tag':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor();
    final problem = widget.edited.original;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：Checkbox + 类型标签 + 标签名
            Row(
              children: [
                Checkbox(
                  value: widget.confirmed,
                  onChanged: (v) => widget.onConfirmChanged(v ?? false),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    problem.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (problem.isMissingTag)
                  Expanded(
                    child: _buildEditableField(
                      controller: _suggestedTagController,
                      hint: '新标签名',
                      onChanged: (v) => widget.edited.editedSuggestedTag = v,
                    ),
                  )
                else if (problem.tagName != null)
                  Expanded(
                    child: Text(
                      problem.tagName!,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 分析理由
            Text(
              problem.analysis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // 可编辑的建议值
            if (problem.isReasonAdjust) ...[
              _buildEditableChangeRow(
                context: context,
                label: '使用场景',
                currentValue: problem.currentReason,
                controller: _suggestedReasonController,
                onChanged: (v) => widget.edited.editedSuggestedReason = v,
              ),
            ],
            if (problem.isPromptClarify) ...[
              _buildEditableChangeRow(
                context: context,
                label: '提示词',
                currentValue: problem.currentPrompt,
                controller: _suggestedPromptController,
                onChanged: (v) => widget.edited.editedSuggestedPrompt = v,
              ),
            ],
            if (problem.isMissingTag) ...[
              _buildEditableSuggestRow(
                context: context,
                label: '使用场景',
                controller: _suggestedNewReasonController,
                onChanged: (v) => widget.edited.editedSuggestedNewReason = v,
              ),
              _buildEditableSuggestRow(
                context: context,
                label: '提示词',
                controller: _suggestedPromptController,
                onChanged: (v) => widget.edited.editedSuggestedPrompt = v,
              ),
              _buildEditableSuggestRow(
                context: context,
                label: '分类',
                controller: _suggestedCategoryController,
                onChanged: (v) => widget.edited.editedSuggestedCategory = v,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 可编辑的"当前 → 建议"对比行
  Widget _buildEditableChangeRow({
    required BuildContext context,
    required String label,
    required String? currentValue,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        if (currentValue != null && currentValue.isNotEmpty)
          Text('当前: $currentValue',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough)),
        const SizedBox(height: 4),
        _buildEditableField(
          controller: controller,
          hint: '修改后的$label',
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 可编辑的纯建议行（missing_tag 用）
  Widget _buildEditableSuggestRow({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _buildEditableField(
          controller: controller,
          hint: label,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 通用可编辑输入框
  Widget _buildEditableField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.check, size: 16),
          tooltip: '确认修改',
          onPressed: () {
            onChanged(controller.text);
            setState(() {}); // 刷新 UI
          },
        ),
      ),
      style: const TextStyle(fontSize: 12),
      onSubmitted: (v) {
        onChanged(v);
        setState(() {});
      },
    );
  }
}
