import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/database_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../models/prompt_tag.dart';
import '../../models/prompt_tag_category.dart';
import '../../services/logger_service.dart';
import '../../utils/toast_utils.dart';

/// AI 写作技巧标签提取 Sheet
///
/// 流程：输入想法 -> 调用 Dify(cmd='提取标签',阻塞式) -> 解析 tags[] -> 展示可勾选可编辑列表 -> 确认保存到 PromptTag
class AIPromptTagExtractSheet extends ConsumerStatefulWidget {
  final String chapterContent;

  const AIPromptTagExtractSheet({super.key, required this.chapterContent});

  @override
  ConsumerState<AIPromptTagExtractSheet> createState() =>
      _AIPromptTagExtractSheetState();
}

class _AIPromptTagExtractSheetState
    extends ConsumerState<AIPromptTagExtractSheet> {
  final TextEditingController _inputController = TextEditingController();

  bool _isExtracting = false;
  List<_ExtractedTag> _extracted = [];
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    for (final t in _extracted) {
      t.dispose();
    }
    super.dispose();
  }

  // ============ 核心逻辑 ============

  Future<void> _extract() async {
    final userInput = _inputController.text.trim();
    if (userInput.isEmpty) {
      ToastUtils.showWarning('请输入提取想法', context: context);
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      // 加载所有类别，格式化为字符串
      final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
      final categories = await categoryRepo.getAll();
      final tagCategoriesStr = categories.map((c) => c.name).join('、');

      // 调用 Service 层提取标签
      final difyService = ref.read(difyServiceProvider);
      final extractedTags = await difyService.extractPromptTags(
        userInput: userInput,
        chapterContent: widget.chapterContent,
        tagCategories: tagCategoriesStr,
      );

      if (extractedTags.isEmpty) {
        setState(() {
          _isExtracting = false;
          _errorMessage = '未提取到任何标签，请调整输入后重试';
        });
        return;
      }

      // 转换为 UI 层数据结构（默认全选）
      final uiTags = extractedTags
          .map((t) => _ExtractedTag(
                tag: t.tag,
                type: t.type,
                promptText: t.promptText,
              ))
          .toList();

      setState(() {
        _isExtracting = false;
        _extracted = uiTags;
      });
    } catch (e, st) {
      LoggerService.instance.e(
        'AI 标签提取失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['ai', 'tag-extract', 'error'],
      );
      setState(() {
        _isExtracting = false;
        _errorMessage = '提取失败: $e';
      });
    }
  }

  Future<void> _saveAll() async {
    final selected = _extracted.where((t) => t.selected).toList();
    if (selected.isEmpty) {
      ToastUtils.showWarning('请至少选择一个标签', context: context);
      return;
    }

    try {
      final tagRepo = ref.read(promptTagRepositoryProvider);
      final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);

      final categories = await categoryRepo.getAll();
      final categoryIdByName = <String, int>{
        for (final c in categories)
          if (c.id != null) c.name: c.id!,
      };
      final now = DateTime.now();

      int saved = 0;
      int skipped = 0;
      for (final t in selected) {
        final name = t.tagController.text.trim();
        final prompt = t.promptController.text.trim();
        final type = t.typeController.text.trim();
        if (name.isEmpty || prompt.isEmpty) {
          skipped++;
          continue;
        }

        final categoryId = await _ensureCategory(
          categoryRepo,
          categoryIdByName,
          type,
          now,
        );
        if (categoryId == null) {
          skipped++;
          continue;
        }

        // 查重：categoryId + name + promptText 完全一致则跳过
        final existing = await tagRepo.search(name, categoryId: categoryId);
        if (existing.any((e) => e.name == name && e.promptText == prompt)) {
          skipped++;
          continue;
        }

        await tagRepo.save(PromptTag(
          categoryId: categoryId,
          name: name,
          promptText: prompt,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ));
        saved++;
      }

      if (!mounted) return;
      if (saved > 0) {
        ToastUtils.showSuccess(
          '已保存 $saved 个标签${skipped > 0 ? "，跳过 $skipped 个" : ""}',
          context: context,
        );
        Navigator.of(context).pop(saved);
      } else {
        ToastUtils.showError(
          '没有可保存的标签（已跳过 $skipped 个）',
          context: context,
        );
      }
    } catch (e, st) {
      LoggerService.instance.e(
        '保存标签失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['ai', 'tag-extract', 'save-error'],
      );
      if (!mounted) return;
      ToastUtils.showError('保存失败: $e', context: context);
    }
  }

  /// 确保类别存在，返回 categoryId；空类型返回 null
  Future<int?> _ensureCategory(
    dynamic categoryRepo,
    Map<String, int> categoryIdByName,
    String type,
    DateTime now,
  ) async {
    if (type.isEmpty) return null;
    final existing = categoryIdByName[type];
    if (existing != null) return existing;

    final newId = await categoryRepo.save(PromptTagCategory(
      name: type,
      sortOrder: categoryIdByName.length,
      createdAt: now,
      updatedAt: now,
    ));
    categoryIdByName[type] = newId;
    return newId;
  }

  // ============ UI ============

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                  _buildInputSection(),
                  const SizedBox(height: 16),
                  if (_isExtracting) _buildLoadingState(),
                  if (_errorMessage != null) _buildErrorState(),
                  if (_extracted.isNotEmpty) _buildResultList(),
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
          const Icon(Icons.auto_awesome, size: 20),
          const SizedBox(width: 8),
          const Text(
            'AI 提取写作技巧标签',
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

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '输入你想提取的标签想法',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _inputController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '例如：紧张的对峙场景、动作描写技巧、人物心理活动...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _isExtracting ? null : _extract,
          icon: const Icon(Icons.bolt, size: 18),
          label: const Text('提取标签'),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('正在调用 Dify 提取标签...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.errorContainer),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.appColors.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: context.appColors.onErrorContainer, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              '提取结果（可勾选、编辑后保存）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '已选 ${_extracted.where((t) => t.selected).length}/${_extracted.length}',
              style: TextStyle(fontSize: 12, color: context.appColors.onInfoContainer),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _extracted.length; i++) ...[
          _ExtractedTagCard(
            index: i,
            tag: _extracted[i],
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
        ],
      ],
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
                onPressed: _extracted.isNotEmpty && !_isExtracting ? _saveAll : null,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('确认保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ 内部数据 ============

/// 一个待保存的标签（Controllers 即数据源）
class _ExtractedTag {
  bool selected;
  final TextEditingController tagController;
  final TextEditingController typeController;
  final TextEditingController promptController;

  _ExtractedTag({
    required String tag,
    required String type,
    required String promptText,
  })  : tagController = TextEditingController(text: tag),
        typeController = TextEditingController(text: type),
        promptController = TextEditingController(text: promptText),
        // 标签默认全部选中，用户可在 UI 上取消勾选
        selected = true;

  void dispose() {
    tagController.dispose();
    typeController.dispose();
    promptController.dispose();
  }
}

class _ExtractedTagCard extends StatelessWidget {
  final int index;
  final _ExtractedTag tag;
  final VoidCallback onChanged;

  const _ExtractedTagCard({
    required this.index,
    required this.tag,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tag.selected
            ? context.appColors.infoContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tag.selected
              ? context.appColors.onInfoContainer.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: tag.selected,
                onChanged: (v) {
                  tag.selected = v ?? false;
                  onChanged();
                },
              ),
              Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          _field(context, '类型', tag.typeController),
          const SizedBox(height: 6),
          _field(context, '标签', tag.tagController),
          const SizedBox(height: 6),
          _field(context, '提示词', tag.promptController, minLines: 2, maxLines: 4),
        ],
      ),
    );
  }

  Widget _field(
    BuildContext context,
    String label,
    TextEditingController controller, {
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
