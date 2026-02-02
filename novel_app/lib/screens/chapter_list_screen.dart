import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/ai_accompaniment_settings.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../core/di/api_service_provider.dart';
import '../services/dify_service.dart';
import '../services/preload_service.dart';
import '../services/preload_progress_update.dart';
import 'reader_screen.dart';
import 'chapter_generation_screen.dart';
import '../screens/chapter_search_screen.dart';
import '../screens/character_management_screen.dart';
import 'outline/outline_management_screen.dart';
import '../widgets/chapter_list/chapter_list_header.dart';
import '../widgets/chapter_list/chapter_list_item.dart';
import '../widgets/chapter_list/reorderable_chapter_item.dart';
import '../widgets/chapter_list/empty_chapters_view.dart';
import '../widgets/ai_accompaniment_settings_dialog.dart';
import '../dialogs/chapter_list/delete_chapter_dialog.dart';
import 'insert_chapter_screen.dart';
import 'background_setting_screen.dart';
import '../controllers/chapter_list/chapter_loader.dart';
import '../controllers/chapter_list/chapter_action_handler.dart';
import '../controllers/chapter_list/chapter_reorder_controller.dart';
import '../services/chapter_service.dart';
import '../constants/chapter_constants.dart';
import '../utils/toast_utils.dart';
import 'dart:async';

class ChapterListScreen extends StatefulWidget {
  final Novel novel;

  // 可选的依赖注入参数 - 用于测试
  final ApiServiceWrapper? api;
  final DatabaseService? databaseService;
  final DifyService? difyService;
  final PreloadService? preloadService;

  const ChapterListScreen({
    super.key,
    required this.novel,
    this.api,
    this.databaseService,
    this.difyService,
    this.preloadService,
  });

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  late final ApiServiceWrapper _api;
  late final DatabaseService _databaseService;
  late final DifyService _difyService;
  late final PreloadService _preloadService;
  final ScrollController _scrollController = ScrollController();

  // 预加载监听
  StreamSubscription<PreloadProgressUpdate>? _preloadSubscription;

  // 控制器
  late final ChapterLoader _chapterLoader;
  late final ChapterActionHandler _chapterActionHandler;
  late final ChapterReorderController _reorderController;
  late final ChapterService _chapterService;

  List<Chapter> _chapters = [];
  bool _isLoading = true;
  bool _isInBookshelf = false;
  String _errorMessage = '';
  int _lastReadChapterIndex = 0;

  // 分页状态
  int _currentPage = 1; // 当前页码（从1开始）
  int _totalPages = 1; // 总页数

  // 当前页章节缓存
  List<Chapter> _currentPageChaptersCache = [];
  int _currentPageCache = -1; // 缓存的页码

  // 章节缓存状态映射（chapterUrl -> isCached）
  final Map<String, bool> _cachedStatus = {};

  /// 获取已缓存章节数量
  ///
  /// 遍历 _cachedStatus Map，统计值为 true 的项数量
  /// 每次缓存状态更新时自动反映最新数量
  int get cachedCount =>
      _cachedStatus.values.where((isCached) => isCached).length;

  // 重排相关状态
  bool _isReorderingMode = false;

  // AI伴读设置状态
  AiAccompanimentSettings? _aiSettings;

  // 生成章节相关的状态
  final ValueNotifier<bool> _isGeneratingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _generatedContentNotifier =
      ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();

    // 使用注入的依赖或创建默认实例
    _api = widget.api ?? ApiServiceProvider.instance;
    _databaseService = widget.databaseService ?? DatabaseService();
    _difyService = widget.difyService ?? DifyService();
    _preloadService = widget.preloadService ?? PreloadService();

    // 初始化控制器（轻量级，同步操作）
    _chapterLoader = ChapterLoader(
      api: _api,
      databaseService: _databaseService,
    );
    _chapterActionHandler = ChapterActionHandler(
      databaseService: _databaseService,
    );
    _reorderController = ChapterReorderController(
      databaseService: _databaseService,
    );
    _chapterService = ChapterService(
      databaseService: _databaseService,
    );

    // 异步初始化重量级数据加载
    _initializeAsyncData();

