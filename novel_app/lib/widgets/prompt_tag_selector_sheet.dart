import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag_group.dart';
import '../models/prompt_tag_category.dart';
import '../core/providers/database_providers.dart';
import '../core/providers/service_providers.dart';
import '../core/theme/app_colors.dart';
import '../utils/toast_utils.dart';

/// 标签选择面板（分组模式）
///
/// 横向 Scrollable Tab 切换分类 + 搜索 + 智能匹配 + 多选分组。
/// 同名标签聚合展示（name × count），选中后以 TagGroup 形式返回。
/// 返回 `List<TagGroup>`（选中的分组），null 表示取消。
class PromptTagSelectorSheet extends ConsumerStatefulWidget {
  final List<TagGroup> initialSelectedGroups;

  const PromptTagSelectorSheet({
    super.key,
    this.initialSelectedGroups = const [],
  });

  @override
  ConsumerState<PromptTagSelectorSheet> createState() =>
      _PromptTagSelectorSheetState();
}

class _PromptTagSelectorSheetState
    extends ConsumerState<PromptTagSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<String> _selectedKeys; // key = "categoryId:name"
  String _keyword = '';
  int? _currentCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedKeys = widget.initialSelectedGroups
        .map((g) => '${g.categoryId}:${g.name}')
        .toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _groupKey(TagGroup g) => '${g.categoryId}:${g.name}';

  @override
  Widget build(BuildContext context) {
    final categoryRepo = ref.watch(promptTagCategoryRepositoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 拖拽指示条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.neutral,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题行
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.label, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '选择标签',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_selectedKeys.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '已选 ${_selectedKeys.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appColors.onInfoContainer,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 智能匹配按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showSmartMatchDialog,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('智能匹配'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: '搜索标签名或提示词内容...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _keyword = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _keyword = v),
              ),
            ),
            const SizedBox(height: 8),
            // 分类 Tab
            FutureBuilder<List<PromptTagCategory>>(
              future: categoryRepo.getAll(),
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];
                if (_currentCategoryId == null && categories.isNotEmpty) {
                  _currentCategoryId = categories.first.id;
                }
                return SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat.id == _currentCategoryId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _currentCategoryId = cat.id);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: _GroupedTagList(
                categoryId: _currentCategoryId,
                keyword: _keyword,
                scrollController: scrollController,
                selectedKeys: _selectedKeys,
                onToggle: (group) {
                  setState(() {
                    final key = _groupKey(group);
                    if (_selectedKeys.contains(key)) {
                      _selectedKeys.remove(key);
                    } else {
                      _selectedKeys.add(key);
                    }
                  });
                },
              ),
            ),
            // 底部操作栏
            SafeArea(
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
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _buildSelectedGroups()),
                        child: const Text('确认选择'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 从当前选中 keys 构建返回结果
  List<TagGroup> _buildSelectedGroups() {
    return _selectedKeys.map((key) {
      final parts = key.split(':');
      final catId = int.parse(parts[0]);
      final name = parts.sublist(1).join(':');
      return TagGroup(
        categoryId: catId,
        name: name,
        count: 0,
        representativeId: 0,
      );
    }).toList();
  }

  /// 弹出智能匹配对话框
  Future<void> _showSmartMatchDialog() async {
    final sceneController = TextEditingController();
    final result = await showDialog<_SmartMatchResult>(
      context: context,
      builder: (ctx) => _SmartMatchDialog(controller: sceneController),
    );
    if (result == null || !mounted) return;

    // 执行智能匹配
    try {
      final difyService = ref.read(difyServiceProvider);

      // 准备可用标签列表（含 reason + category_id）
      final tagRepo = ref.read(promptTagRepositoryProvider);
      final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
      final allTags = await tagRepo.getAll();
      final categories = await categoryRepo.getAll();
      final categoryMap = <int, String>{};
      for (final cat in categories) {
        if (cat.id != null) categoryMap[cat.id!] = cat.name;
      }

      // 格式化标签列表，过滤掉 reason 为空的（无法判断适用性）
      final availableTagsBuffer = StringBuffer();
      for (final tag in allTags) {
        if (tag.reason.isEmpty) continue; // 无 reason 的标签跳过
        availableTagsBuffer.writeln('【${tag.name}】');
        availableTagsBuffer.writeln('场景：${tag.reason}');
        availableTagsBuffer.writeln('category_id: ${tag.categoryId}');
        availableTagsBuffer.writeln();
      }

      if (availableTagsBuffer.isEmpty) {
        if (mounted) {
          ToastUtils.showWarning('没有可用的标签（需要标签包含使用场景描述）',
              context: context);
        }
        return;
      }

      final matchResults = await difyService.matchPromptTags(
        sceneDescription: result.sceneDescription,
        availableTags: availableTagsBuffer.toString(),
      );

      if (matchResults.isEmpty) {
        if (mounted) {
          ToastUtils.showInfo('未找到匹配的标签', context: context);
        }
        return;
      }

      // 将匹配结果转为 TagGroup 并自动勾选
      if (!mounted) return;
      final tagGroupRepo = ref.read(promptTagRepositoryProvider);
      final newSelectedKeys = <String>{};
      final matchMessages = <String>[];

      for (final match in matchResults) {
        // 查找匹配的 tag 来获取完整信息
        final tags = await tagGroupRepo.search(match.name);
        if (tags.isEmpty) continue;
        final tag = tags.first;
        final key = '${tag.categoryId}:${tag.name}';
        newSelectedKeys.add(key);
        matchMessages.add('• ${match.name}：${match.matchReason}');
      }

      setState(() {
        _selectedKeys.addAll(newSelectedKeys);
      });

      if (mounted) {
        ToastUtils.showSuccess(
          '智能匹配推荐了 ${matchResults.length} 个标签',
          context: context,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('智能匹配失败: $e', context: context);
      }
    }
  }
}

/// 智能匹配对话框结果
class _SmartMatchResult {
  final String sceneDescription;
  _SmartMatchResult(this.sceneDescription);
}

/// 智能匹配输入对话框
class _SmartMatchDialog extends StatefulWidget {
  final TextEditingController controller;
  const _SmartMatchDialog({required this.controller});

  @override
  State<_SmartMatchDialog> createState() => _SmartMatchDialogState();
}

class _SmartMatchDialogState extends State<_SmartMatchDialog> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_fix_high, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('智能匹配'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '描述当前创作场景，AI 会根据标签的使用场景自动推荐合适的标签。',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '例如：两人在山洞中对峙后爆发激烈冲突...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final text = widget.controller.text.trim();
            if (text.isEmpty) {
              ToastUtils.showWarning('请输入场景描述', context: context);
              return;
            }
            Navigator.pop(context, _SmartMatchResult(text));
          },
          icon: const Icon(Icons.search, size: 18),
          label: const Text('匹配'),
        ),
      ],
    );
  }
}

