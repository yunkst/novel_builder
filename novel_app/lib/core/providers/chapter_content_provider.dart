import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import 'service_providers.dart';
import 'repository_providers.dart';

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

    try {
      final apiService = ref.read(apiServiceWrapperProvider);
      final chapterRepository = ref.read(chapterRepositoryProvider);

      String content;

      // 强制刷新时先删除缓存
      if (forceRefresh) {
        await chapterRepository.deleteChapterCache(chapter.url);
      }

      // 尝试从缓存获取
      final cachedContent = await chapterRepository.getCachedChapter(chapter.url);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        content = cachedContent;
      } else {
        // 缓存未命中，从API获取
        content = await apiService.getChapterContent(
          chapter.url,
          forceRefresh: forceRefresh,
        );

        // 验证内容并缓存
        if (content.isNotEmpty && content.length > 50) {
          await chapterRepository.cacheChapter(
            novel.url,
            chapter,
            content,
          );
        } else {
          throw Exception('获取到的章节内容为空或过短');
        }
      }

      // 更新状态
      state = state.copyWith(content: content, isLoading: false);

      // 标记章节为已读
      await chapterRepository.markChapterAsRead(
        novel.url,
        chapter.url,
      );
    } catch (e) {
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
