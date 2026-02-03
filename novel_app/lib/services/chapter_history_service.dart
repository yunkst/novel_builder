import 'package:flutter/foundation.dart';
import '../models/chapter.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';

/// ChapterHistoryService
///
/// 职责：
/// - 获取历史章节内容（用于AI生成的上下文）
/// - 统一历史章节加载逻辑
/// - 支持缓存和API获取
///
/// 使用方式：
/// ```dart
/// // 通过Provider获取（推荐）
/// final service = ref.watch(chapterHistoryServiceProvider);
///
/// // 或手动指定依赖
/// final service = ChapterHistoryService(
///   databaseService: _databaseService,
///   apiService: _apiService,
/// );
///
/// final historyContent = await service.fetchHistoryChaptersContent(
///   chapters: widget.chapters,
///   currentChapter: widget.currentChapter,
///   maxHistoryCount: 2,
/// );
/// ```
class ChapterHistoryService {
  final DatabaseService _databaseService;
  final ApiServiceWrapper _apiService;

  /// 创建 ChapterHistoryService 实例
  ///
  /// 参数:
  /// - [databaseService] 数据库服务（必需）
  /// - [apiService] API服务（必需）
  ChapterHistoryService({
    required DatabaseService databaseService,
    required ApiServiceWrapper apiService,
  })  : _databaseService = databaseService,
        _apiService = apiService;

  /// 获取历史章节内容（最多前N章）
  ///
  /// [chapters] 所有章节列表
  /// [currentChapter] 当前章节
  /// [maxHistoryCount] 最大历史章节数量（默认2）
  ///
  /// 返回格式化后的历史章节内容字符串
  Future<String> fetchHistoryChaptersContent({
    required List<Chapter> chapters,
    required Chapter currentChapter,
    int maxHistoryCount = 2,
  }) async {
    final currentIndex = chapters.indexWhere(
      (c) => c.url == currentChapter.url,
    );

    if (currentIndex == -1) {
      debugPrint('⚠️ ChapterHistoryService: 未找到当前章节索引');
      return '';
    }

    debugPrint('📚 ChapterHistoryService: 当前章节索引=$currentIndex, 开始获取历史章节');

    final historyContents = <String>[];

    // 从最近到最远获取历史章节
    for (int i = 1; i <= maxHistoryCount; i++) {
      final historyIndex = currentIndex - i;
      if (historyIndex >= 0 && historyIndex < chapters.length) {
        final chapter = chapters[historyIndex];

        try {
          // 尝试从缓存获取
          var content = await _databaseService.getCachedChapter(chapter.url);

          // 如果缓存未命中，从API获取
          if (content == null || content.isEmpty) {
            debugPrint(
                '🌐 ChapterHistoryService: 缓存未命中，从API获取 - ${chapter.title}');
            content = await _apiService.getChapterContent(chapter.url);
          } else {
            debugPrint('💾 ChapterHistoryService: 从缓存加载 - ${chapter.title}');
          }

          // 格式化为历史章节内容
          historyContents.add('历史章节: ${chapter.title}\n\n$content');
          debugPrint(
              '✅ ChapterHistoryService: 已加载历史章节 - ${chapter.title} (${content.length}字符)');
        } catch (e) {
          debugPrint(
              '❌ ChapterHistoryService: 加载历史章节失败 - ${chapter.title}, 错误: $e');
          // 继续加载其他章节，不中断
        }
      }
    }

    final result = historyContents.join('\n\n');
    debugPrint(
        '📊 ChapterHistoryService: 历史章节加载完成，共${historyContents.length}章，总计${result.length}字符');

    return result;
  }

  /// 仅获取历史章节内容列表（不格式化）
  ///
  /// 返回章节内容列表（纯内容，不包含标题前缀）
  Future<List<String>> fetchHistoryChaptersList({
    required List<Chapter> chapters,
    required Chapter currentChapter,
    int maxHistoryCount = 2,
  }) async {
    final currentIndex = chapters.indexWhere(
      (c) => c.url == currentChapter.url,
    );

    if (currentIndex == -1) return [];

    final historyContents = <String>[];

    for (int i = 1; i <= maxHistoryCount; i++) {
      final historyIndex = currentIndex - i;
      if (historyIndex >= 0 && historyIndex < chapters.length) {
        final chapter = chapters[historyIndex];

        try {
          var content = await _databaseService.getCachedChapter(chapter.url) ??
              await _apiService.getChapterContent(chapter.url);

          historyContents.add(content);
        } catch (e) {
          debugPrint(
              '❌ ChapterHistoryService: 加载失败 - ${chapter.title}, 错误: $e');
        }
      }
    }

    return historyContents;
  }
}
