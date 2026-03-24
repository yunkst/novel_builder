/// ChapterListScreen Providers
///
/// 管理 ChapterListScreen 的所有状态和逻辑
/// 使用 Riverpod 的 StateNotifier 和 FutureProvider 进行状态管理
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../models/ai_accompaniment_settings.dart';
import '../../services/preload_progress_update.dart';
import '../../services/logger_service.dart';
import '../../constants/chapter_constants.dart';
import 'service_providers.dart';
import 'repository_providers.dart';
import 'database_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'chapter_list_providers.g.dart';

/// ChapterListScreen 状态类
class ChapterListState {
  final List<Chapter> chapters;
  final bool isLoading;
  final bool isInBookshelf;
  final String errorMessage;
  final int lastReadChapterIndex;
  final int currentPage;
  final int totalPages;
  final Map<String, bool> cachedStatus;
  final bool isReorderingMode;
  final AiAccompanimentSettings? aiSettings;

  const ChapterListState({
    this.chapters = const [],
    this.isLoading = true,
    this.isInBookshelf = false,
    this.errorMessage = '',
    this.lastReadChapterIndex = -1,
    this.currentPage = 1,
    this.totalPages = 1,
    this.cachedStatus = const {},
    this.isReorderingMode = false,
    this.aiSettings,
  });

  /// 获取已缓存章节数量
  int get cachedCount =>
      cachedStatus.values.where((isCached) => isCached).length;

  ChapterListState copyWith({
    List<Chapter>? chapters,
    bool? isLoading,
    bool? isInBookshelf,
    String? errorMessage,
    int? lastReadChapterIndex,
    int? currentPage,
    int? totalPages,
    Map<String, bool>? cachedStatus,
    bool? isReorderingMode,
    AiAccompanimentSettings? aiSettings,
  }) {
    return ChapterListState(
      chapters: chapters ?? this.chapters,
      isLoading: isLoading ?? this.isLoading,
      isInBookshelf: isInBookshelf ?? this.isInBookshelf,
      errorMessage: errorMessage ?? this.errorMessage,
      lastReadChapterIndex: lastReadChapterIndex ?? this.lastReadChapterIndex,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      cachedStatus: cachedStatus ?? this.cachedStatus,
      isReorderingMode: isReorderingMode ?? this.isReorderingMode,
      aiSettings: aiSettings ?? this.aiSettings,
    );
  }
}

/// ChapterListStateNotifier
///
/// 管理 ChapterListScreen 的状态
@riverpod
class ChapterList extends _$ChapterList {
  @override
  ChapterListState build(Novel novel) {
    // 使用 Future.microtask 确保 build() 返回后再执行异步操作
    // 避免 "Tried to read the state of an uninitialized provider" 错误
    Future.microtask(() => _initializeData());
    return const ChapterListState();
  }

