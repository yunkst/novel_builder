import '../../models/chapter.dart';
import '../../services/database_service.dart';
import '../../services/api_service_wrapper.dart';
import '../../core/repositories/chapter_repository.dart';
import '../../core/utils/result.dart';
import '../../core/failures/database_failure.dart';
import '../../core/failures/network_failure.dart';
import '../../core/failures/cache_failure.dart';
import '../../core/utils/error_handler.dart';

/// 章节Repository实现
class ChapterRepositoryImpl implements ChapterRepository {
  final DatabaseService _databaseService;
  final ApiServiceWrapper _apiService;

  ChapterRepositoryImpl({
    required DatabaseService databaseService,
    required ApiServiceWrapper apiService,
  }) : _databaseService = databaseService,
       _apiService = apiService;

  @override
  Future<Result<List<Chapter>>> getChapters(String novelUrl, {bool forceRefresh = false}) async {
    try {
      // 对于自定义小说，直接从数据库获取
      if (novelUrl.startsWith('custom://')) {
        final chapters = await _databaseService.getCachedNovelChapters(novelUrl);
        return Result.success(chapters);
      }

      // 先尝试从缓存获取
      if (!forceRefresh) {
        final cachedChapters = await _databaseService.getCachedNovelChapters(novelUrl);
        if (cachedChapters.isNotEmpty) {
          return Result.success(cachedChapters);
        }
      }

      // 从网络获取章节列表
      await _apiService.init();
      final chapters = await _apiService.getChapters(novelUrl);

      if (chapters.isNotEmpty) {
        // 缓存章节列表
        await _databaseService.cacheNovelChapters(novelUrl, chapters);

        // 重新获取包含用户章节的完整列表
        final updatedChapters = await _databaseService.getCachedNovelChapters(novelUrl);
        return Result.success(updatedChapters);
      }

      return Result.success(chapters);
    } catch (e) {
      if (novelUrl.startsWith('custom://')) {
        ErrorHandler.logError(
          DatabaseFailure('Failed to get custom chapters: $e'),
          'ChapterRepository.getChapters',
        );
        return Result.failure(DatabaseFailure('获取章节列表失败: $e'));
      } else {
        ErrorHandler.logError(
          NetworkFailure('Failed to get chapters from network: $e'),
          'ChapterRepository.getChapters',
        );
        return Result.failure(NetworkFailure('获取章节列表失败: $e'));
      }
    }
  }

