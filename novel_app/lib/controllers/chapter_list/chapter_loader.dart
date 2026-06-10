import '../../models/chapter.dart';
import '../../services/api_service_wrapper.dart';
import '../../services/logger_service.dart';
import '../../core/interfaces/repositories/i_chapter_repository.dart';
import '../../core/interfaces/repositories/i_novel_repository.dart';

/// 章节加载器
/// 负责章节列表的加载、刷新和缓存管理
class ChapterLoader {
  final ApiServiceWrapper _api;
  final IChapterRepository _chapterRepo;
  final INovelRepository _novelRepo;
  final _log = LoggerService.instance;

  ChapterLoader({
    required ApiServiceWrapper api,
    required IChapterRepository chapterRepository,
    required INovelRepository novelRepository,
  })  : _api = api,
        _chapterRepo = chapterRepository,
        _novelRepo = novelRepository;

  /// 初始化API服务
  Future<void> initApi() async {
    await _api.init();
  }

  /// 加载章节列表
  /// [novelUrl] 小说URL
  /// [forceRefresh] 是否强制刷新
  /// 返回章节列表
  Future<List<Chapter>> loadChapters(
    String novelUrl, {
    bool forceRefresh = false,
  }) async {
    _log.d(
      '加载章节列表: $novelUrl, forceRefresh=$forceRefresh',
      category: LogCategory.ui,
      tags: ['chapter-list', 'load'],
    );

    try {
      // 对于本地创建的小说，直接从数据库加载用户创建的章节
      if (novelUrl.startsWith('custom://')) {
        final chapters = await _chapterRepo.getCachedNovelChapters(novelUrl);
        _log.i(
          '本地小说章节加载完成: ${chapters.length}章',
          category: LogCategory.database,
          tags: ['chapter', 'load'],
        );
        return chapters;
      }

      // 先尝试从缓存加载
      final cachedChapters = await _chapterRepo.getCachedNovelChapters(novelUrl);

      if (cachedChapters.isNotEmpty && !forceRefresh) {
        // 有缓存且不强制刷新时，直接返回缓存
        _log.i(
          '从缓存加载章节列表: ${cachedChapters.length}章',
          category: LogCategory.database,
          tags: ['chapter', 'load', 'cache-hit'],
        );
        return cachedChapters;
      }

      if (cachedChapters.isNotEmpty && forceRefresh) {
        // 有缓存但需要刷新时，先返回缓存，调用方负责后台更新
        _log.i(
          '从缓存加载章节列表(待刷新): ${cachedChapters.length}章',
          category: LogCategory.database,
          tags: ['chapter', 'load', 'cache-hit', 'pending-refresh'],
        );
        return cachedChapters;
      }

      // 没有缓存时，从后端获取
      _log.d(
        '缓存未命中，从后端获取章节列表',
        category: LogCategory.network,
        tags: ['chapter-list', 'load', 'backend'],
      );
      return await refreshFromBackend(novelUrl, forceRefresh: forceRefresh);
    } catch (e, st) {
      _log.e(
        '加载章节列表失败: $novelUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.ui,
        tags: ['chapter-list', 'load'],
      );
      rethrow;
    }
  }

  /// 从后端刷新章节列表
  /// [novelUrl] 小说URL
  /// [forceRefresh] 是否强制刷新
  /// 返回刷新后的章节列表
  Future<List<Chapter>> refreshFromBackend(String novelUrl,
      {bool forceRefresh = false}) async {
    _log.d(
      '从后端刷新章节列表: $novelUrl',
      category: LogCategory.network,
      tags: ['chapter-list', 'refresh'],
    );

    try {
      // 对于本地创建的小说，直接从数据库获取用户创建的章节
      if (novelUrl.startsWith('custom://')) {
        return await _chapterRepo.getCachedNovelChapters(novelUrl);
      }

      // 从后端获取最新章节列表
      final chapters = await _api.getChapters(novelUrl, forceRefresh: forceRefresh);

      if (chapters.isNotEmpty) {
        // 缓存章节列表
        await _chapterRepo.cacheNovelChapters(novelUrl, chapters);
        _log.i(
          '章节列表缓存在数据库: ${chapters.length}章',
          category: LogCategory.database,
          tags: ['chapter', 'cache'],
        );

        // 重新从数据库获取合并后的章节列表（包括用户插入的章节）
        final mergedChapters = await _chapterRepo.getCachedNovelChapters(novelUrl);
        _log.i(
          '从后端刷新章节列表完成: ${mergedChapters.length}章(含用户章节)',
          category: LogCategory.network,
          tags: ['chapter-list', 'refresh'],
        );
        return mergedChapters;
      }

      _log.w(
        '从后端获取的章节列表为空: $novelUrl',
        category: LogCategory.network,
        tags: ['chapter-list', 'refresh', 'empty'],
      );
      return [];
    } catch (e, st) {
      _log.e(
        '从后端刷新章节列表失败: $novelUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.network,
        tags: ['chapter-list', 'refresh'],
      );
      rethrow;
    }
  }

  /// 加载上次阅读的章节索引
  /// [novelUrl] 小说URL
  /// 返回上次阅读的章节索引
  Future<int> loadLastReadChapter(String novelUrl) async {
    try {
      return await _novelRepo.getLastReadChapter(novelUrl);
    } catch (e, st) {
      _log.e(
        '加载上次阅读章节索引失败: $novelUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'last-read'],
      );
      rethrow;
    }
  }
}
