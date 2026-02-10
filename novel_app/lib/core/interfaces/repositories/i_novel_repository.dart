import '../../../models/novel.dart';
import '../../../models/ai_accompaniment_settings.dart';

/// 小说数据仓库接口
///
/// 负责小说元数据、阅读进度和AI伴读设置的数据访问操作
abstract class INovelRepository {
  /// 添加小说到书架
  ///
  /// [novel] 要添加的小说对象
  /// 返回新插入记录的ID
  Future<int> addToBookshelf(Novel novel);

  /// 从书架移除小说
  ///
  /// [novelUrl] 小说的URL
  /// 返回受影响的行数
  Future<int> removeFromBookshelf(String novelUrl);

  /// 获取所有小说
  ///
  /// 返回小说列表，按最后阅读时间和添加时间降序排列
  Future<List<Novel>> getNovels();

  /// 检查小说是否在书架中
  ///
  /// [novelUrl] 小说的URL
  /// 返回是否在书架中
  Future<bool> isInBookshelf(String novelUrl);

  /// 更新最后阅读章节
  ///
  /// [novelUrl] 小说的URL
  /// [chapterIndex] 章节索引
  /// 返回受影响的行数
  Future<int> updateLastReadChapter(String novelUrl, int chapterIndex);

  /// 更新小说背景设定
  ///
  /// [novelUrl] 小说的URL
  /// [backgroundSetting] 背景设定内容
  /// 返回受影响的行数
  Future<int> updateBackgroundSetting(
      String novelUrl, String? backgroundSetting);

  /// 获取小说背景设定
  ///
  /// [novelUrl] 小说的URL
  /// 返回背景设定内容，如果不存在则返回null
  Future<String?> getBackgroundSetting(String novelUrl);

  /// 获取上次阅读的章节索引
  ///
  /// [novelUrl] 小说的URL
  /// 返回章节索引，如果不存在则返回0
  Future<int> getLastReadChapter(String novelUrl);

  /// 获取小说的AI伴读设置
  ///
  /// [novelUrl] 小说的URL
  /// 返回AI伴读设置对象，如果不存在则返回默认设置
  Future<AiAccompanimentSettings> getAiAccompanimentSettings(String novelUrl);

  /// 更新小说的AI伴读设置
  ///
  /// [novelUrl] 小说的URL
  /// [settings] AI伴读设置对象
  /// 返回受影响的行数
  Future<int> updateAiAccompanimentSettings(
      String novelUrl, AiAccompanimentSettings settings);
}
