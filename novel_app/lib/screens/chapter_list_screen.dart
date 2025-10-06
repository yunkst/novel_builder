import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/novel_crawler_service.dart';
import '../services/database_service.dart';
import 'reader_screen.dart';

class ChapterListScreen extends StatefulWidget {
  final Novel novel;

  const ChapterListScreen({super.key, required this.novel});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  final NovelCrawlerService _crawlerService = NovelCrawlerService();
  final DatabaseService _databaseService = DatabaseService();
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _isInBookshelf = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadChapters();
    _checkBookshelfStatus();
  }

  @override
  void dispose() {
    _crawlerService.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 先尝试从缓存加载
      final cachedChapters = await _databaseService.getCachedNovelChapters(widget.novel.url);

      if (cachedChapters.isNotEmpty) {
        setState(() {
          _chapters = cachedChapters;
          _isLoading = false;
        });
      }

      // 从网络获取最新章节列表
      final chapters = await _crawlerService.getChapterList(widget.novel.url);

      if (chapters.isNotEmpty) {
        // 缓存章节列表
        await _databaseService.cacheNovelChapters(widget.novel.url, chapters);

        setState(() {
          _chapters = chapters;
          _isLoading = false;
        });
      } else if (cachedChapters.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '未能获取章节列表';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载章节列表失败: $e';
      });
    }
  }

  Future<void> _checkBookshelfStatus() async {
    final isInBookshelf = await _databaseService.isInBookshelf(widget.novel.url);
    setState(() {
      _isInBookshelf = isInBookshelf;
    });
  }

  Future<void> _toggleBookshelf() async {
    if (_isInBookshelf) {
      await _databaseService.removeFromBookshelf(widget.novel.url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从书架移除')),
        );
      }
    } else {
      await _databaseService.addToBookshelf(widget.novel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到书架')),
        );
      }
    }
    await _checkBookshelfStatus();
  }

  Future<void> _cacheAllChapters() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('缓存小说'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在缓存 ${_chapters.length} 章节...'),
          ],
        ),
      ),
    );

    try {
      for (var i = 0; i < _chapters.length; i++) {
        final chapter = _chapters[i];
        final content = await _crawlerService.getChapterContent(chapter.url);
        await _databaseService.cacheChapter(widget.novel.url, chapter, content);

        // 每10章更新一次进度
        if (i % 10 == 0) {
          // 可以在这里更新进度提示
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('全书缓存完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('缓存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isInBookshelf ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleBookshelf,
            tooltip: _isInBookshelf ? '从书架移除' : '添加到书架',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'cache_all') {
                _cacheAllChapters();
              } else if (value == 'refresh') {
                _loadChapters();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cache_all',
                child: Text('缓存全书'),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Text('刷新章节'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChapters,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.novel.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('作者: ${widget.novel.author}'),
                          const SizedBox(height: 4),
                          Text('共 ${_chapters.length} 章'),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = _chapters[index];
                          return ListTile(
                            title: Text(chapter.title),
                            trailing: FutureBuilder<bool>(
                              future: _databaseService.isChapterCached(chapter.url),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) {
                                  return const Icon(
                                    Icons.download_done,
                                    color: Colors.green,
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReaderScreen(
                                    novel: widget.novel,
                                    chapter: chapter,
                                    chapters: _chapters,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
