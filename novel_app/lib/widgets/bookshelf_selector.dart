import 'package:flutter/material.dart';
import '../models/bookshelf.dart';
import '../services/database_service.dart';

/// 书架选择器组件
///
/// 显示在BookshelfScreen顶部，用于切换和创建书架
class BookshelfSelector extends StatefulWidget {
  /// 当前选中的书架ID
  final int currentBookshelfId;

  /// 书架切换回调
  final ValueChanged<int> onBookshelfChanged;

  const BookshelfSelector({
    super.key,
    required this.currentBookshelfId,
    required this.onBookshelfChanged,
  });

  @override
  State<BookshelfSelector> createState() => _BookshelfSelectorState();
}

class _BookshelfSelectorState extends State<BookshelfSelector> {
  final DatabaseService _databaseService = DatabaseService();
  List<Bookshelf> _bookshelves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookshelves();
  }

  Future<void> _loadBookshelves() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookshelves = await _databaseService.getBookshelves();
      if (mounted) {
        setState(() {
          _bookshelves = bookshelves;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载书架列表失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCreateBookshelfDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.create_new_folder, color: Colors.blue),
            SizedBox(width: 8),
            Text('新建书架'),
          ],
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '书架名称',
            hintText: '请输入书架名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请输入书架名称'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _databaseService.createBookshelf(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('书架创建成功'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBookshelves(); // 重新加载书架列表
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('创建失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showBookshelfMenu(Bookshelf bookshelf) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.blue),
              title: Text(bookshelf.name),
              subtitle: Text(bookshelf.isSystem ? '系统书架' : '自定义书架'),
            ),
            const Divider(),
            if (!bookshelf.isSystem) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除书架'),
                onTap: () async {
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('确认删除'),
                      content: Text(
                        '确定要删除书架"${bookshelf.name}"吗？\n'
                        '书架内的小说不会被删除。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    final success = await _databaseService.deleteBookshelf(
                      bookshelf.id,
                    );
                    if (!mounted) return;

                    if (success) {
                      // 如果删除的是当前书架，切换到"全部小说"
                      if (widget.currentBookshelfId == bookshelf.id) {
                        widget.onBookshelfChanged(1);
                      }
                      _loadBookshelves();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('书架已删除')),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('删除失败'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('关闭'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final currentBookshelf = _bookshelves.firstWhere(
      (b) => b.id == widget.currentBookshelfId,
      orElse: () => _bookshelves.first,
    );

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            currentBookshelf.isSystem
                ? Icons.folder_shared
                : Icons.folder,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showBookshelfSelectionDialog(),
              child: Row(
                children: [
                  Text(
                    currentBookshelf.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建书架',
            onPressed: _showCreateBookshelfDialog,
          ),
        ],
      ),
    );
  }

  void _showBookshelfSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择书架'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _bookshelves.length,
            itemBuilder: (context, index) {
              final bookshelf = _bookshelves[index];
              final isSelected = bookshelf.id == widget.currentBookshelfId;

              return ListTile(
                leading: Icon(
                  bookshelf.isSystem
                      ? Icons.folder_shared
                      : Icons.folder,
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
                title: Text(
                  bookshelf.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue : null,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.blue)
                    : IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          Navigator.pop(context);
                          _showBookshelfMenu(bookshelf);
                        },
                      ),
                onTap: () {
                  Navigator.pop(context);
                  if (bookshelf.id != widget.currentBookshelfId) {
                    widget.onBookshelfChanged(bookshelf.id);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
