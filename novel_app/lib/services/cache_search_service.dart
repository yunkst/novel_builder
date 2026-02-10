import 'package:flutter/foundation.dart' show debugPrint;
import '../models/search_result.dart';
import '../core/interfaces/repositories/i_chapter_repository.dart';

/// 缓存内容搜索服务
class CacheSearchService {
  final IChapterRepository _chapterRepository;
  final dynamic _databaseService;

  /// 构造函数 - 支持依赖注入
  /// 注意：必须通过Provider注入，不再支持直接实例化
  CacheSearchService({
    required IChapterRepository chapterRepository,
    required dynamic databaseService,
  })  : _chapterRepository = chapterRepository,
        _databaseService = databaseService;

  /// 搜索缓存内容
  Future<CacheSearchResult> searchInCache({
    required String keyword,
    String? novelUrl,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      if (keyword.trim().isEmpty) {
        return CacheSearchResult(
          results: [],
          totalCount: 0,
          currentPage: page,
          pageSize: pageSize,
          hasMore: false,
        );
      }

      debugPrint('搜索缓存内容: 关键字="$keyword", 小说URL=$novelUrl');

      // 执行搜索 - 使用 ChapterRepository
      List<ChapterSearchResult> allResults = [];

      try {
        allResults = await _chapterRepository.searchInCachedContent(
          keyword,
          novelUrl: novelUrl,
        );
      } catch (e) {
        debugPrint('⚠️ searchInCachedContent方法调用失败: $e');
        // 方法不存在时返回空结果
        allResults = [];
      }

      // 分页处理
      final totalCount = allResults.length;
      final startIndex = (page - 1) * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, totalCount);

      final List<ChapterSearchResult> pageResults =
          totalCount > 0 ? allResults.sublist(startIndex, endIndex) : [];

      return CacheSearchResult(
        results: pageResults,
        totalCount: totalCount,
        currentPage: page,
        pageSize: pageSize,
        hasMore: endIndex < totalCount,
      );
    } catch (e) {
      debugPrint('搜索缓存内容失败: $e');
      return CacheSearchResult(
        results: [],
        totalCount: 0,
        currentPage: page,
        pageSize: pageSize,
        hasMore: false,
        error: e.toString(),
      );
    }
  }

  /// 获取已缓存小说列表
  Future<List<CachedNovelInfo>> getCachedNovels() async {
    try {
      // 注意：getCachedNovels方法需要在DatabaseService中实现
      // 如果方法不存在，返回空列表
      try {
        return await _databaseService.getCachedNovels();
      } catch (e) {
        debugPrint('⚠️ getCachedNovels方法未实现或调用失败: $e');
        return [];
      }
    } catch (e) {
      debugPrint('获取已缓存小说列表失败: $e');
      return [];
    }
  }

  /// 检查是否有缓存内容
  Future<bool> hasCachedContent() async {
    try {
      final cachedNovels = await getCachedNovels();
      return cachedNovels.isNotEmpty;
    } catch (e) {
      debugPrint('检查缓存内容失败: $e');
      return false;
    }
  }

  /// 搜索建议（基于小说标题）
  Future<List<String>> getSearchSuggestions(String keyword) async {
    try {
      if (keyword.trim().isEmpty) {
        return [];
      }

      final cachedNovels = await getCachedNovels();

      return cachedNovels
          .where((novel) =>
              novel.novelTitle.toLowerCase().contains(keyword.toLowerCase()) ||
              novel.novelAuthor.toLowerCase().contains(keyword.toLowerCase()))
          .map((novel) => novel.novelTitle)
          .take(5)
          .toList();
    } catch (e) {
      debugPrint('获取搜索建议失败: $e');
      return [];
    }
  }

  /// 清理搜索结果（高亮显示）
  String highlightKeyword(String text, String keyword) {
    if (keyword.trim().isEmpty) return text;

    final String lowerKeyword = keyword.toLowerCase();
    final String lowerText = text.toLowerCase();

    if (!lowerText.contains(lowerKeyword)) return text;

    final List<String> parts = [];
    int lastEnd = 0;
    int index = lowerText.indexOf(lowerKeyword);

    while (index != -1) {
      // 添加关键字前的文本
      parts.add(text.substring(lastEnd, index));

      // 添加高亮的关键字
      parts.add('**${text.substring(index, index + keyword.length)}**');

      lastEnd = index + keyword.length;
      index = lowerText.indexOf(lowerKeyword, lastEnd);
    }

    // 添加剩余文本
    if (lastEnd < text.length) {
      parts.add(text.substring(lastEnd));
    }

    return parts.join('');
  }
}

/// 缓存搜索结果模型
class CacheSearchResult {
  final List<ChapterSearchResult> results;
  final int totalCount;
  final int currentPage;
  final int pageSize;
  final bool hasMore;
  final String? error;

  CacheSearchResult({
    required this.results,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
    required this.hasMore,
    this.error,
  });

  /// 是否有错误
  bool get hasError => error != null && error!.isNotEmpty;

  /// 是否为空结果
  bool get isEmpty => results.isEmpty && !hasError;

  /// 获取结果摘要文本
  String get summaryText {
    if (hasError) {
      return '搜索出错: $error';
    }

    if (isEmpty) {
      return '未找到相关内容';
    }

    return '找到 $totalCount 个相关章节';
  }

  /// 获取分页信息
  String get paginationText {
    if (totalCount <= pageSize) {
      return '共 $totalCount 个结果';
    }

    final startItem = (currentPage - 1) * pageSize + 1;
    final endItem = (currentPage * pageSize).clamp(0, totalCount);

    return '第 $startItem-$endItem 个，共 $totalCount 个结果';
  }
}