  /// 初始化数据
  Future<void> _initializeData() async {
    try {
      // 并行执行所有独立的初始化操作
      await Future.wait([
        _initApiAndLoadChapters(),
        _checkBookshelfStatus(),
        _loadLastReadChapter(),
        _loadAiSettings(),
      ]);

      debugPrint('✅ 所有异步数据初始化完成');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '初始化失败: $e',
      );
    }
  }

  /// 初始化API并加载章节
  Future<void> _initApiAndLoadChapters() async {
    final chapterLoader = ref.watch(chapterLoaderProvider);

    // 对于本地创建的小说，不需要初始化API
    if (novel.url.startsWith('custom://')) {
      await _loadChapters();
      return;
    }

    try {
      await chapterLoader.initApi();
      await _loadChapters();
    } catch (e, stackTrace) {
      final logger = ref.read(loggerServiceProvider);
      logger.e(
        '初始化API失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['api', 'init', 'failed'],
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: '初始化API失败: $e',
      );
    }
  }

  /// 加载章节列表
  Future<void> _loadChapters({
    bool forceRefresh = false,
    BuildContext? context,
  }) async {
    // 在方法开始时保存 context 引用，避免跨异步边界使用
    final savedContext = context;
    final chapterLoader = ref.watch(chapterLoaderProvider);

    state = state.copyWith(isLoading: true, errorMessage: '');

    try {
      // 先尝试从缓存加载
      final cachedChapters = await chapterLoader.loadChapters(novel.url);

      if (cachedChapters.isNotEmpty && !forceRefresh) {
        // 有缓存且不强制刷新时，直接显示缓存
        state = state.copyWith(
          chapters: cachedChapters,
          isLoading: false,
        );
        _updateTotalPages();
        return;
      }

      if (cachedChapters.isNotEmpty && forceRefresh && savedContext == null) {
        // 有缓存但需要刷新，且没有提供 context（如首次加载），直接刷新
        await _refreshChaptersFromBackend(forceRefresh: true);
      } else if (cachedChapters.isNotEmpty && forceRefresh && savedContext != null) {
        // 有缓存但需要刷新，且有 context（用户手动刷新）
        // ignore: use_build_context_synchronously - savedContext 在方法开始时已保存
        await _refreshChaptersFromBackend(forceRefresh: true, context: savedContext);
      } else {
        // 没有缓存时，检查是否为自定义小说
        if (cachedChapters.isEmpty && novel.url.startsWith('custom://')) {
          // 自定义小说没有章节时，直接设置空状态，结束loading
          state = state.copyWith(
            chapters: [],
            isLoading: false,
          );
          _updateTotalPages();
          return;
        }
        // 从后端获取
        await _refreshChaptersFromBackend(forceRefresh: forceRefresh);
      }
    } catch (e) {
      debugPrint('❌ 加载章节列表失败: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载章节列表失败: $e',
      );
    }
  }

  /// 从后端刷新章节列表
  Future<void> _refreshChaptersFromBackend({
    bool forceRefresh = false,
    BuildContext? context,
  }) async {
    final chapterLoader = ref.watch(chapterLoaderProvider);

    // 对于本地创建的小说，不需要从后端获取，直接从数据库加载
    if (novel.url.startsWith('custom://')) {
      try {
        // 从数据库加载用户创建的章节
        final chapters = await chapterLoader.loadChapters(novel.url);
        state = state.copyWith(
          chapters: chapters,
          isLoading: false,
        );
        _updateTotalPages();
      } catch (e) {
        debugPrint('❌ 加载自定义小说章节失败: $e');
        state = state.copyWith(
          isLoading: false,
          errorMessage: '加载章节失败: $e',
        );
      }
      return;
    }

    // 如果需要强制刷新且有 context，显示确认对话框
    if (forceRefresh && context != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('刷新章节列表'),
          content: const Text(
            '是否需要重新抓取最新章节信息？\n\n'
            '选择"是"将强制从源站重新获取，可能需要较长时间。\n'
            '选择"否"将使用缓存的章节列表。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('否'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('是'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        // 用户选择不刷新，使用缓存
        return;
      }
    }

    try {
      // 从后端获取最新章节列表
      final updatedChapters = await chapterLoader.refreshFromBackend(
        novel.url,
        forceRefresh: forceRefresh,
      );

      if (updatedChapters.isNotEmpty) {
        state = state.copyWith(
          chapters: updatedChapters,
          isLoading: false,
        );
        _updateTotalPages();

        // 只加载当前页的缓存状态（性能优化）
        await _loadCurrentPageCacheStatus();

        // 显示更新成功提示
        // ToastUtils.show('章节列表已更新');
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '未能获取章节列表',
        );
      }
    } catch (e) {
      debugPrint('❌ 从后端刷新章节列表失败: $e');
      // 如果已经有缓存数据，不显示错误，只显示提示
      if (state.chapters.isNotEmpty) {
        // ToastUtils.show('更新章节列表失败: $e');
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '加载章节列表失败: $e',
        );
      }
    }
  }

  /// 加载当前页章节的缓存状态
  Future<void> _loadCurrentPageCacheStatus() async {
    final pageChapters = _getCurrentPageChapters();
    if (pageChapters.isEmpty) return;

    try {
      final chapterActionHandler = ref.watch(chapterActionHandlerProvider);

      // 批量查询当前页章节的缓存状态
      final chapterUrls = pageChapters.map((c) => c.url).toList();
      final results = await chapterActionHandler.areChaptersCached(chapterUrls);

      state = state.copyWith(
        cachedStatus: {...state.cachedStatus, ...results},
      );

      debugPrint('✅ 已加载当前页 ${results.length} 个章节的缓存状态');
    } catch (e) {
      debugPrint('⚠️ 加载当前页缓存状态失败: $e');
    }
  }

  /// 检查书架状态
  Future<void> _checkBookshelfStatus() async {
    final novelRepository = ref.read(novelRepositoryProvider);
    final isInBookshelf = await novelRepository.isInBookshelf(novel.url);
    state = state.copyWith(isInBookshelf: isInBookshelf);
  }

  /// 加载最后阅读章节
  Future<void> _loadLastReadChapter() async {
    final chapterLoader = ref.watch(chapterLoaderProvider);
    try {
      final lastReadIndex = await chapterLoader.loadLastReadChapter(novel.url);
      state = state.copyWith(lastReadChapterIndex: lastReadIndex);
    } catch (e) {
      debugPrint('获取上次阅读章节失败: $e');
    }
  }

  /// 加载AI伴读设置
  Future<void> _loadAiSettings() async {
    final novelRepository = ref.read(novelRepositoryProvider);
    try {
      final settings =
          await novelRepository.getAiAccompanimentSettings(novel.url);
      state = state.copyWith(aiSettings: settings);
    } catch (e) {
      debugPrint('加载AI伴读设置失败: $e');
    }
  }

  /// 计算总页数
  void _updateTotalPages() {
    if (state.chapters.isEmpty) {
      state = state.copyWith(totalPages: 1);
    } else {
      final totalPages = (state.chapters.length / ChapterConstants.chaptersPerPage).ceil();
      state = state.copyWith(totalPages: totalPages);
    }
  }

  /// 获取当前页章节
  List<Chapter> _getCurrentPageChapters() {
    if (state.chapters.isEmpty) return [];

    final chaptersPerPage = ChapterConstants.chaptersPerPage;
    final startIndex = (state.currentPage - 1) * chaptersPerPage;
    final endIndex =
        (startIndex + chaptersPerPage).clamp(0, state.chapters.length);

    return state.chapters.sublist(startIndex, endIndex);
  }

  /// 刷新章节列表
  /// [context] 可选的 BuildContext，用于显示刷新确认对话框
  Future<void> refreshChapters(BuildContext? context) async {
    await _loadChapters(forceRefresh: true, context: context);
  }

  /// 切换书架状态
  Future<void> toggleBookshelf() async {
    final novelRepository = ref.read(novelRepositoryProvider);

    if (state.isInBookshelf) {
      await novelRepository.removeFromBookshelf(novel.url);
    } else {
      await novelRepository.addToBookshelf(novel);
    }

    await _checkBookshelfStatus();
  }

  /// 清除缓存
  Future<void> clearCache() async {
    // clearNovelCache 涉及多个表的清理操作，暂时保留使用 DatabaseService
    final databaseService = ref.read(databaseServiceProvider);
    try {
      await databaseService.clearNovelCache(novel.url);
    } catch (e) {
      debugPrint('❌ 清除缓存失败: $e');
      rethrow;
    }
  }

  /// 切换重排模式
  void toggleReorderingMode() {
    state = state.copyWith(
      isReorderingMode: !state.isReorderingMode,
    );
  }

  /// 退出重排模式
  void exitReorderingMode() {
    state = state.copyWith(isReorderingMode: false);
  }

  /// 跳转到指定页码
  void goToPage(int page) {
    if (page < 1 || page > state.totalPages) return;

    state = state.copyWith(currentPage: page);

    // 加载新页面的缓存状态
    _loadCurrentPageCacheStatus();
  }

  /// 更新章节缓存状态（用于预加载进度监听）
  void updateChapterCacheStatus(String chapterUrl, bool isCached) {
    final newCachedStatus = Map<String, bool>.from(state.cachedStatus);
    newCachedStatus[chapterUrl] = isCached;
    state = state.copyWith(cachedStatus: newCachedStatus);
  }

  /// 重排章节
  Future<void> reorderChapters(int oldIndex, int newIndex) async {
    final reorderController = ref.watch(chapterReorderControllerProvider);

    final reorderedChapters = reorderController.onReorder(
      oldIndex: oldIndex,
      newIndex: newIndex,
      chapters: state.chapters,
    );

    state = state.copyWith(chapters: reorderedChapters);

    // 保存重排后的顺序到数据库
    await _saveReorderedChapters();
  }

  /// 保存重排后的章节顺序
  Future<void> _saveReorderedChapters() async {
    final reorderController = ref.watch(chapterReorderControllerProvider);

    try {
      await reorderController.saveReorderedChapters(
        novelUrl: novel.url,
        chapters: state.chapters,
      );

      // 重新加载章节列表以确保数据一致性
      await _loadChapters();
    } catch (e) {
      debugPrint('❌ 保存章节顺序失败: $e');
      rethrow;
    }
  }

  /// 重新加载最后阅读位置
  Future<void> reloadLastReadChapter() async {
    await _loadLastReadChapter();
  }
}

/// ChapterListScreen 的 Novel 参数 Provider
///
/// 用于在屏幕中传递 novel 参数
@riverpod
Novel currentNovel(Ref ref) {
  throw UnimplementedError('currentNovel must be overridden');
}

/// 生成章节相关的状态
@riverpod
class ChapterGeneration extends _$ChapterGeneration {
  @override
  bool build() {
    return false;
  }

  void setGenerating(bool isGenerating) {
    state = isGenerating;
  }
}

/// 生成章节内容的状态
@riverpod
class GeneratedContent extends _$GeneratedContent {
  @override
  String build() {
    return '';
  }

  void setContent(String content) {
    state = content;
  }

  void appendContent(String content) {
    state += content;
  }

  void clear() {
    state = '';
  }
}

/// 预加载进度监听 Provider
///
/// 监听 PreloadService 的进度更新
@riverpod
Stream<PreloadProgressUpdate> preloadProgress(Ref ref, Novel novel) {
  final preloadService = ref.watch(preloadServiceProvider);

  return preloadService.progressStream
      .where((update) => update.novelUrl == novel.url);
}
