import 'package:flutter/foundation.dart';
import '../models/search_result.dart';
import '../services/database_service.dart';

/// 章节搜索服务类
class ChapterSearchService {
  final DatabaseService _databaseService = DatabaseService();

  /// 在指定小说的缓存内容中搜索关键词
  ///
  /// [novelUrl] 小说的URL，用于限制搜索范围
  /// [keyword] 搜索关键词
  ///
  /// 返回匹配的章节搜索结果列表
  Future<List<ChapterSearchResult>> searchInNovel(
    String novelUrl,
    String keyword,
  ) async {
    if (keyword.trim().isEmpty) {
      return [];
    }

    try {
      final results = await _databaseService.searchInCachedContent(
        keyword.trim(),
        novelUrl: novelUrl,
      );

      // 按章节索引排序
      final sortedResults = List<ChapterSearchResult>.from(results);
      sortedResults.sort((a, b) {
        return a.chapterIndex.compareTo(b.chapterIndex);
      });

      return sortedResults;
    } catch (e) {
      throw Exception('搜索失败: $e');
    }
  }

  /// 在所有缓存的小说中搜索关键词
  ///
  /// [keyword] 搜索关键词
  ///
  /// 返回匹配的章节搜索结果列表，不限制小说范围
  Future<List<ChapterSearchResult>> searchInAllNovels(String keyword) async {
    if (keyword.trim().isEmpty) {
      return [];
    }

    try {
      final results = await _databaseService.searchInCachedContent(
        keyword.trim(),
        novelUrl: null, // 不限制小说范围
      );

      // 先按小说URL排序，再按章节索引排序
      final sortedResults = List<ChapterSearchResult>.from(results);
      sortedResults.sort((a, b) {
        final novelComparison = a.novelUrl.compareTo(b.novelUrl);
        if (novelComparison != 0) {
          return novelComparison;
        }

        return a.chapterIndex.compareTo(b.chapterIndex);
      });

      return sortedResults;
    } catch (e) {
      throw Exception('搜索失败: $e');
    }
  }

  /// 获取搜索建议关键词（基于搜索历史或热门关键词）
  ///
  /// 这个方法可以扩展为基于用户搜索历史的建议
  /// 目前返回空列表，可以在未来实现
  Future<List<String>> getSearchSuggestions() async {
    // TODO: 实现搜索建议功能
    // 可以基于用户的搜索历史记录提供建议
    return [];
  }

  /// 保存搜索关键词到历史记录
  ///
  /// [keyword] 搜索关键词
  Future<void> saveSearchHistory(String keyword) async {
    if (keyword.trim().isEmpty) {
      return;
    }

    try {
      // TODO: 实现搜索历史记录功能
      // 可以将搜索历史保存到本地数据库或 SharedPreferences
      // 用于后续的搜索建议功能
    } catch (e) {
      // 搜索历史保存失败不应该影响搜索功能
      debugPrint('保存搜索历史失败: $e');
    }
  }

  /// 清除搜索历史记录
  Future<void> clearSearchHistory() async {
    // TODO: 实现清除搜索历史功能
  }
}
