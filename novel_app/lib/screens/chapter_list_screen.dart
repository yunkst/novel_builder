import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/novel_crawler_service.dart';
import '../services/database_service.dart';
import '../services/dify_service.dart';
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
  final DifyService _difyService = DifyService();
  final ScrollController _scrollController = ScrollController();
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _isInBookshelf = false;
  String _errorMessage = '';
  int _lastReadChapterIndex = 0;

  // 生成章节相关的状态
  final ValueNotifier<bool> _isGeneratingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _generatedContentNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> _insertResultNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingInsertNotifier = ValueNotifier<bool>(false);
  String _currentGeneratingTitle = '';

  @override
  void initState() {
    super.initState();
    _loadChapters();
    _checkBookshelfStatus();
    _loadLastReadChapter();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _crawlerService.dispose();
    _insertResultNotifier.dispose();
    _isGeneratingInsertNotifier.dispose();
    _isGeneratingNotifier.dispose();
    _generatedContentNotifier.dispose();
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
        _scrollToLastReadChapter();
      }

      // 从网络获取最新章节列表
      final chapters = await _crawlerService.getChapterList(widget.novel.url);

      if (chapters.isNotEmpty) {
        // 缓存章节列表
        await _databaseService.cacheNovelChapters(widget.novel.url, chapters);

        // 重新从数据库获取合并后的章节列表（包括用户插入的章节）
        final updatedChapters = await _databaseService.getCachedNovelChapters(widget.novel.url);

        setState(() {
          _chapters = updatedChapters;
          _isLoading = false;
        });
        _scrollToLastReadChapter();
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

  Future<void> _loadLastReadChapter() async {
    try {
      final lastReadIndex = await _databaseService.getLastReadChapter(widget.novel.url);
      setState(() {
        _lastReadChapterIndex = lastReadIndex;
      });
    } catch (e) {
      print('获取上次阅读章节失败: $e');
    }
  }

  void _scrollToLastReadChapter() {
    if (_lastReadChapterIndex > 0 && _chapters.isNotEmpty) {
      // 延迟执行滚动，确保ListView已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final targetIndex = _lastReadChapterIndex.clamp(0, _chapters.length - 1);
          
          // 使用简单的滚动方法，避免复杂计算导致的过头问题
          // 计算目标位置：让目标章节显示在可视区域的上方1/4处
          final itemHeight = 56.0; // ListTile默认高度
          final targetOffset = targetIndex * itemHeight;
          
          // 获取可视区域高度，让目标章节显示在上方1/4处
          final viewportHeight = _scrollController.position.viewportDimension;
          final adjustedOffset = (targetOffset - viewportHeight * 0.25).clamp(
            0.0, 
            _scrollController.position.maxScrollExtent
          );
          
          _scrollController.animateTo(
            adjustedOffset,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
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

  Future<void> _showClearCacheDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除该小说的所有缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearCache();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    try {
      await _databaseService.clearNovelCache(widget.novel.url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除缓存失败: $e')),
        );
      }
    }
  }

  // 显示插入章节的弹框
  Future<void> _showInsertChapterDialog(int afterIndex) async {
    final titleController = TextEditingController();
    final userInputController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_circle, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('插入新章节'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将在第${afterIndex + 1}章"${_chapters[afterIndex].title}"后插入新章节',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '章节标题',
                hintText: '例如：第十五章 意外的相遇',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: userInputController,
              decoration: const InputDecoration(
                labelText: '章节内容要求',
                hintText: '描述你想要的故事情节、人物对话、场景描述等...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            Text(
              '提示：AI将根据你的要求生成新的章节内容',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty && 
                  userInputController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'title': titleController.text.trim(),
                  'content': userInputController.text.trim(),
                });
              }
            },
            child: const Text('生成章节'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _generateNewChapter(afterIndex, result['title']!, result['content']!);
    }
  }

  // 生成新章节内容
  Future<void> _generateNewChapter(int afterIndex, String title, String userInput) async {
    // 保存当前生成的章节标题
    _currentGeneratingTitle = title;
    
    // 显示生成进度弹框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue),
              SizedBox(width: 8),
              Text('生成新章节'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    border: Border.all(color: Colors.grey[600]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _generatedContentNotifier,
                      builder: (context, value, child) {
                        return Text(
                          value.isEmpty ? '正在生成中...' : value,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '生成完成后，你可以选择插入或重新生成',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingNotifier,
              builder: (context, isGenerating, child) {
                return TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _generateNewChapter(afterIndex, _currentGeneratingTitle, userInput);
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中...' : '重新生成'),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingNotifier,
              builder: (context, isGenerating, child) {
                return ValueListenableBuilder<String>(
                  valueListenable: _generatedContentNotifier,
                  builder: (context, value, child) {
                    return ElevatedButton.icon(
                      onPressed: (isGenerating || value.isEmpty)
                          ? null
                          : () {
                              _insertGeneratedChapter(afterIndex, _currentGeneratingTitle, value);
                              Navigator.pop(dialogContext);
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('插入章节'),
                    );
                  },
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    // 开始生成内容
    await _callDifyToGenerateChapter(afterIndex, userInput);
  }

  // 调用Dify生成章节内容
  Future<void> _callDifyToGenerateChapter(int afterIndex, String userInput) async {
    _isGeneratingNotifier.value = true;
    _generatedContentNotifier.value = '';

    try {
      // 获取历史章节内容（最近5章）
      String historyChaptersContent = '';
      int startIndex = (afterIndex - 4).clamp(0, _chapters.length);
      for (int i = startIndex; i <= afterIndex; i++) {
        final content = await _databaseService.getCachedChapter(
          _chapters[i].url,
        );
        if (content != null && content.isNotEmpty) {
          historyChaptersContent += '第${i + 1}章 ${_chapters[i].title}\n$content\n\n';
        }
      }

      // 构建Dify请求参数（参考特写功能，但cmd为空，current_chapter_content为空）
      final inputs = {
        'user_input': userInput,
        'cmd': '', // 空的cmd参数
        'current_chapter_content': '', // 空的当前章节字段
        'history_chapters_content': historyChaptersContent,
        'background_setting': widget.novel.description ?? '',
        'ai_writer_setting': '', // 可以从设置中获取
        'next_chapter_overview': '',
        'characters_info': '',
      };

      // 调用Dify流式生成
      await _difyService.runWorkflowStreaming(
        inputs: inputs,
        onData: (data) {
          if (mounted) {
            _generatedContentNotifier.value += data;
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('生成失败: $error')),
            );
          }
        },
        onDone: () {
          _isGeneratingNotifier.value = false;
        },
      );
    } catch (e) {
      _isGeneratingNotifier.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    }
  }

  // 插入生成的章节
  Future<void> _insertGeneratedChapter(int afterIndex, String title, String content) async {
    try {
      // 使用新的数据库方法插入用户章节
      await _databaseService.insertUserChapter(
        widget.novel.url,
        title,
        content,
        afterIndex + 1,
      );

      // 重新加载章节列表
      await _loadChapters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('章节插入成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('插入章节失败: $e')),
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'toggle_bookmark':
                  _toggleBookshelf();
                  break;
                case 'cache_all':
                  _cacheAllChapters();
                  break;
                case 'clear_cache':
                  _showClearCacheDialog();
                  break;
                case 'refresh':
                  _loadChapters();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_bookmark',
                child: Row(
                  children: [
                    Icon(_isInBookshelf ? Icons.bookmark : Icons.bookmark_border),
                    const SizedBox(width: 8),
                    Text(_isInBookshelf ? '移出书架' : '加入书架'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cache_all',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('缓存全书'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('清除缓存'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('刷新章节'),
                  ],
                ),
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
                        controller: _scrollController,
                        itemCount: _chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = _chapters[index];
                          final isLastRead = index == _lastReadChapterIndex;
                          
                          return ListTile(
                            title: Text(
                              chapter.title,
                              style: TextStyle(
                                fontWeight: isLastRead ? FontWeight.bold : FontWeight.normal,
                                color: isLastRead ? Colors.red : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 插入章节按钮
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _showInsertChapterDialog(index),
                                  tooltip: '在此章节后插入新章节',
                                ),
                                // 缓存状态图标
                                FutureBuilder<bool>(
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
                              ],
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
