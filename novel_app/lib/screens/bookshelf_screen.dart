import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../services/database_service.dart';
import '../services/preload_service.dart';
import '../services/preload_progress_update.dart';
import '../widgets/bookshelf_selector.dart';
import 'chapter_list_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:async';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final PreloadService _preloadService = PreloadService();
  List<Novel> _bookshelf = [];
  bool _isLoading = true;
  final Map<String, Map<String, int>> _progress = {}; // novelUrl -> stats

  // 当前选中的书架ID
  int _currentBookshelfId = 1; // 默认显示"全部小说"

  // 预加载监听
  StreamSubscription<PreloadProgressUpdate>? _preloadSubscription;

  @override
  void initState() {
    super.initState();
    _loadBookshelf();

    // 监听预加载进度
    _preloadSubscription = _preloadService.progressStream.listen((update) {
      if (mounted) {
        setState(() {
          _progress[update.novelUrl] = {
            'cachedChapters': update.cachedChapters,
            'totalChapters': update.totalChapters,
          };
        });
      }
    });
  }

  Future<void> _loadBookshelf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (kIsWeb) {
        // 在Web环境中，模拟一些测试数据
        final mockNovels = [
          Novel(
            title: '测试小说1',
            author: '测试作者1',
            url: 'https://example.com/novel1',
            coverUrl: '',
            description: '这是一个测试小说描述',
          ),
          Novel(
            title: '测试小说2',
            author: '测试作者2',
            url: 'https://example.com/novel2',
            coverUrl: '',
            description: '这是另一个测试小说描述',
          ),
        ];

        setState(() {
          _bookshelf = mockNovels;
          _isLoading = false;
        });
      } else {
        // 使用多书架查询方法
        final novels = await _databaseService.getNovelsByBookshelf(
          _currentBookshelfId,
        );
        setState(() {
          _bookshelf = novels;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载书架失败: $e');
      setState(() {
        _bookshelf = [];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _preloadSubscription?.cancel();
    super.dispose();
  }

  /// 判断小说是否正在预加载
  bool _isPreloading(String novelUrl) {
    final stats = _preloadService.getStatistics();
    return stats['is_processing'] == true &&
        stats['last_active_novel'] == novelUrl;
  }

  /// 书架切换回调
  void _onBookshelfChanged(int bookshelfId) {
    setState(() {
      _currentBookshelfId = bookshelfId;
    });
    _loadBookshelf();
  }

  Future<void> _removeFromBookshelf(Novel novel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
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

  // 显示创建空小说对话框
  Future<void> _showCreateNovelDialog() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.create, color: Colors.blue),
            SizedBox(width: 8),
            Text('创建新小说'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('创建一本属于你自己的小说，可以自由添加章节'),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '小说标题',
                hintText: '请输入小说标题',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: '作者',
                hintText: '请输入作者名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '简介 (可选)',
                hintText: '请输入小说简介',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final author = authorController.text.trim();

              if (title.isEmpty || author.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请填写小说标题和作者'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final Map<String, String> resultData = {
                'title': title,
                'author': author,
                'description': descriptionController.text.trim(),
              };

              // 使用微任务确保 Navigator 调用时机正确
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  Navigator.pop(context, resultData);
                }
              });
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
        await _databaseService.createCustomNovel(
          result['title']!,
          result['author']!,
          description: result['description'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('小说创建成功！'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadBookshelf(); // 重新加载书架
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 书架选择器
          BookshelfSelector(
            currentBookshelfId: _currentBookshelfId,
            onBookshelfChanged: _onBookshelfChanged,
          ),
          // 书架内容
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bookshelf.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.library_books,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '书架是空的',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('你可以去搜索添加小说，或点击右下角按钮创建自己的小说'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showCreateNovelDialog,
                              icon: const Icon(Icons.create),
                              label: const Text('创建新小说'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBookshelf,
                        child: ListView.builder(
                          itemCount: _bookshelf.length,
                          itemBuilder: (context, index) {
                            final novel = _bookshelf[index];
                            final stats = _progress[novel.url];
                            // 注意：不再批量统计缓存状态，避免性能问题
                            // 进度条UI将依赖预加载服务的实时更新（如果有）
                            final cached =
                                stats != null ? (stats['cachedChapters'] ?? 0) : 0;
                            final total =
                                stats != null ? (stats['totalChapters'] ?? 0) : 0;
                            final double percent =
                                (total > 0) ? (cached / total).clamp(0.0, 1.0) : 0.0;
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                title: Row(
                                  children: [
                                    if (_isPreloading(novel.url))
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.blue),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        novel.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '作者: ${novel.author}',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (novel.url.startsWith('custom://')) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: Colors.purple
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              '原创',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.purple[700],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (total > 0) ...[
                                      LinearProgressIndicator(value: percent),
                                      const SizedBox(height: 4),
                                      Text(
                                        '已缓存章节: $cached / $total',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _removeFromBookshelf(novel);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('从书架移除'),
                                        ],
                                      ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'bookshelf_fab',
        onPressed: _showCreateNovelDialog,
        tooltip: '创建新小说',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
    );
  }
}