    // 监听预加载进度
    _listenToPreloadProgress();
  }

  /// 异步初始化数据
  ///
  /// 性能优化：并行执行多个独立的异步操作，减少总初始化时间
  Future<void> _initializeAsyncData() async {
    // 并行执行所有独立的初始化操作
    await Future.wait([
      _initApi(),
      _checkBookshelfStatus(),
      _loadLastReadChapter(),
      _loadAiSettings(),
    ]);

    debugPrint('✅ 所有异步数据初始化完成');
  }

  /// 监听预加载进度
  void _listenToPreloadProgress() {
    _preloadSubscription = _preloadService.progressStream
        .where((update) => update.novelUrl == widget.novel.url) // 过滤当前小说
        .listen((update) {
      if (mounted) {
        // 如果有具体的章节URL，只更新该章节的状态
        if (update.chapterUrl != null) {
          setState(() {
            _cachedStatus[update.chapterUrl!] = true; // 标记为已缓存
          });
          debugPrint('✅ 章节缓存状态更新: ${update.chapterUrl} → 已缓存');
        }
        // 如果没有具体章节URL（队列开始/结束），则重建整个列表
        else {
          setState(() {
            // 触发重建，使用已有的 _cachedStatus 数据
          });
        }
      }
    });
  }

  Future<void> _initApi() async {
    // 对于本地创建的小说，不需要初始化API
    if (widget.novel.url.startsWith('custom://')) {
      _loadChapters();
      return;
    }

    try {
      await _chapterLoader.initApi();
      _loadChapters();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '初始化API失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['api', 'init', 'failed'],
      );
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化API失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _preloadSubscription?.cancel();
    _scrollController.dispose();
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
          await _chapterLoader.loadChapters(widget.novel.url);

      if (cachedChapters.isNotEmpty && !forceRefresh) {
        // 有缓存且不强制刷新时，直接显示缓存
        setState(() {
          _chapters = cachedChapters;
          _isLoading = false;
        });
        _updateTotalPages();
        _scrollToLastReadChapter();
        // 不再批量加载缓存状态，避免性能问题
        // 缓存状态将在用户点击阅读时按需检查
        // _loadCachedStatus();
        return;
      }

      if (cachedChapters.isNotEmpty && forceRefresh) {
        // 有缓存但需要刷新时，先显示缓存，然后在后台更新
        setState(() {
          _chapters = cachedChapters;
          _isLoading = false;
        });
        _updateTotalPages();
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
          _updateTotalPages();
        }
      }
    } catch (e) {
      debugPrint('❌ 加载章节列表失败: $e');
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
      final updatedChapters =
          await _chapterLoader.refreshFromBackend(widget.novel.url);

      if (updatedChapters.isNotEmpty) {
        setState(() {
          _chapters = updatedChapters;
          _isLoading = false;
        });
        _updateTotalPages();
        _scrollToLastReadChapter();

        // 只加载当前页的缓存状态（性能优化）
        _loadCurrentPageCacheStatus();

        // 显示更新成功提示
        if (mounted) {
          ToastUtils.show('章节列表已更新');
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '未能获取章节列表';
        });
      }
    } catch (e) {
      debugPrint('❌ 从后端刷新章节列表失败: $e');
      // 如果已经有缓存数据，不显示错误，只显示提示
      if (_chapters.isNotEmpty) {
        if (mounted) {
          ToastUtils.show('更新章节列表失败: $e');
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载章节列表失败: $e';
        });
      }
    }
  }

  /// 加载当前页章节的缓存状态
  ///
  /// 性能优化：只加载当前可见页面的缓存状态，而不是全部章节
  /// 避免在章节数量多时产生大量数据库查询
  Future<void> _loadCurrentPageCacheStatus() async {
    final pageChapters = _getCurrentPageChapters();
    if (pageChapters.isEmpty) return;

    try {
      // 批量查询当前页章节的缓存状态
      final chapterUrls = pageChapters.map((c) => c.url).toList();
      final results =
          await _chapterActionHandler.areChaptersCached(chapterUrls);

      if (mounted) {
        setState(() {
          _cachedStatus.addAll(results);
        });
      }

      debugPrint('✅ 已加载当前页 ${results.length} 个章节的缓存状态');
    } catch (e) {
      debugPrint('⚠️ 加载当前页缓存状态失败: $e');
    }
  }

  /// 加载所有章节的缓存状态（已废弃，保留用于降级）
  ///
  /// 批量查询数据库，填充 _cachedStatus 映射
  /// ⚠️ 性能警告：章节数量多时会很慢，推荐使用 _loadCurrentPageCacheStatus
  @Deprecated('使用 _loadCurrentPageCacheStatus 替代')
  // ignore: unused_element
  Future<void> _loadCachedStatus() async {
    if (_chapters.isEmpty) return;

    try {
      // 批量查询所有章节的缓存状态
      final chapterUrls = _chapters.map((c) => c.url).toList();
      final results =
          await _chapterActionHandler.areChaptersCached(chapterUrls);

      // 更新状态映射
      if (mounted) {
        setState(() {
          _cachedStatus.addAll(results);
        });
      }

      debugPrint('✅ 已加载 ${results.length} 个章节的缓存状态');
    } catch (e) {
      debugPrint('⚠️ 加载缓存状态失败: $e');
    }
  }

  Future<void> _loadLastReadChapter() async {
    try {
      final lastReadIndex =
          await _chapterLoader.loadLastReadChapter(widget.novel.url);
      setState(() {
        _lastReadChapterIndex = lastReadIndex;
      });
    } catch (e) {
      debugPrint('获取上次阅读章节失败: $e');
    }
  }

  /// 加载AI伴读设置
  Future<void> _loadAiSettings() async {
    try {
      final settings =
          await _databaseService.getAiAccompanimentSettings(widget.novel.url);
      if (mounted) {
        setState(() {
          _aiSettings = settings;
        });
      }
    } catch (e) {
      debugPrint('加载AI伴读设置失败: $e');
    }
  }

  /// 打开AI伴读设置对话框
  void _openAiSettings() {
    showDialog(
      context: context,
      builder: (dialogContext) => AiAccompanimentSettingsDialog(
        initialSettings: _aiSettings ?? const AiAccompanimentSettings(),
        onSave: (settings) async {
          await _databaseService.updateAiAccompanimentSettings(
              widget.novel.url, settings);
          if (mounted) {
            setState(() {
              _aiSettings = settings;
            });
            // 显示保存成功提示
            if (context.mounted) {
              ToastUtils.show('AI伴读设置已保存');
            }
          }
        },
      ),
    );
  }

  void _scrollToLastReadChapter() {
    if (_lastReadChapterIndex >= 0 && _chapters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 计算目标章节所在的页码
        final targetPage =
            (_lastReadChapterIndex / ChapterConstants.chaptersPerPage).floor() +
                1;

        // 跳转到目标页
        if (targetPage != _currentPage) {
          setState(() {
            _currentPage = targetPage.clamp(1, _totalPages);
          });
        }

        // 延迟执行滚动，确保ListView已经重建完成
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            // 计算目标章节在当前页中的索引
            final startIndex =
                (_currentPage - 1) * ChapterConstants.chaptersPerPage;
            final indexInPage = _lastReadChapterIndex - startIndex;

            // 使用简单的滚动方法，避免复杂计算导致的过头问题
            // 计算目标位置：让目标章节显示在可视区域的上方1/4处
            final itemHeight = ChapterConstants.listItemHeight;
            final targetOffset = indexInPage * itemHeight;

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
      });
    }
  }

  /// 计算总页数
  void _updateTotalPages() {
    if (_chapters.isEmpty) {
      _totalPages = 1;
    } else {
      _totalPages =
          (_chapters.length / ChapterConstants.chaptersPerPage).ceil();
    }

    // 清除缓存，因为章节数已变化
    _currentPageCache = -1;
  }

  /// 获取当前页章节（带缓存）
  List<Chapter> _getCurrentPageChapters() {
    // 如果缓存命中且章节数未变化，直接返回缓存
    if (_currentPage == _currentPageCache &&
        _currentPageChaptersCache.isNotEmpty &&
        _currentPageChaptersCache.length <= _chapters.length) {
      return _currentPageChaptersCache;
    }

    // 否则重新加载并缓存
    _currentPageChaptersCache = _loadCurrentPageChapters();
    _currentPageCache = _currentPage;
    return _currentPageChaptersCache;
  }

  /// 加载当前页章节
  List<Chapter> _loadCurrentPageChapters() {
    if (_chapters.isEmpty) return [];

    final startIndex = (_currentPage - 1) * ChapterConstants.chaptersPerPage;
    final endIndex = (startIndex + ChapterConstants.chaptersPerPage)
        .clamp(0, _chapters.length);

    return _chapters.sublist(startIndex, endIndex);
  }

  /// 跳转到指定页码
  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    setState(() {
      _currentPage = page;
    });

    // 加载新页面的缓存状态
    _loadCurrentPageCacheStatus();

    // 滚动到列表顶部
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 构建分页控制栏
  Widget _buildPaginationControl() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 首页按钮
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
            tooltip: '首页',
          ),
          // 上一页按钮
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
            tooltip: '上一页',
          ),
          // 页码显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('第 $_currentPage / $_totalPages 页'),
          ),
          // 下一页按钮
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _goToPage(_currentPage + 1)
                : null,
            tooltip: '下一页',
          ),
          // 末页按钮
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentPage < _totalPages
                ? () => _goToPage(_totalPages)
                : null,
            tooltip: '末页',
          ),
        ],
      ),
    );
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
        ToastUtils.show('已从书架移除');
      }
    } else {
      await _databaseService.addToBookshelf(widget.novel);
      if (mounted) {
        ToastUtils.show('已添加到书架');
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
        ToastUtils.show('缓存已清除');
      }
    } catch (e) {
      debugPrint('❌ 清除缓存失败: $e');
      if (mounted) {
        ToastUtils.show('清除缓存失败: $e');
      }
    }
  }

  // 显示插入章节的页面
  Future<void> _showInsertChapterDialog(
    int afterIndex, {
    String? prefillTitle,
    String? prefillContent,
  }) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => InsertChapterScreen(
          novel: widget.novel,
          afterIndex: afterIndex,
          chapters: _chapters,
          prefillTitle: prefillTitle,
          prefillContent: prefillContent,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      _generateNewChapter(
        afterIndex,
        result['title']!,
        result['content']!,
        result['characterIds'] as List<int>? ?? [],
      );
    }
  }

  // 生成新章节内容
  Future<void> _generateNewChapter(int afterIndex, String title,
      String userInput, List<int> characterIds) async {
    // 在后台开始生成内容
    _callDifyToGenerateChapter(afterIndex, userInput, characterIds);

    // 显示全屏生成页面并等待用户操作
    final result = await ChapterGenerationScreen.show(
      context: context,
      title: title,
      generatedContentNotifier: _generatedContentNotifier,
      isGeneratingNotifier: _isGeneratingNotifier,
    );

    if (result == null) {
      // 用户取消
      return;
    } else if (result == false) {
      // 用户选择重试
      _showInsertChapterDialog(
        afterIndex,
        prefillTitle: title,
        prefillContent: userInput,
      );
      return;
    }

    // 用户选择插入
    final content = _generatedContentNotifier.value;
    if (content.isNotEmpty) {
      await _insertGeneratedChapter(afterIndex, title, content);
    }
  }

  // 调用Dify生成章节内容
  Future<void> _callDifyToGenerateChapter(
      int afterIndex, String userInput, List<int> characterIds) async {
    _isGeneratingNotifier.value = true;
    _generatedContentNotifier.value = '';

    try {
      // 使用 ChapterService 构建完整的 inputs
      final inputs = await _chapterService.buildChapterGenerationInputs(
        novel: widget.novel,
        chapters: _chapters,
        afterIndex: afterIndex,
        userInput: userInput,
        characterIds: characterIds,
      );

      // 直接调用 DifyService 进行流式生成
      await _difyService.runWorkflowStreaming(
        inputs: inputs,
        onData: (data) {
          if (mounted) {
            _generatedContentNotifier.value += data;
          }
        },
        onError: (error) {
          if (mounted) {
            ToastUtils.showError('生成失败: $error');
          }
        },
        onDone: () {
          _isGeneratingNotifier.value = false;
        },
        enableDebugLog: false,
      );
    } catch (e) {
      debugPrint('❌ 调用Dify生成章节失败: $e');
      _isGeneratingNotifier.value = false;
      if (mounted) {
        ToastUtils.showError('生成失败: $e');
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
      await _chapterActionHandler.insertChapter(
        novelUrl: widget.novel.url,
        title: title,
        content: content,
        insertIndex: insertIndex,
      );

      // 重新加载章节列表
      await _loadChapters();

      if (mounted) {
        // 查找刚插入的章节
        final insertedChapter = _chapters.firstWhere(
          (c) => c.title == title,
          orElse: () =>
              _chapters.isNotEmpty ? _chapters[insertIndex] : _chapters.last,
        );

        // 跳转到阅读页面
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(
              novel: widget.novel,
              chapter: insertedChapter,
              chapters: _chapters,
            ),
          ),
          (route) => route.isFirst, // 保留首页
        );
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('插入章节失败: $e');
      }
    }
  }

  // 显示删除章节确认对话框
  Future<void> _showDeleteChapterDialog(Chapter chapter, int index) async {
    final dialog = DeleteChapterDialog(
      chapter: chapter,
      totalChapters: _chapters.length,
    );

    final confirmed = await dialog.show(context);

    if (confirmed) {
      await _deleteChapter(chapter, index);
    }
  }

  // 删除章节的方法
  Future<void> _deleteChapter(Chapter chapter, int index) async {
    try {
      // 显示加载提示
      if (mounted) {
        ToastUtils.show('正在删除章节...');
      }

      // 调用数据库删除方法
      await _chapterActionHandler.deleteChapter(chapter.url);

      // 重新加载章节列表
      await _loadChapters();

      // 显示成功提示
      if (mounted) {
        ToastUtils.showSuccess('章节删除成功');
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ToastUtils.showError('删除章节失败: $e');
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
          _buildReorderButton(),
          _buildSearchButton(),
          _buildCharacterButton(),
          // _buildOutlineButton(),
          // _buildBackgroundSettingButton(),
          _buildPopupMenu(),
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
                    ChapterListHeader(
                      novel: widget.novel,
                      chapterCount: _chapters.length,
                      cachedCount: cachedCount,
                    ),
                    const Divider(),
                    Expanded(
                      child: _chapters.isEmpty
                          ? EmptyChaptersView(
                              novel: widget.novel,
                              onGenerateChapter: () =>
                                  _showInsertChapterDialog(0),
                              onLoadFromSource: () =>
                                  _loadChapters(forceRefresh: true),
                            )
                          : _isReorderingMode
                              ? _buildReorderableChapterList()
                              : _buildNormalChapterList(),
                    ),
                    // 只在非重排模式、有章节且总页数大于1时显示分页控制栏
                    if (!_isReorderingMode &&
                        _chapters.isNotEmpty &&
                        _totalPages > 1)
                      _buildPaginationControl(),
                  ],
                ),
    );
  }

  // 构建重排按钮
  Widget _buildReorderButton() {
    if (_isReorderingMode) {
      return IconButton(
        icon: const Icon(Icons.check),
        onPressed: () {
          setState(() {
            _isReorderingMode = false;
          });
          ToastUtils.show('已退出重排模式');
        },
        tooltip: '完成重排',
        style: IconButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Theme.of(context).colorScheme.surface,
        ),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.reorder),
        onPressed: _toggleReorderingMode,
        tooltip: '重排章节',
      );
    }
  }

  // 构建搜索按钮
  Widget _buildSearchButton() {
    return IconButton(
      icon: const Icon(Icons.search),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChapterSearchScreen(novel: widget.novel),
          ),
        );
      },
      tooltip: '搜索章节内容',
    );
  }

  // 构建人物管理按钮
  Widget _buildCharacterButton() {
    return IconButton(
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
    );
  }

  // 构建弹出菜单
  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'toggle_bookmark':
            _toggleBookshelf();
            break;
          case 'clear_cache':
            _showClearCacheDialog();
            break;
          case 'refresh':
            _loadChapters(forceRefresh: true);
            break;
          case 'outline_management':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OutlineManagementScreen(
                  novelUrl: widget.novel.url,
                  novelTitle: widget.novel.title,
                ),
              ),
            );
            break;
          case 'background_setting':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BackgroundSettingScreen(
                  novel: widget.novel,
                ),
              ),
            );
            break;
          case 'ai_accompaniment_settings':
            _openAiSettings();
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
                Icon(_isInBookshelf ? Icons.bookmark : Icons.bookmark_border),
                const SizedBox(width: 8),
                Text(_isInBookshelf ? '移出书架' : '加入书架'),
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
          if (!isCustomNovel)
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
          const PopupMenuItem(
            value: 'outline_management',
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined),
                SizedBox(width: 8),
                Text('大纲管理'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'background_setting',
            child: Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Text('背景设定'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'ai_accompaniment_settings',
            child: Row(
              children: [
                Icon(Icons.psychology_outlined),
                SizedBox(width: 8),
                Text('AI伴读设置'),
              ],
            ),
          ),
        ];
      },
    );
  }

  // 构建正常的章节列表（支持长按进入重排模式）
  Widget _buildNormalChapterList() {
    final pageChapters = _getCurrentPageChapters();

    return ListView.builder(
      controller: _scrollController,
      itemCount: pageChapters.length,
      itemBuilder: (context, index) {
        final chapter = pageChapters[index];
        // 计算在全部章节中的实际索引
        final globalIndex =
            (_currentPage - 1) * ChapterConstants.chaptersPerPage + index;
        final isLastRead = globalIndex == _lastReadChapterIndex;
        final isUserChapter = chapter.isUserInserted;

        return ChapterListItem(
          chapter: chapter,
          isLastRead: isLastRead,
          isUserChapter: isUserChapter,
          isCached: _cachedStatus[chapter.url] ?? false, // 传入缓存状态
          isRead: chapter.isRead, // 传入已读状态
          isAccompanied: chapter.isAccompanied, // 传入AI伴读状态
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
            ).then((_) {
              // 返回时重新加载上次阅读位置并跳转
              if (mounted) {
                _loadLastReadChapter().then((_) {
                  if (mounted) {
                    _scrollToLastReadChapter();
                  }
                });
              }
            });
          },
          onLongPress: () {
            _toggleReorderingMode();
          },
          onInsert: () => _showInsertChapterDialog(index),
          onDelete: chapter.isUserInserted
              ? () => _showDeleteChapterDialog(chapter, index)
              : null,
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

        return ReorderableChapterListItem(
          key: ValueKey(chapter.url),
          chapter: chapter,
          index: index,
          isLastRead: isLastRead,
          isUserChapter: isUserChapter,
          isCached: _cachedStatus[chapter.url] ?? false, // 传入缓存状态
          isRead: chapter.isRead, // 传入已读状态
          isAccompanied: chapter.isAccompanied, // 传入AI伴读状态
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
      ToastUtils.show('已进入重排模式，拖拽章节调整顺序');
    }
  }

  // 处理章节重排
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      _chapters = _reorderController.onReorder(
        oldIndex: oldIndex,
        newIndex: newIndex,
        chapters: _chapters,
      );
    });

    // 保存重排后的顺序到数据库
    await _saveReorderedChapters();
  }

  // 保存重排后的章节顺序
  Future<void> _saveReorderedChapters() async {
    try {
      // 显示保存进度提示
      ToastUtils.show('正在保存章节顺序...');

      // 批量更新章节索引
      await _reorderController.saveReorderedChapters(
        novelUrl: widget.novel.url,
        chapters: _chapters,
      );

      // 重新加载章节列表以确保数据一致性
      await _loadChapters();

      if (mounted) {
        ToastUtils.showSuccess('章节顺序已保存');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('保存章节顺序失败: $e');
      }
    }
  }
}