  @override
  Future<Result<String>> getChapterContent(String chapterUrl) async {
    try {
      // 对于本地章节，直接从数据库获取
      if (_isLocalChapter(chapterUrl)) {
        final content = await _databaseService.getCachedChapter(chapterUrl);
        if (content != null && content.isNotEmpty) {
          return Result.success(content);
        } else {
          return Result.failure(CacheFailure('本地章节内容不存在'));
        }
      }

      // 先从缓存获取
      final cachedContent = await _databaseService.getCachedChapter(chapterUrl);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        return Result.success(cachedContent);
      }

      // 从网络获取
      await _apiService.init();
      final content = await _apiService.getChapterContent(chapterUrl);

      // 验证内容有效性
      if (content.isNotEmpty && content.length > 50) {
        return Result.success(content);
      } else {
        return Result.failure(NetworkFailure('章节内容为空或过短'));
      }
    } catch (e) {
      if (_isLocalChapter(chapterUrl)) {
        ErrorHandler.logError(
          CacheFailure('Failed to get local chapter content: $e'),
          'ChapterRepository.getChapterContent',
        );
        return Result.failure(CacheFailure('获取本地章节内容失败: $e'));
      } else {
        ErrorHandler.logError(
          NetworkFailure('Failed to get chapter content from network: $e'),
          'ChapterRepository.getChapterContent',
        );
        return Result.failure(NetworkFailure('获取章节内容失败: $e'));
      }
    }
  }

  @override
  Future<Result<void>> cacheChapter(String novelUrl, Chapter chapter, String content) async {
    try {
      await _databaseService.cacheChapter(novelUrl, chapter, content);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to cache chapter: $e'),
        'ChapterRepository.cacheChapter',
      );
      return Result.failure(CacheFailure('缓存章节失败: $e'));
    }
  }

  @override
  Future<Result<void>> cacheChapters(String novelUrl, List<Chapter> chapters) async {
    try {
      await _databaseService.cacheNovelChapters(novelUrl, chapters);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to cache chapters: $e'),
        'ChapterRepository.cacheChapters',
      );
      return Result.failure(CacheFailure('批量缓存章节失败: $e'));
    }
  }

  @override
  Future<Result<void>> updateChapterContent(String chapterUrl, String content) async {
    try {
      await _databaseService.updateChapterContent(chapterUrl, content);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to update chapter content: $e'),
        'ChapterRepository.updateChapterContent',
      );
      return Result.failure(DatabaseFailure('更新章节内容失败: $e'));
    }
  }

  @override
  Future<Result<void>> insertUserChapter(String novelUrl, String title, String content, int insertIndex) async {
    try {
      await _databaseService.insertUserChapter(novelUrl, title, content, insertIndex);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to insert user chapter: $e'),
        'ChapterRepository.insertUserChapter',
      );
      return Result.failure(DatabaseFailure('插入用户章节失败: $e'));
    }
  }

  @override
  Future<Result<void>> deleteUserChapter(String chapterUrl) async {
    try {
      // 确保只能删除用户章节
      final chapters = await _databaseService.getChapterByUrl(chapterUrl);
      if (chapters != null && chapters.isUserInserted) {
        await _databaseService.deleteUserChapter(chapterUrl);
        return Result.success(null);
      } else {
        return Result.failure(CacheFailure('只能删除用户创建的章节'));
      }
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to delete user chapter: $e'),
        'ChapterRepository.deleteUserChapter',
      );
      return Result.failure(DatabaseFailure('删除用户章节失败: $e'));
    }
  }

  @override
  Future<Result<void>> createCustomChapter(String novelUrl, String title, String content) async {
    try {
      await _databaseService.createCustomChapter(novelUrl, title, content);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to create custom chapter: $e'),
        'ChapterRepository.createCustomChapter',
      );
      return Result.failure(DatabaseFailure('创建自定义章节失败: $e'));
    }
  }

  @override
  Future<Result<int>> getCachedChaptersCount(String novelUrl) async {
    try {
      final count = await _databaseService.getCachedChaptersCount(novelUrl);
      return Result.success(count);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to get cached chapters count: $e'),
        'ChapterRepository.getCachedChaptersCount',
      );
      return Result.failure(DatabaseFailure('获取缓存章节数量失败: $e'));
    }
  }

  @override
  Future<Result<void>> clearNovelCache(String novelUrl) async {
    try {
      await _databaseService.clearNovelCache(novelUrl);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to clear novel cache: $e'),
        'ChapterRepository.clearNovelCache',
      );
      return Result.failure(CacheFailure('清理小说缓存失败: $e'));
    }
  }

  @override
  Future<Result<bool>> isChapterCached(String chapterUrl) async {
    try {
      final isCached = await _databaseService.isChapterCached(chapterUrl);
      return Result.success(isCached);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to check if chapter is cached: $e'),
        'ChapterRepository.isChapterCached',
      );
      return Result.failure(DatabaseFailure('检查章节缓存状态失败: $e'));
    }
  }

  @override
  Future<Result<int>> getLastReadChapter(String novelUrl) async {
    try {
      final lastReadIndex = await _databaseService.getLastReadChapter(novelUrl);
      return Result.success(lastReadIndex);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to get last read chapter: $e'),
        'ChapterRepository.getLastReadChapter',
      );
      return Result.failure(DatabaseFailure('获取最后阅读章节失败: $e'));
    }
  }

  @override
  Future<Result<void>> updateReadingProgress(String novelUrl, int chapterIndex, double progress) async {
    try {
      await _databaseService.updateReadingProgress(novelUrl, chapterIndex, progress);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to update reading progress: $e'),
        'ChapterRepository.updateReadingProgress',
      );
      return Result.failure(DatabaseFailure('更新阅读进度失败: $e'));
    }
  }

  /// 判断是否为本地章节
  bool _isLocalChapter(String chapterUrl) {
    return DatabaseService.isLocalChapter(chapterUrl);
  }
}