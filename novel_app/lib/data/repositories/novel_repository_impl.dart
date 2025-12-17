import '../../models/novel.dart';
import '../../services/database_service.dart';
import '../../services/api_service_wrapper.dart';
import '../../core/repositories/novel_repository.dart';
import '../../core/utils/result.dart';
import '../../core/failures/database_failure.dart';
import '../../core/failures/network_failure.dart';
import '../../core/utils/error_handler.dart';

/// 小说Repository实现
class NovelRepositoryImpl implements NovelRepository {
  final DatabaseService _databaseService;
  final ApiServiceWrapper _apiService;

  NovelRepositoryImpl({
    required DatabaseService databaseService,
    required ApiServiceWrapper apiService,
  }) : _databaseService = databaseService,
       _apiService = apiService;

  @override
  Future<Result<List<Novel>>> getBookshelf() async {
    try {
      final novels = await _databaseService.getBookshelf();
      return Result.success(novels);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to get bookshelf: $e'),
        'NovelRepository.getBookshelf',
      );
      return Result.failure(DatabaseFailure('获取书架失败: $e'));
    }
  }

  @override
  Future<Result<void>> addToBookshelf(Novel novel) async {
    try {
      await _databaseService.addToBookshelf(novel);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to add novel to bookshelf: $e'),
        'NovelRepository.addToBookshelf',
      );
      return Result.failure(DatabaseFailure('添加小说到书架失败: $e'));
    }
  }

  @override
  Future<Result<void>> removeFromBookshelf(String novelUrl) async {
    try {
      await _databaseService.removeFromBookshelf(novelUrl);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to remove novel from bookshelf: $e'),
        'NovelRepository.removeFromBookshelf',
      );
      return Result.failure(DatabaseFailure('从书架移除小说失败: $e'));
    }
  }

  @override
  Future<Result<bool>> isInBookshelf(String novelUrl) async {
    try {
      final isInBookshelf = await _databaseService.isInBookshelf(novelUrl);
      return Result.success(isInBookshelf);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to check if novel is in bookshelf: $e'),
        'NovelRepository.isInBookshelf',
      );
      return Result.failure(DatabaseFailure('检查小说是否在书架中失败: $e'));
    }
  }

  @override
  Future<Result<void>> updateNovelMetadata(Novel novel) async {
    try {
      await _databaseService.updateNovelInBookshelf(novel);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to update novel metadata: $e'),
        'NovelRepository.updateNovelMetadata',
      );
      return Result.failure(DatabaseFailure('更新小说元数据失败: $e'));
    }
  }

  @override
  Future<Result<List<Novel>>> searchNovels(String keyword) async {
    try {
      // 对于自定义小说URL，不进行网络搜索
      if (keyword.startsWith('custom://')) {
        return Result.success([]);
      }

      await _apiService.init();
      final novels = await _apiService.searchNovels(keyword);
      return Result.success(novels);
    } catch (e) {
      ErrorHandler.logError(
        NetworkFailure('Failed to search novels: $e'),
        'NovelRepository.searchNovels',
      );
      return Result.failure(NetworkFailure('搜索小说失败: $e'));
    }
  }

  @override
  Future<Result<Novel?>> getNovelDetails(String novelUrl) async {
    try {
      // 对于自定义小说，直接返回空
      if (novelUrl.startsWith('custom://')) {
        return Result.success(null);
      }

      // 先从数据库查找
      final bookshelf = await _databaseService.getBookshelf();
      final cachedNovel = bookshelf.firstWhere(
        (novel) => novel.url == novelUrl,
        orElse: () => Novel(
          title: '',
          author: '',
          url: novelUrl,
          isInBookshelf: false,
        ),
      );

      // 如果缓存中有详细信息，直接返回
      if (cachedNovel.title.isNotEmpty) {
        return Result.success(cachedNovel);
      }

      // 如果是网络小说，尝试从API获取
      await _apiService.init();
      // 这里需要根据具体的API实现获取小说详情
      // 暂时返回缓存的简化版本
      return Result.success(cachedNovel);
    } catch (e) {
      ErrorHandler.logError(
        NetworkFailure('Failed to get novel details: $e'),
        'NovelRepository.getNovelDetails',
      );
      return Result.failure(NetworkFailure('获取小说详情失败: $e'));
    }
  }

  @override
  Future<Result<void>> clearBookshelfCache() async {
    try {
      // 清理书架缓存（保留阅读进度）
      await _databaseService.clearBookshelfCache();
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        DatabaseFailure('Failed to clear bookshelf cache: $e'),
        'NovelRepository.clearBookshelfCache',
      );
      return Result.failure(DatabaseFailure('清理书架缓存失败: $e'));
    }
  }
}