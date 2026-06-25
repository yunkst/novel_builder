import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prompt_tag.dart';
import '../models/prompt_tag_category.dart';
import '../core/providers/database_providers.dart';
import '../core/theme/app_colors.dart';

/// 标签管理页面
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
  List<PromptTag> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    await categoryRepo.initDefaultCategories();
    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    final categories = await categoryRepo.getAll();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading = false;
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
        _loadTags();
      }
    });
  }

  Future<void> _loadTags() async {
    if (_selectedCategoryId == null) {
      setState(() => _tags = []);
      return;
    }
    final tagRepo = ref.read(promptTagRepositoryProvider);
    final tags = await tagRepo.getByCategory(_selectedCategoryId!);
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  Future<void> _addCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _CategoryEditDialog(),
    );
    if (result == null || result.trim().isEmpty) return;
    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    final now = DateTime.now();
    final newCategory = PromptTagCategory(
      name: result.trim(),
      sortOrder: _categories.length,
      createdAt: now,
      updatedAt: now,
    );
    final id = await categoryRepo.save(newCategory);
    if (!mounted) return;
    setState(() {
      _selectedCategoryId = id;
    });
    await _loadCategories();
    await _loadTags();
  }

  Future<void> _renameCategory(PromptTagCategory category) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CategoryEditDialog(initial: category.name),
    );
    if (result == null || result.trim().isEmpty) return;
    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    await categoryRepo.save(category.copyWith(
      name: result.trim(),
      updatedAt: DateTime.now(),
    ));
    await _loadCategories();
  }

  Future<void> _deleteCategory(PromptTagCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确认删除分类"${category.name}"吗？\n此分类下的所有标签也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final tagRepo = ref.read(promptTagRepositoryProvider);
    final categoryRepo = ref.read(promptTagCategoryRepositoryProvider);
    await tagRepo.deleteByCategory(category.id!);
    await categoryRepo.delete(category.id!);
    if (!mounted) return;
    setState(() => _selectedCategoryId = null);
    await _loadCategories();
    await _loadTags();
  }

  Future<void> _addTag() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择或创建分类')),
      );
      return;
    }
    final result = await showDialog<_TagEditResult>(
      context: context,
      builder: (context) => const _TagEditDialog(),
    );
    if (result == null) return;
    final tagRepo = ref.read(promptTagRepositoryProvider);
    final now = DateTime.now();
    final tag = PromptTag(
      categoryId: _selectedCategoryId!,
      name: result.name,
      reason: result.reason,
      promptText: result.prompt,
      sortOrder: _tags.length,
      createdAt: now,
      updatedAt: now,
    );
    await tagRepo.save(tag);
    await _loadTags();
  }

  Future<void> _editTag(PromptTag tag) async {
    final result = await showDialog<_TagEditResult>(
      context: context,
      builder: (context) => _TagEditDialog(
        initialName: tag.name,
        initialReason: tag.reason,
        initialPrompt: tag.promptText,
      ),
    );
    if (result == null) return;
    final tagRepo = ref.read(promptTagRepositoryProvider);
    await tagRepo.save(tag.copyWith(
      name: result.name,
      reason: result.reason,
      promptText: result.prompt,
      updatedAt: DateTime.now(),
    ));
    await _loadTags();
  }

  Future<void> _deleteTag(PromptTag tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确认删除标签"${tag.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final tagRepo = ref.read(promptTagRepositoryProvider);
    await tagRepo.delete(tag.id!);
    await _loadTags();
  }

  Future<void> _moveTagToCategory(PromptTag tag) async {
    // 过滤出可用的目标分类（排除当前分类）
    final availableCategories = _categories
        .where((c) => c.id != tag.categoryId)
        .toList();
    if (availableCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有其他可用的分类，请先创建分类')),
      );
      return;
    }
    final selectedCategoryId = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('移动 "${tag.name}" 到'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableCategories.length,
            itemBuilder: (context, index) {
              final cat = availableCategories[index];
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(cat.name),
                onTap: () => Navigator.pop(context, cat.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (selectedCategoryId == null) return;
    // 校验分类是否仍然存在
    final targetExists = _categories.any((c) => c.id == selectedCategoryId);
    if (!targetExists) return;
    final tagRepo = ref.read(promptTagRepositoryProvider);
    await tagRepo.moveToCategory(tag.id!, selectedCategoryId);
    if (!mounted) return;
    // 刷新当前列表（若目标分类是当前选中分类，标签会出现在末尾；否则从当前列表消失）
    await _loadTags();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已将标签"${tag.name}"移动到目标分类')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 分类栏
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              final isSelected = cat.id == _selectedCategoryId;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: GestureDetector(
                                  onLongPress: () => _showCategoryMenu(cat),
                                  child: ChoiceChip(
                                    label: Text(cat.name),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setState(() =>
                                          _selectedCategoryId = cat.id);
                                      _loadTags();
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: '新建分类',
                          onPressed: _addCategory,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // 标签列表
                Expanded(
                  child: _tags.isEmpty
                      ? Center(
                          child: Text(
                            _selectedCategoryId == null
                                ? '请先创建分类'
                                : '此分类下暂无标签，点击右下角"+"新建',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _tags.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tag = _tags[index];
                            return ListTile(
                              title: Row(
                                children: [
                                  Text(
                                    tag.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  if (tag.reason.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tag.reason,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                tag.promptText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _editTag(tag);
                                  if (v == 'delete') _deleteTag(tag);
                                  if (v == 'move') _moveTagToCategory(tag);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('编辑')),
                                  PopupMenuItem(
                                      value: 'move', child: Text('移动到分类')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('删除')),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _addTag,
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showCategoryMenu(PromptTagCategory cat) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('重命名'),
            onTap: () {
              Navigator.pop(context);
              _renameCategory(cat);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: context.appColors.error),
            title: Text('删除', style: TextStyle(color: context.appColors.error)),
            onTap: () {
              Navigator.pop(context);
              _deleteCategory(cat);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryEditDialog extends StatefulWidget {
  final String initial;
  const _CategoryEditDialog({this.initial = ''});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? '新建分类' : '重命名分类'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '分类名称',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _TagEditResult {
  final String name;
  final String reason;
  final String prompt;
  _TagEditResult(this.name, this.reason, this.prompt);
}

class _TagEditDialog extends StatefulWidget {
  final String initialName;
  final String initialReason;
  final String initialPrompt;
  const _TagEditDialog({
    this.initialName = '',
    this.initialReason = '',
    this.initialPrompt = '',
  });

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _reasonController;
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _reasonController = TextEditingController(text: widget.initialReason);
    _promptController = TextEditingController(text: widget.initialPrompt);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.initialName.isEmpty ? '新建标签' : '编辑标签'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '标签名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '使用场景',
                hintText: '简短一句话，说明何时该用这个标签',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '提示词内容',
                hintText: '拼接在用户输入前的提示词',
                border: OutlineInputBorder(),
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
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _TagEditResult(
                _nameController.text.trim(),
                _reasonController.text.trim(),
                _promptController.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
