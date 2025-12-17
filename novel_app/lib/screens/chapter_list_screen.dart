import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';
import '../core/di/api_service_provider.dart';
import '../services/dify_service.dart';
import '../services/cache_manager.dart';
import '../screens/reader_screen.dart';
import '../screens/chapter_search_screen.dart';
import '../screens/character_management_screen.dart';

class ChapterListScreen extends StatefulWidget {
  final Novel novel;

  const ChapterListScreen({super.key, required this.novel});

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  final ApiServiceWrapper _api = ApiServiceProvider.instance;
  final DatabaseService _databaseService = DatabaseService();
  final DifyService _difyService = DifyService();
  final CacheManager _cacheManager = CacheManager();
  final ScrollController _scrollController = ScrollController();
  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _isInBookshelf = false;
  String _errorMessage = '';
  int _lastReadChapterIndex = 0;

  // 重排相关状态
  bool _isReorderingMode = false;

  // 生成章节相关的状态
  final ValueNotifier<bool> _isGeneratingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _generatedContentNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<String> _insertResultNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingInsertNotifier =
      ValueNotifier<bool>(false);
  String _currentGeneratingTitle = '';
  String _currentGeneratingContent = '';

  @override
  void initState() {
    super.initState();
    _initApi();
    _checkBookshelfStatus();
    _loadLastReadChapter();
  }

  Future<void> _initApi() async {
    // 对于本地创建的小说，不需要初始化API
    if (widget.novel.url.startsWith('custom://')) {
      _loadChapters();
      return;
    }

    try {
      await _api.init();
      _loadChapters();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化API失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // 移除 _api.dispose() 调用，避免关闭共享的Dio连接
    // _api.dispose(); // 已移除，ApiServiceWrapper是单例，不应由Screen关闭
    _insertResultNotifier.dispose();
    _isGeneratingInsertNotifier.dispose();
    _isGeneratingNotifier.dispose();
    _generatedContentNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadChapters({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 先尝试从缓存加载
      final cachedChapters =
          await _databaseService.getCachedNovelChapters(widget.novel.url);

      if (cachedChapters.isNotEmpty && !forceRefresh) {
        // 有缓存且不强制刷新时，直接显示缓存
        setState(() {
          _chapters = cachedChapters;
          _isLoading = false;
        });
        _scrollToLastReadChapter();
        return;
      }

      if (cachedChapters.isNotEmpty && forceRefresh) {
        // 有缓存但需要刷新时，先显示缓存，然后在后台更新
        setState(() {
          _chapters = cachedChapters;
          _isLoading = false;
        });
        _scrollToLastReadChapter();

        // 在后台更新章节列表
        await _refreshChaptersFromBackend();
      } else {
        // 没有缓存时，从后端获取
        await _refreshChaptersFromBackend();

        // 对于本地创建的小说，如果刷新后仍然没有章节，需要结束loading状态
        if (widget.novel.url.startsWith('custom://')) {
          setState(() {
            _chapters = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载章节列表失败: $e';
      });
    }
  }

  // 从后端刷新章节列表的独立方法
  Future<void> _refreshChaptersFromBackend() async {
    // 对于本地创建的小说，不需要从后端获取
    if (widget.novel.url.startsWith('custom://')) {
      return;
    }

    try {
      // 从后端获取最新章节列表
      final chapters = await _api.getChapters(widget.novel.url);

      if (chapters.isNotEmpty) {
        // 缓存章节列表
        await _databaseService.cacheNovelChapters(widget.novel.url, chapters);

        // 重新从数据库获取合并后的章节列表（包括用户插入的章节）
        final updatedChapters =
            await _databaseService.getCachedNovelChapters(widget.novel.url);

        setState(() {
          _chapters = updatedChapters;
          _isLoading = false;
        });
        _scrollToLastReadChapter();

        // 显示更新成功提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('章节列表已更新')),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '未能获取章节列表';
        });
      }
    } catch (e) {
      // 如果已经有缓存数据，不显示错误，只显示提示
      if (_chapters.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新章节列表失败: $e')),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载章节列表失败: $e';
        });
      }
    }
  }