/// 分组标签列表
class _GroupedTagList extends ConsumerStatefulWidget {
  const _GroupedTagList({
    required this.categoryId,
    required this.keyword,
    required this.scrollController,
    required this.selectedKeys,
    required this.onToggle,
  });

  final int? categoryId;
  final String keyword;
  final ScrollController scrollController;
  final Set<String> selectedKeys;
  final ValueChanged<TagGroup> onToggle;

  @override
  ConsumerState<_GroupedTagList> createState() => _GroupedTagListState();
}

class _GroupedTagListState extends ConsumerState<_GroupedTagList> {
  List<TagGroup> _groups = [];

  Future<void> _loadGroups() async {
    final tagRepo = ref.read(promptTagRepositoryProvider);
    if (widget.keyword.isEmpty && widget.categoryId != null) {
      _groups = await tagRepo.getGroupedByCategory(widget.categoryId!);
    } else if (widget.keyword.isNotEmpty) {
      // 搜索模式：获取所有匹配标签后手动分组
      final tags = await tagRepo.search(widget.keyword);
      final groupMap = <String, TagGroup>{};
      for (final tag in tags) {
        final key = '${tag.categoryId}:${tag.name}';
        if (!groupMap.containsKey(key)) {
          groupMap[key] = TagGroup(
            categoryId: tag.categoryId,
            name: tag.name,
            count: 1,
            representativeId: tag.id ?? 0,
          );
        } else {
          // increment count (approximate for search)
          groupMap[key] = TagGroup(
            categoryId: tag.categoryId,
            name: tag.name,
            count: groupMap[key]!.count + 1,
            representativeId: groupMap[key]!.representativeId,
          );
        }
      }
      _groups = groupMap.values.toList();
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void didUpdateWidget(covariant _GroupedTagList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId ||
        oldWidget.keyword != widget.keyword) {
      _loadGroups();
    }
  }

  String _groupKey(TagGroup g) => '${g.categoryId}:${g.name}';

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) {
      return Center(
        child: Text(
          widget.categoryId == null
              ? '暂无标签，请先在管理页面创建'
              : (widget.keyword.isEmpty ? '此分类下暂无标签' : '未找到匹配项'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final group = _groups[index];
        final selected = widget.selectedKeys.contains(_groupKey(group));
        return InkWell(
          onTap: () => widget.onToggle(group),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: selected
                      ? context.appColors.info
                      : Theme.of(context).colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (group.count > 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.appColors.infoContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${group.count}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appColors.onInfoContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
