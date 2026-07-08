/// 提示词标签管理页
///
/// 职责：
/// - 分类（PromptTagCategory）的增删改
/// - 标签（PromptTag）的增删改、移动分类
/// - 同名标签按 TagGroup 聚合展示，点击展开查看各 prompt
/// - 宽屏双栏 / 窄屏上下自适应布局
///
/// 数据层：
/// - promptTagCategoryRepositoryProvider → 分类 CRUD
/// - promptTagRepositoryProvider → 标签 CRUD
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/prompt_tag.dart';
import '../../models/prompt_tag_category.dart';
import '../../models/tag_group.dart';
import '../../utils/toast_utils.dart';

// ============================================================
// 主页面
// ============================================================

class PromptTagManagementScreen extends ConsumerStatefulWidget {
  const PromptTagManagementScreen({super.key});

  @override
  ConsumerState<PromptTagManagementScreen> createState() =>
      _PromptTagManagementScreenState();
}

class _PromptTagManagementScreenState
    extends ConsumerState<PromptTagManagementScreen> {
  List<PromptTagCategory> _categories = [];
  int? _selectedCategoryId;
  List<TagGroup> _tagGroups = [];
  // 展开的 TagGroup name 集合
  final Set<String> _expandedGroupNames = {};
  // 展开后加载的 PromptTag 列表（按 groupName 索引）
  final Map<String, List<PromptTag>> _expandedTags = {};

  bool _isLoadingCategories = true;
  bool _isLoadingTags = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // ==================== 数据加载 ====================

  Future<void> _loadCategories() async {
    final repo = ref.read(promptTagCategoryRepositoryProvider);
    // 首次进入自动初始化默认分类
    await repo.initDefaultCategories();
    final categories = await repo.getAll();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
      // 自动选中第一个分类
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
    });
    if (_selectedCategoryId != null) {
      _loadTagGroups(_selectedCategoryId!);
    }
  }

  Future<void> _loadTagGroups(int categoryId) async {
    setState(() => _isLoadingTags = true);
    final repo = ref.read(promptTagRepositoryProvider);
    final groups = await repo.getGroupedByCategory(categoryId);
    if (!mounted) return;
    setState(() {
      _tagGroups = groups;
      _isLoadingTags = false;
      // 清理不存在的展开状态
      _expandedGroupNames
          .removeWhere((name) => !groups.any((g) => g.name == name));
      // 清理不存在的展开 tag 缓存
      _expandedTags
          .removeWhere((key, _) => !groups.any((g) => g.name == key));
    });
  }

  Future<void> _toggleGroupExpand(TagGroup group) async {
    if (_expandedGroupNames.contains(group.name)) {
      setState(() {
        _expandedGroupNames.remove(group.name);
      });
      return;
    }
    setState(() => _expandedGroupNames.add(group.name));
    // 加载该 group 下所有 tag
    if (!_expandedTags.containsKey(group.name)) {
      final repo = ref.read(promptTagRepositoryProvider);
      final tags = await repo.getByCategory(group.categoryId);
      final sameNameTags =
          tags.where((t) => t.name == group.name).toList();
      if (!mounted) return;
      setState(() {
        _expandedTags[group.name] = sameNameTags;
      });
    }
  }

  void _selectCategory(int? categoryId) {
    if (categoryId == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _expandedGroupNames.clear();
      _expandedTags.clear();
    });
    if (categoryId != null) {
      _loadTagGroups(categoryId);
    }
  }

  // ==================== 分类 CRUD ====================

  Future<void> _addCategory() async {
    final result = await showDialog<PromptTagCategory>(
      context: context,
      builder: (context) => const _CategoryEditDialog(),
    );
    if (result == null) return;
    final repo = ref.read(promptTagCategoryRepositoryProvider);
    await repo.save(result);
    if (mounted) {
      ToastUtils.showSuccess('分类已添加');
      await _loadCategories();
    }
  }

  Future<void> _editCategory(PromptTagCategory category) async {
    final result = await showDialog<PromptTagCategory>(
      context: context,
      builder: (context) => _CategoryEditDialog(category: category),
    );
    if (result == null) return;
    final repo = ref.read(promptTagCategoryRepositoryProvider);
    await repo.save(result);
    if (mounted) {
      ToastUtils.showSuccess('分类已更新');
      await _loadCategories();
    }
  }

  Future<void> _deleteCategory(PromptTagCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除分类「${category.name}」将同时删除该分类下所有标签，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || category.id == null) return;
    final tagRepo = ref.read(promptTagRepositoryProvider);
    final catRepo = ref.read(promptTagCategoryRepositoryProvider);
    await tagRepo.deleteByCategory(category.id!);
    await catRepo.delete(category.id!);
    if (mounted) {
      ToastUtils.showSuccess('分类已删除');
      if (_selectedCategoryId == category.id) {
        _selectedCategoryId = null;
      }
      await _loadCategories();
    }
  }

  // ==================== Tag CRUD ====================

  Future<void> _addTag() async {
    if (_selectedCategoryId == null) {
      ToastUtils.showInfo('请先选择分类');
      return;
    }
    final category =
        _categories.firstWhere((c) => c.id == _selectedCategoryId);
    final result = await showDialog<PromptTag>(
      context: context,
      builder: (context) => _TagEditDialog(
        categoryId: _selectedCategoryId!,
        categoryName: category.name,
        categories: _categories,
      ),
    );
    if (result == null) return;
    final repo = ref.read(promptTagRepositoryProvider);
    await repo.save(result);
    if (mounted) {
      ToastUtils.showSuccess('标签已添加');
      // 自动展开新 tag 所在的 group
      _expandedGroupNames.add(result.name);
      _loadTagGroups(_selectedCategoryId!);
    }
  }

  Future<void> _editTag(PromptTag tag) async {
    final category =
        _categories.firstWhere((c) => c.id == tag.categoryId);
    final result = await showDialog<PromptTag>(
      context: context,
      builder: (context) => _TagEditDialog(
        tag: tag,
        categoryId: tag.categoryId,
        categoryName: category.name,
        categories: _categories,
      ),
    );
    if (result == null) return;
    final repo = ref.read(promptTagRepositoryProvider);
    // 如果分类变了，需要移动
    if (result.categoryId != tag.categoryId) {
      await repo.save(result);
      await repo.moveToCategory(result.id!, result.categoryId);
    } else {
      await repo.save(result);
    }
    if (mounted) {
      ToastUtils.showSuccess('标签已更新');
      _loadTagGroups(_selectedCategoryId!);
      // 如果移动到了当前分类，刷新目标分类
      if (result.categoryId != tag.categoryId &&
          result.categoryId == _selectedCategoryId) {
        _loadTagGroups(_selectedCategoryId!);
      }
    }
  }

  Future<void> _deleteTag(PromptTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除标签「${tag.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || tag.id == null) return;
    final repo = ref.read(promptTagRepositoryProvider);
    await repo.delete(tag.id!);
    if (mounted) {
      ToastUtils.showSuccess('标签已删除');
      _loadTagGroups(_selectedCategoryId!);
    }
  }

  // ==================== 构建布局 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '提示词标签管理',
          style: AppTypography.chapterTitle.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: _addTag,
            icon: const Icon(Icons.add),
            tooltip: '添加标签',
          ),
        ],
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // 宽屏 ≥ 600 走双栏，窄屏走上下布局
                if (constraints.maxWidth >= 600) {
                  return _buildWideLayout();
                }
                return _buildNarrowLayout();
              },
            ),
    );
  }

  /// 窄屏布局：顶部 Tab 切分类 + 下方 tag 列表
  Widget _buildNarrowLayout() {
    return Column(
      children: [
        // 分类 Tab 栏
        _buildCategoryTabs(),
        const Divider(height: 1),
        // Tag 列表
        Expanded(child: _buildTagContent()),
      ],
    );
  }

  /// 宽屏布局：左侧分类列表 + 右侧 tag 列表
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧分类列表（固定宽度）
        SizedBox(
          width: 200,
          child: _buildCategoryList(),
        ),
        const VerticalDivider(width: 1),
        // 右侧 tag 列表
        Expanded(child: _buildTagContent()),
      ],
    );
  }

  // ==================== 分类 UI ====================

  /// 窄屏用：可横滑的 Tab 栏
  Widget _buildCategoryTabs() {
    if (_categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              '暂无分类',
              style: AppTypography.metaItalic.copyWith(
                color: context.appColors.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              onPressed: _addCategory,
              icon: const Icon(Icons.add, size: 18),
              tooltip: '添加分类',
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ..._categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat.name),
                  selected: cat.id == _selectedCategoryId,
                  onSelected: (_) => _selectCategory(cat.id),
                ),
              )),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _addCategory,
            icon: const Icon(Icons.add, size: 20),
            tooltip: '添加分类',
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  /// 宽屏用：左侧分类列表
  Widget _buildCategoryList() {
    return Column(
      children: [
        // 标题 + 添加按钮
        ListTile(
          dense: true,
          title: Text('分类',
              style: AppTypography.metaItalic.copyWith(
                color: context.appColors.inkSoft,
              )),
          trailing: IconButton(
            onPressed: _addCategory,
            icon: const Icon(Icons.add, size: 18),
            tooltip: '添加分类',
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _categories.isEmpty
              ? Center(
                  child: Text(
                    '暂无分类',
                    style: AppTypography.metaItalic.copyWith(
                      color: context.appColors.inkSoft,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat.id == _selectedCategoryId;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      leading: Icon(
                        Icons.folder_outlined,
                        size: 20,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(cat.name),
                      trailing: _buildCategoryPopupMenu(cat),
                      onTap: () => _selectCategory(cat.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryPopupMenu(PromptTagCategory category) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _editCategory(category);
            break;
          case 'delete':
            _deleteCategory(category);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('编辑')),
        const PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );
  }

  // ==================== Tag 内容区 ====================

  Widget _buildTagContent() {
    if (_selectedCategoryId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.label_outline,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              '请选择左侧分类',
              style: AppTypography.bodyProse.copyWith(
                fontSize: 15,
                color: context.appColors.inkSoft,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingTags) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tagGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.label_off_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              '该分类下暂无标签',
              style: AppTypography.bodyProse.copyWith(
                fontSize: 15,
                color: context.appColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 添加标签',
              style: AppTypography.metaItalic.copyWith(
                color: context.appColors.inkSoft,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _tagGroups.length,
      itemBuilder: (context, index) {
        final group = _tagGroups[index];
        return _buildTagGroupItem(group);
      },
    );
  }

  Widget _buildTagGroupItem(TagGroup group) {
    final isExpanded = _expandedGroupNames.contains(group.name);
    final expandedTags = _expandedTags[group.name] ?? [];

    return Column(
      children: [
        // Group 头部（可点击展开/收起）
        ListTile(
          leading: Icon(
            isExpanded ? Icons.label : Icons.label_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(group.name),
          subtitle: group.count > 1
              ? Text('${group.count} 条 prompt')
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (group.count > 1)
                IconButton(
                  icon: Icon(isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more),
                  onPressed: () => _toggleGroupExpand(group),
                  tooltip: isExpanded ? '收起' : '展开',
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) {
                  switch (value) {
                    case 'add_same_name':
                      // 同名新增 prompt
                      _addTagWithName(group.categoryId, group.name);
                      break;
                    case 'delete_all':
                      _deleteAllInGroup(group);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'add_same_name',
                      child: Text('添加同名标签')),
                  if (group.count > 1)
                    const PopupMenuItem(
                        value: 'delete_all',
                        child: Text('删除全部同名标签')),
                ],
              ),
            ],
          ),
          onTap: group.count > 1
              ? () => _toggleGroupExpand(group)
              : () => _editSingleTag(group),
        ),
        // 展开的 tag 列表
        if (isExpanded && expandedTags.isNotEmpty)
          ...expandedTags.map((tag) => _buildExpandedTagItem(tag)),
      ],
    );
  }

  /// 展开的单条 tag（缩进展示）
  Widget _buildExpandedTagItem(PromptTag tag) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.short_text, size: 16),
        title: Text(
          tag.promptText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyProse.copyWith(
            fontSize: 13,
            height: 1.5,
            color: context.appColors.ink,
          ),
        ),
        subtitle: tag.reason.isNotEmpty
            ? Text(
                tag.reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metaItalic.copyWith(
                  fontSize: 11,
                  color: context.appColors.inkSoft,
                ),
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 16),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editTag(tag);
                break;
              case 'delete':
                _deleteTag(tag);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () => _editTag(tag),
      ),
    );
  }

  /// 点击只有 1 条 tag 的 group 时，直接编辑该 tag
  Future<void> _editSingleTag(TagGroup group) async {
    final repo = ref.read(promptTagRepositoryProvider);
    final tags = await repo.getByCategory(group.categoryId);
    final tag = tags.firstWhere((t) => t.name == group.name);
    if (mounted) {
      _editTag(tag);
    }
  }

  /// 添加同名的 tag（预设 name 不可修改）
  Future<void> _addTagWithName(int categoryId, String name) async {
    final category =
        _categories.firstWhere((c) => c.id == categoryId);
    final result = await showDialog<PromptTag>(
      context: context,
      builder: (context) => _TagEditDialog(
        categoryId: categoryId,
        categoryName: category.name,
        categories: _categories,
        presetName: name,
      ),
    );
    if (result == null) return;
    final repo = ref.read(promptTagRepositoryProvider);
    await repo.save(result);
    if (mounted) {
      ToastUtils.showSuccess('标签已添加');
      _expandedGroupNames.add(result.name);
      _loadTagGroups(_selectedCategoryId!);
    }
  }

  /// 删除同名 group 下所有 tag
  Future<void> _deleteAllInGroup(TagGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除所有名为「${group.name}」的标签（${group.count} 条）吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(promptTagRepositoryProvider);
    final tags = await repo.getByCategory(group.categoryId);
    for (final tag in tags.where((t) => t.name == group.name)) {
      if (tag.id != null) {
        await repo.delete(tag.id!);
      }
    }
    if (mounted) {
      ToastUtils.showSuccess('已删除全部同名标签');
      _expandedGroupNames.remove(group.name);
      _expandedTags.remove(group.name);
      _loadTagGroups(_selectedCategoryId!);
    }
  }
}

// ============================================================
// 分类编辑对话框
// ============================================================

class _CategoryEditDialog extends StatefulWidget {
  final PromptTagCategory? category;

  const _CategoryEditDialog({this.category});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    return AlertDialog(
      title: Text(isEditing ? '编辑分类' : '添加分类'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '分类名称',
          hintText: '如：风格、场景、人物',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分类名称')),
      );
      return;
    }
    final now = DateTime.now();
    final category = PromptTagCategory(
      id: widget.category?.id,
      name: name,
      sortOrder: widget.category?.sortOrder ?? 0,
      createdAt: widget.category?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, category);
  }
}

// ============================================================
// Tag 编辑对话框
// ============================================================

class _TagEditDialog extends StatefulWidget {
  final PromptTag? tag;
  final int categoryId;
  final String categoryName;
  final List<PromptTagCategory> categories;
  final String? presetName;

  const _TagEditDialog({
    this.tag,
    required this.categoryId,
    required this.categoryName,
    required this.categories,
    this.presetName,
  });

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _reasonController;
  late final TextEditingController _promptTextController;
  late int _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.presetName ?? widget.tag?.name ?? '',
    );
    _reasonController = TextEditingController(
      text: widget.tag?.reason ?? '',
    );
    _promptTextController = TextEditingController(
      text: widget.tag?.promptText ?? '',
    );
    _selectedCategoryId = widget.tag?.categoryId ?? widget.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _promptTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tag != null;
    final hasPresetName = widget.presetName != null;

    return AlertDialog(
      title: Text(isEditing ? '编辑标签' : '添加标签'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 分类选择
            DropdownButtonFormField<int>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: '所属分类',
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id != null) {
                  setState(() => _selectedCategoryId = id);
                }
              },
            ),
            const SizedBox(height: 12),
            // 标签名称
            TextField(
              controller: _nameController,
              readOnly: hasPresetName,
              decoration: InputDecoration(
                labelText: '标签名称',
                hintText: '如：赛博朋克、暗黑',
                border: const OutlineInputBorder(),
                filled: hasPresetName,
                fillColor: hasPresetName
                    ? context.appColors.divider.withValues(alpha: 0.3)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            // 使用场景
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '使用场景',
                hintText: '简述何时该用这个标签（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Prompt 文本
            TextField(
              controller: _promptTextController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Prompt 文本',
                hintText: '输入该标签对应的 prompt 内容',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
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
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final reason = _reasonController.text.trim();
    final promptText = _promptTextController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标签名称')),
      );
      return;
    }
    if (promptText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Prompt 文本')),
      );
      return;
    }

    final now = DateTime.now();
    final tag = PromptTag(
      id: widget.tag?.id,
      categoryId: _selectedCategoryId,
      name: name,
      reason: reason,
      promptText: promptText,
      sortOrder: widget.tag?.sortOrder ?? 0,
      createdAt: widget.tag?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, tag);
  }
}