  Future<void> _loadLastReadChapter() async {
    try {
      final lastReadIndex =
          await _databaseService.getLastReadChapter(widget.novel.url);
      setState(() {
        _lastReadChapterIndex = lastReadIndex;
      });
    } catch (e) {
      debugPrint('获取上次阅读章节失败: $e');
    }
  }

  void _scrollToLastReadChapter() {
    if (_lastReadChapterIndex > 0 && _chapters.isNotEmpty) {
      // 延迟执行滚动，确保ListView已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final targetIndex =
              _lastReadChapterIndex.clamp(0, _chapters.length - 1);

          // 使用简单的滚动方法，避免复杂计算导致的过头问题
          // 计算目标位置：让目标章节显示在可视区域的上方1/4处
          final itemHeight = 56.0; // ListTile默认高度
          final targetOffset = targetIndex * itemHeight;

          // 获取可视区域高度，让目标章节显示在上方1/4处
          final viewportHeight = _scrollController.position.viewportDimension;
          final adjustedOffset = (targetOffset - viewportHeight * 0.25)
              .clamp(0.0, _scrollController.position.maxScrollExtent);

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
    final isInBookshelf =
        await _databaseService.isInBookshelf(widget.novel.url);
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

  Future<void> _showClearCacheDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
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
  Future<void> _showInsertChapterDialog(int afterIndex, {
    String? prefillTitle,
    String? prefillContent,
  }) async {
    final titleController = TextEditingController(
      text: prefillTitle ?? '',
    );
    final userInputController = TextEditingController(
      text: prefillContent ?? '',
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_circle, color: Colors.blue),
            const SizedBox(width: 8),
            Text(_chapters.isEmpty ? '创建新章节' : '插入新章节'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chapters.isEmpty
                ? '将为小说"${widget.novel.title}"创建第一章'
                : '将在第${afterIndex + 1}章"${_chapters[afterIndex].title}"后插入新章节',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: '章节标题',
                hintText: _chapters.isEmpty
                  ? '例如：第一章 故事的开始'
                  : '例如：第十五章 意外的相遇',
                border: const OutlineInputBorder(),
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
            child: const Text('生成'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _generateNewChapter(afterIndex, result['title']!, result['content']!);
    }
  }

  // 生成新章节内容
  Future<void> _generateNewChapter(
      int afterIndex, String title, String userInput) async {
    // 保存当前生成的章节标题和用户输入内容
    _currentGeneratingTitle = title;
    _currentGeneratingContent = userInput;

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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingNotifier,
              builder: (context, isGenerating, child) {
                return TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _showInsertChapterDialog(afterIndex,
                            prefillTitle: _currentGeneratingTitle,
                            prefillContent: _currentGeneratingContent,
                          );
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中' : '重试'),
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
                              _insertGeneratedChapter(
                                  afterIndex, _currentGeneratingTitle, value);
                              Navigator.pop(dialogContext);
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('插入'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );

    // 开始生成内容
    await _callDifyToGenerateChapter(afterIndex, userInput);
  }

  // 调用Dify生成章节内容
  Future<void> _callDifyToGenerateChapter(
      int afterIndex, String userInput) async {
    _isGeneratingNotifier.value = true;
    _generatedContentNotifier.value = '';

    try {
      // 获取历史章节内容（最近5章）
      String historyChaptersContent = '';

      // 安全检查：确保_chapters不为空且索引有效
      if (_chapters.isNotEmpty && afterIndex >= 0 && afterIndex < _chapters.length) {
        int startIndex = (afterIndex - 4).clamp(0, _chapters.length - 1);
        for (int i = startIndex; i <= afterIndex; i++) {
          final content = await _databaseService.getCachedChapter(
            _chapters[i].url,
          );
          if (content != null && content.isNotEmpty) {
            historyChaptersContent +=
                '第${i + 1}章 ${_chapters[i].title}\n$content\n\n';
          }
        }
      } else if (_chapters.isEmpty) {
        // 如果是空列表（创建第一章），提供一些默认的上下文信息
        historyChaptersContent = '这是小说的开始，请创建引人入胜的第一章内容。\n';
        if (widget.novel.description?.isNotEmpty == true) {
          historyChaptersContent += '小说背景：${widget.novel.description}\n';
        }
        historyChaptersContent += '作者：${widget.novel.author}\n';
      }

      // 角色信息设置为空，不使用角色选择功能
      const String rolesInfo = '无特定角色出场';

      // 构建Dify请求参数（参考特写功能，但cmd为空，current_chapter_content为空）
      final inputs = {
        'user_input': userInput,
        'cmd': '', // 空的cmd参数
        'current_chapter_content': '', // 空的当前章节字段
        'history_chapters_content': historyChaptersContent,
        'background_setting': widget.novel.description ?? '',
        'ai_writer_setting': '', // 可以从设置中获取
        'next_chapter_overview': '',
        'roles': rolesInfo, // ✨ 新增角色信息
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
  Future<void> _insertGeneratedChapter(
      int afterIndex, String title, String content) async {
    try {
      // 统一使用insertUserChapter方法，空列表时插入到位置0
      final insertIndex = _chapters.isEmpty ? 0 : afterIndex + 1;
      debugPrint('AI生成章节：使用insertUserChapter插入到位置$insertIndex');
      await _databaseService.insertUserChapter(
        widget.novel.url,
        title,
        content,
        insertIndex,
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

  
  // 显示删除章节确认对话框
  Future<void> _showDeleteChapterDialog(Chapter chapter, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('删除章节'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除章节 "${chapter.title}" 吗？',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '此操作无法撤销，章节内容将被永久删除。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
              ),
            ),
            if (_chapters.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                '删除后章节列表将重新排序。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteChapter(chapter, index);
    }
  }

  // 删除章节的方法
  Future<void> _deleteChapter(Chapter chapter, int index) async {
    try {
      // 显示加载提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在删除章节...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 调用数据库删除方法
      await _databaseService.deleteUserChapter(chapter.url);

      // 重新加载章节列表
      await _loadChapters();

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('章节删除成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除章节失败: $e'),
            backgroundColor: Colors.red,
          ),
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
          // 重排模式切换按钮
          if (_isReorderingMode)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                setState(() {
                  _isReorderingMode = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已退出重排模式'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: '完成重排',
              style: IconButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.reorder),
              onPressed: _toggleReorderingMode,
              tooltip: '重排章节',
            ),
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChapterSearchScreen(novel: widget.novel),
                ),
              );
            },
            tooltip: '搜索章节内容',
          ),
          // 人物管理按钮
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CharacterManagementScreen(novel: widget.novel),
                ),
              );
            },
            tooltip: '人物管理',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'toggle_bookmark':
                  _toggleBookshelf();
                  break;
                case 'cache_all':
                  _enqueueCacheWholeNovel();
                  break;
                                case 'clear_cache':
                  _showClearCacheDialog();
                  break;
                case 'refresh':
                  _loadChapters(forceRefresh: true);
                  break;
              }
            },
            itemBuilder: (context) {
              final isCustomNovel = widget.novel.url.startsWith('custom://');
              return [
                PopupMenuItem(
                  value: 'toggle_bookmark',
                  child: Row(
                    children: [
                      Icon(_isInBookshelf
                          ? Icons.bookmark
                          : Icons.bookmark_border),
                      const SizedBox(width: 8),
                      Text(_isInBookshelf ? '移出书架' : '加入书架'),
                    ],
                  ),
                ),
                if (!isCustomNovel) const PopupMenuItem(
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
                if (!isCustomNovel) const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('刷新章节'),
                    ],
                  ),
                ),
              ];
            },
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
                        onPressed: () => _loadChapters(forceRefresh: true),
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
                      child: _chapters.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.menu_book,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '还没有章节',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.novel.url.startsWith('custom://')
                                        ? '点击下方按钮创建第一个章节'
                                        : '你可以从源网站获取章节，或创建自己的章节',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // 主按钮：AI生成章节（与插入章节逻辑一致）
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showInsertChapterDialog(0),
                                    icon: const Icon(Icons.auto_awesome),
                                    label: const Text('AI生成章节'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                  if (!widget.novel.url
                                      .startsWith('custom://')) ...[
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _loadChapters(forceRefresh: true),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('从源网站获取章节'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : _isReorderingMode
                              ? _buildReorderableChapterList()
                              : _buildNormalChapterList(),
                    ),
                  ],
                ),
    );
  }

  void _enqueueCacheWholeNovel() {
    // 将小说加入后台缓存队列
    _cacheManager.enqueueNovel(widget.novel.url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已开始后台缓存全书')),
      );
    }
  }

  
  
  // 构建正常的章节列表（支持长按进入重排模式）
  Widget _buildNormalChapterList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        final isLastRead = index == _lastReadChapterIndex;
        final isUserChapter = chapter.isUserInserted;

        return Container(
          decoration: BoxDecoration(
            // 为用户自创章节添加轻微的背景色区分
            color: isUserChapter
                ? Colors.blue.withValues(alpha: 0.05)
                : null,
            border: isUserChapter
                ? Border(left: BorderSide(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 3,
                  ))
                : null,
          ),
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    chapter.title,
                    style: TextStyle(
                      fontWeight: isLastRead
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isLastRead ? Colors.red : null,
                      fontStyle: isUserChapter
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
                // 为用户自创章节添加小标识
                if (isUserChapter)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '用户',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 删除章节按钮（仅用户自创章节显示）
                if (chapter.isUserInserted)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => _showDeleteChapterDialog(chapter, index),
                    tooltip: '删除此章节',
                  ),
                // 插入章节按钮
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.blue,
                  ),
                  onPressed: () =>
                      _showInsertChapterDialog(index),
                  tooltip: '在此章节后插入新章节',
                ),
                // 缓存状态图标
                FutureBuilder<bool>(
                  future: _databaseService
                      .isChapterCached(chapter.url),
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
            onLongPress: () {
              _toggleReorderingMode();
            },
          ),
        );
      },
    );
  }

  // 构建可重排的章节列表
  Widget _buildReorderableChapterList() {
    return ReorderableListView.builder(
      itemCount: _chapters.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        final isLastRead = index == _lastReadChapterIndex;
        final isUserChapter = chapter.isUserInserted;

        return Container(
          key: ValueKey(chapter.url),
          decoration: BoxDecoration(
            // 为用户自创章节添加轻微的背景色区分
            color: isUserChapter
                ? Colors.blue.withValues(alpha: 0.05)
                : Colors.orange.withValues(alpha: 0.05),
            border: isUserChapter
                ? Border(
                    left: BorderSide(
                      color: Colors.blue.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    right: BorderSide(
                      color: Colors.orange.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    top: BorderSide(
                      color: Colors.orange.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: Colors.orange.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  )
                : Border.all(
                    color: Colors.orange.withValues(alpha: 0.5),
                    width: 1,
                  ),
          ),
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: ListTile(
            leading: Icon(
              Icons.drag_handle,
              color: Colors.grey[600],
            ),
            title: Row(
              children: [
                // 显示章节序号
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    chapter.title,
                    style: TextStyle(
                      fontWeight: isLastRead
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isLastRead ? Colors.red : null,
                      fontStyle: isUserChapter
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
                // 为用户自创章节添加小标识
                if (isUserChapter)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '用户',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              // 重排模式下点击不跳转到阅读页面
            },
          ),
        );
      },
    );
  }

  // 切换重排模式
  void _toggleReorderingMode() {
    setState(() {
      _isReorderingMode = !_isReorderingMode;
    });

    if (_isReorderingMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已进入重排模式，拖拽章节调整顺序'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 处理章节重排
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final Chapter item = _chapters.removeAt(oldIndex);
      _chapters.insert(newIndex, item);
    });

    // 保存重排后的顺序到数据库
    await _saveReorderedChapters();
  }

  // 保存重排后的章节顺序
  Future<void> _saveReorderedChapters() async {
    try {
      // 显示保存进度提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在保存章节顺序...'),
          duration: Duration(seconds: 1),
        ),
      );

      // 批量更新章节索引
      await _databaseService.updateChaptersOrder(
        widget.novel.url,
        _chapters,
      );

      // 重新加载章节列表以确保数据一致性
      await _loadChapters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('章节顺序已保存'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存章节顺序失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
