/// Riverpod Providers for ChapterSearchScreen
///
/// 提供 ChapterSearchScreen 所需的所有状态和逻辑
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../models/search_result.dart';
import '../../services/logger_service.dart';
import 'database_providers.dart';
import 'service_providers.dart';

part 'chapter_search_providers.g.dart';

/// Novel Parameter Provider
///
/// 提供 ChapterSearchScreen 所需的 Novel 参数
@riverpod
class NovelParam extends _$NovelParam {
  Novel? _novel;

  Novel? get novel => _novel;

  void setNovel(Novel novel) {
    _novel = novel;
  }

  @override
  Novel? build() {
    return _novel;
  }
}

/// Chapters List Provider
///
/// 提供小说的章节列表
@riverpod
Future<List<Chapter>> chaptersList(Ref ref) async {
  final novelParam = ref.watch(novelParamProvider);
  if (novelParam == null) {
    return [];
  }

  final chapterRepository = ref.watch(chapterRepositoryProvider);

  try {
    final chapters =
        await chapterRepository.getCachedNovelChapters(novelParam.url);
    return chapters;
  } catch (e, stackTrace) {
    LoggerService.instance.e(
      '加载章节列表失败',
      stackTrace: stackTrace.toString(),
      category: LogCategory.database,
      tags: ['chapter', 'list', 'load', 'failed'],
    );
    rethrow;
  }
}

/// Search Query Provider
///
/// 管理搜索查询字符串
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() {
    return '';
  }

  void update(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Search Results Provider
///
/// 提供章节搜索结果
@riverpod
Future<List<ChapterSearchResult>> searchResults(Ref ref) async {
  final novelParam = ref.watch(novelParamProvider);
  final query = ref.watch(searchQueryProvider);

  if (novelParam == null || query.trim().isEmpty) {
    return [];
  }

  final searchService = ref.watch(chapterSearchServiceProvider);

  try {
    final results = await searchService.searchInNovel(
      novelParam.url,
      query.trim(),
    );
    return results;
  } catch (e, stackTrace) {
    LoggerService.instance.e(
      '搜索章节失败',
      stackTrace: stackTrace.toString(),
      category: LogCategory.database,
      tags: ['chapter', 'search', 'failed'],
    );
    rethrow;
  }
}

/// Search State Provider
///
/// 管理搜索状态（是否已搜索、是否正在加载）
@riverpod
class SearchState extends _$SearchState {
  @override
  SearchStateData build() {
    return SearchStateData(
      hasSearched: false,
      isLoading: false,
    );
  }

  void setHasSearched(bool value) {
    state = SearchStateData(
      hasSearched: value,
      isLoading: state.isLoading,
    );
  }

  void setIsLoading(bool value) {
    state = SearchStateData(
      hasSearched: state.hasSearched,
      isLoading: value,
    );
  }

  void reset() {
    state = SearchStateData(
      hasSearched: false,
      isLoading: false,
    );
  }
}

/// Search State Data Model
class SearchStateData {
  final bool hasSearched;
  final bool isLoading;

  const SearchStateData({
    required this.hasSearched,
    required this.isLoading,
  });
}
