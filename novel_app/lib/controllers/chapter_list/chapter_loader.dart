import '../../models/chapter.dart';
import '../../services/api_service_wrapper.dart';
import '../../core/interfaces/repositories/i_chapter_repository.dart';
import '../../core/interfaces/repositories/i_novel_repository.dart';

/// 章节加载器
/// 负责章节列表的加载、刷新和缓存管理
class ChapterLoader {
  final ApiServiceWrapper _api;
  final IChapterRepository _chapterRepo;
  final INovelRepository _novelRepo;

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
    // 对于本地创建的小说，直接从数据库加载用户创建的章节
    if (novelUrl.startsWith('custom://')) {
      return await _chapterRepo.getCachedNovelChapters(novelUrl);
    }

    // 先尝试从缓存加载
    final cachedChapters = await _chapterRepo.getCachedNovelChapters(novelUrl);

    if (cachedChapters.isNotEmpty && !forceRefresh) {
      // 有缓存且不强制刷新时，直接返回缓存
      return cachedChapters;
    }

    if (cachedChapters.isNotEmpty && forceRefresh) {
      // 有缓存但需要刷新时，先返回缓存，调用方负责后台更新
      return cachedChapters;
    }

    // 没有缓存时，从后端获取
    return await refreshFromBackend(novelUrl);
  }

  /// 从后端刷新章节列表
  /// [novelUrl] 小说URL
  /// 返回刷新后的章节列表
  Future<List<Chapter>> refreshFromBackend(String novelUrl) async {
    // 对于本地创建的小说，直接从数据库获取用户创建的章节
    if (novelUrl.startsWith('custom://')) {
      return await _chapterRepo.getCachedNovelChapters(novelUrl);
    }

    // 从后端获取最新章节列表
    final chapters = await _api.getChapters(novelUrl);

    if (chapters.isNotEmpty) {
      // 缓存章节列表
      await _chapterRepo.cacheNovelChapters(novelUrl, chapters);

      // 重新从数据库获取合并后的章节列表（包括用户插入的章节）
      return await _chapterRepo.getCachedNovelChapters(novelUrl);
    }

    return [];
  }

  /// 加载上次阅读的章节索引
  /// [novelUrl] 小说URL
  /// 返回上次阅读的章节索引
  Future<int> loadLastReadChapter(String novelUrl) async {
    return await _novelRepo.getLastReadChapter(novelUrl);
  }
}
