import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../services/database_service.dart';
import 'chapter_list_screen.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Novel> _bookshelf = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
  }

  Future<void> _loadBookshelf() async {
    setState(() {
      _isLoading = true;
    });

    final novels = await _databaseService.getBookshelf();

    setState(() {
      _bookshelf = novels;
      _isLoading = false;
    });
  }

  Future<void> _removeFromBookshelf(Novel novel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要从书架移除《${novel.title}》吗？'),
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

    if (confirmed == true) {
      await _databaseService.removeFromBookshelf(novel.url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从书架移除')),
        );
      }
      _loadBookshelf();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookshelf.isEmpty
              ? const Center(
                  child: Text('书架是空的，快去搜索添加小说吧'),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookshelf,
                  child: ListView.builder(
                    itemCount: _bookshelf.length,
                    itemBuilder: (context, index) {
                      final novel = _bookshelf[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: novel.coverUrl != null
                                ? Image.network(
                                    novel.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.book);
                                    },
                                  )
                                : const Icon(Icons.book),
                          ),
                          title: Text(
                            novel.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('作者: ${novel.author}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _removeFromBookshelf(novel);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('从书架移除'),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChapterListScreen(novel: novel),
                              ),
                            ).then((_) => _loadBookshelf());
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
