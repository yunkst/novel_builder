import '../../models/novel.dart';
import '../../services/database_service.dart';

/// 书架管理器
/// 负责书架状态管理和缓存操作
class BookshelfManager {
  final DatabaseService _databaseService;

  BookshelfManager({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;

  /// 检查小说是否在书架中
  Future<bool> isInBookshelf(String novelUrl) async {
    return await _databaseService.isInBookshelf(novelUrl);
  }

  /// 添加小说到书架
  Future<void> addToBookshelf(Novel novel) async {
    await _databaseService.addToBookshelf(novel);
  }

  /// 从书架移除小说
  Future<void> removeFromBookshelf(String novelUrl) async {
    await _databaseService.removeFromBookshelf(novelUrl);
  }

  /// 清除小说的所有缓存
  Future<void> clearNovelCache(String novelUrl) async {
    await _databaseService.clearNovelCache(novelUrl);
  }
}
