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
    this.isReorderingMode = false,
    this.aiSettings,
  });

  /// 获取已缓存章节数量
  ///
  /// 直接从 chapters 列表统计，数据源来自 getCachedNovelChapters 的 LEFT JOIN。
  int get cachedCount => chapters.where((c) => c.isCached).length;

  ChapterListState copyWith({
    List<Chapter>? chapters,
    bool? isLoading,
    bool? isInBookshelf,
    String? errorMessage,
    int? lastReadChapterIndex,
    int? currentPage,
    int? totalPages,
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
    LoggerService.instance.d(
      '开始初始化章节数据: novel=${novel.title}',
      category: LogCategory.ui,
      tags: ['provider', 'chapter-list', 'init'],
    );
    try {
      // 并行执行所有独立的初始化操作
      await Future.wait([
        _initApiAndLoadChapters(),
        _checkBookshelfStatus(),
        _loadLastReadChapter(),
        _loadAiSettings(),
      ]);

      LoggerService.instance.i(
        '所有异步数据初始化完成',
        category: LogCategory.ui,
        tags: ['chapter-list'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '初始化数据失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['provider', 'chapter-list', 'init'],
      );
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
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '加载章节列表失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['chapter-list'],
      );
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
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          '加载自定义小说章节失败: $e',
          stackTrace: stackTrace.toString(),
          category: LogCategory.ui,
          tags: ['chapter-list'],
        );
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
        LoggerService.instance.d(
          '用户拒绝刷新章节列表: novel=${novel.title}',
          category: LogCategory.ui,
          tags: ['provider', 'chapter-list', 'refresh_declined'],
        );
        return;
      }
    }

    try {
      // 从后端获取最新章节列表
      LoggerService.instance.d(
        '章节列表缓存未命中/强制刷新，从后端获取: novel=${novel.title}',
        category: LogCategory.ui,
        tags: ['provider', 'chapter-list', 'backend_fetch_start'],
      );
      final updatedChapters = await chapterLoader.refreshFromBackend(
        novel.url,
        forceRefresh: forceRefresh,
      );

      if (updatedChapters.isNotEmpty) {
        LoggerService.instance.i(
          '章节列表后端获取成功: novel=${novel.title} count=${updatedChapters.length}',
          category: LogCategory.ui,
          tags: ['provider', 'chapter-list', 'backend_fetch_success'],
        );
        state = state.copyWith(
          chapters: updatedChapters,
          isLoading: false,
        );
        _updateTotalPages();

        // 缓存状态已由 getCachedNovelChapters 的 LEFT JOIN 填充到 Chapter.isCached

        // 显示更新成功提示
        // ToastUtils.show('章节列表已更新');
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '未能获取章节列表',
        );
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '刷新章节列表失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['chapter-list'],
      );
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
  ///
  /// 已废弃：缓存状态现在直接来自 Chapter.isCached（getCachedNovelChapters 的 LEFT JOIN），
  /// 无需单独加载。预加载进度通过 updateChapterCacheStatus 增量更新单个章节。

  /// 检查书架状态
  Future<void> _checkBookshelfStatus() async {
    final novelRepository = ref.read(novelRepositoryProvider);
    try {
      final isInBookshelf = await novelRepository.isInBookshelf(novel.url);
      state = state.copyWith(isInBookshelf: isInBookshelf);
      LoggerService.instance.d(
        '书架状态检查完成: isInBookshelf=$isInBookshelf',
        category: LogCategory.database,
        tags: ['provider', 'chapter-list', 'bookshelf-status'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '检查书架状态失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['provider', 'chapter-list', 'bookshelf-status'],
      );
    }
  }

  /// 加载最后阅读章节
  Future<void> _loadLastReadChapter() async {
    final chapterLoader = ref.watch(chapterLoaderProvider);
    try {
      final lastReadIndex = await chapterLoader.loadLastReadChapter(novel.url);
      state = state.copyWith(lastReadChapterIndex: lastReadIndex);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取上次阅读章节失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['chapter-list'],
      );
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
      LoggerService.instance.w(
        '加载AI伴读设置失败: $e',
        category: LogCategory.ui,
        tags: ['chapter-list'],
      );
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

    LoggerService.instance.i(
      '切换书架状态: novel=${novel.title} → isInBookshelf=${!state.isInBookshelf}',
      category: LogCategory.ui,
      tags: ['provider', 'chapter-list', 'toggle_bookshelf'],
    );

    await _checkBookshelfStatus();
  }

  /// 清除缓存
  Future<void> clearCache() async {
    // clearNovelCache 涉及多个表的清理操作，暂时保留使用 DatabaseService
    final databaseService = ref.read(databaseServiceProvider);
    try {
      await databaseService.clearNovelCache(novel.url);
      // 重新加载章节列表，getCachedNovelChapters 的 LEFT JOIN 会返回 isCached=false
      await _loadChapters();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '清除缓存失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['chapter-list'],
      );
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
  }

  /// 更新章节缓存状态（用于预加载进度监听）
  ///
  /// 直接更新对应 Chapter 的 isCached 字段。预加载每完成一章触发一次。
  void updateChapterCacheStatus(String chapterUrl, bool isCached) {
    final updatedChapters = state.chapters.map((c) {
      if (c.url == chapterUrl) {
        return c.copyWith(isCached: isCached);
      }
      return c;
    }).toList();
    state = state.copyWith(chapters: updatedChapters);
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

    LoggerService.instance.i(
      '章节重排: novel=${novel.title} oldIndex=$oldIndex newIndex=$newIndex',
      category: LogCategory.ui,
      tags: ['provider', 'chapter-list', 'reorder'],
    );

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
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '保存章节顺序失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ui,
        tags: ['chapter-list'],
      );
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
