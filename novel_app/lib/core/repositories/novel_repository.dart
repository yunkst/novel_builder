import '../../models/novel.dart';
import '../utils/result.dart';

/// 小说数据访问抽象接口
abstract class NovelRepository {
  /// 获取书架列表
  Future<Result<List<Novel>>> getBookshelf();

  /// 添加小说到书架
  Future<Result<void>> addToBookshelf(Novel novel);

  /// 从书架移除小说
  Future<Result<void>> removeFromBookshelf(String novelUrl);

  /// 检查小说是否在书架中
  Future<Result<bool>> isInBookshelf(String novelUrl);

  /// 更新小说元数据
  Future<Result<void>> updateNovelMetadata(Novel novel);

  /// 搜索小说
  Future<Result<List<Novel>>> searchNovels(String keyword);

  /// 获取小说详细信息
  Future<Result<Novel?>> getNovelDetails(String novelUrl);

  /// 清理书架缓存
  Future<Result<void>> clearBookshelfCache();
}