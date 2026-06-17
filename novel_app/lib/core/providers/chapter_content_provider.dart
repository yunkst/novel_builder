import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../services/headless_webview_errors.dart';
import '../../services/logger_service.dart';
import 'repository_providers.dart';
import 'services/network_service_providers.dart';

part 'chapter_content_provider.g.dart';

/// ChapterContentState
///
/// 章节内容状态
class ChapterContentState {
  final String content;
  final bool isLoading;
  final String errorMessage;

  const ChapterContentState({
    this.content = '',
    this.isLoading = false,
    this.errorMessage = '',
  });

  ChapterContentState copyWith({
    String? content,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChapterContentState(
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ChapterContentProvider
///
/// 管理章节内容加载的 Provider
/// 支持从缓存或API加载章节内容
@riverpod
class ChapterContent extends _$ChapterContent {
  @override
  ChapterContentState build() {
    return const ChapterContentState();
  }

  /// 加载章节内容
  ///
  /// [chapter] 要加载的章节
  /// [novel] 所属小说
  /// [forceRefresh] 是否强制刷新（忽略缓存）
  Future<void> loadChapter(
    Chapter chapter,
    Novel novel, {
    bool forceRefresh = false,
  }) async {
    // 设置加载状态
    state = state.copyWith(isLoading: true, errorMessage: '');

    LoggerService.instance.d(
      '开始加载章节内容: chapter=${chapter.title}, forceRefresh=$forceRefresh',
      category: LogCategory.database,
      tags: ['provider', 'chapter-content', 'load'],
    );

    try {
      final chapterRepository = ref.read(chapterRepositoryProvider);

      String content;

      // 先尝试从缓存获取（非强制刷新时）
      if (!forceRefresh) {
        final cachedContent =
            await chapterRepository.getCachedChapter(chapter.url);
        if (cachedContent != null && cachedContent.isNotEmpty) {
          content = cachedContent;
          LoggerService.instance.d(
            '章节内容从缓存加载成功',
            category: LogCategory.database,
            tags: ['provider', 'chapter-content', 'cache'],
          );

          // 更新状态
          state = state.copyWith(content: content, isLoading: false);

          LoggerService.instance.i(
            '章节内容加载成功: ${chapter.title}',
            category: LogCategory.ui,
            tags: ['provider', 'chapter-content', 'success'],
          );

          // 标记章节为已读
          await chapterRepository.markChapterAsRead(
            novel.url,
            chapter.url,
          );
          return;
        }
      }

      // 缓存未命中或强制刷新，用 Headless WebView 获取
      final headlessService = ref.read(headlessWebViewContentServiceProvider);
      final webViewResult = await headlessService.fetchContent(chapter.url);
      if (webViewResult != null && webViewResult.content.trim().isNotEmpty) {
        content = webViewResult.content;
        LoggerService.instance.d(
          '章节内容从 Headless WebView 获取成功',
          category: LogCategory.database,
          tags: ['provider', 'chapter-content', 'headless'],
        );
      } else {
        throw NoExtractionScriptException(
          _extractHost(chapter.url) ?? '',
          url: chapter.url,
        );
      }

      // 验证内容并缓存（forceRefresh时cacheChapter的ConflictAlgorithm.replace会覆盖旧缓存）
      if (content.isNotEmpty && content.length > 50) {
        await chapterRepository.cacheChapter(
          novel.url,
          chapter,
          content,
        );
        LoggerService.instance.d(
          '章节内容从API获取并缓存成功',
          category: LogCategory.database,
          tags: ['provider', 'chapter-content', 'api'],
        );
      } else {
        throw Exception('获取到的章节内容为空或过短');
      }

      // 更新状态
      state = state.copyWith(content: content, isLoading: false);

      LoggerService.instance.i(
        '章节内容加载成功: ${chapter.title}',
        category: LogCategory.ui,
        tags: ['provider', 'chapter-content', 'success'],
      );

      // 标记章节为已读
      await chapterRepository.markChapterAsRead(
        novel.url,
        chapter.url,
      );
    } catch (e, st) {
      LoggerService.instance.e(
        '加载章节内容失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['provider', 'chapter-content', 'load'],
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: '加载章节失败: $e',
      );
      rethrow;
    }
  }

  /// 更新内容（用于改写等场景）
  void updateContent(String newContent) {
    state = state.copyWith(content: newContent);
  }

  /// 清空内容
  void clear() {
    state = const ChapterContentState();
  }

  /// 重置错误状态
  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}

/// 从 URL 提取 host（用于错误信息）
String? _extractHost(String url) {
  try {
    final host = Uri.parse(url).host;
    return host.isNotEmpty ? host : null;
  } catch (_) {
    return null;
  }
}
