import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag_group.dart';
import '../models/prompt_tag_category.dart';
import '../core/providers/database_providers.dart';

/// 标签选择面板（分组模式）
///
/// 横向 Scrollable Tab 切换分类 + 搜索 + 多选分组。
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
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                          fontSize: 13,
                          color: Colors.blue.shade700,
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

  /// 从当前选中 keys + 当前可见分组数据，构建返回结果
  List<TagGroup> _buildSelectedGroups() {
    // 需要从 _GroupedTagList 获取所有分组数据来匹配
    // 简化：直接从 selectedKeys 构造 TagGroup
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
}

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
          style: TextStyle(color: Colors.grey.shade600),
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
                  color: selected ? Colors.blue : Colors.grey,
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
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${group.count}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
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