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

  /// 更新小说书名
  ///
  /// [novelUrl] 小说的URL
  /// [newTitle] 新的书名
  /// 返回受影响的行数
  Future<int> updateTitle(String novelUrl, String newTitle);

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

  /// 根据 title 查找小说
  ///
  /// [title] 小说标题
  /// 返回小说对象，如果不存在则返回null
  Future<Novel?> getNovelByTitle(String title);

  /// 创建新小说（用于同步下载时创建不存在的书）
  ///
  /// 返回创建后的小说对象
  Future<Novel> createNovel({
    required String title,
    required String author,
    String? description,
    String? coverUrl,
    String? backgroundSetting,
  });

  // ========== ID-based 查询方法（Agent 工具用） ==========

  /// 根据 ID 查询小说
  ///
  /// [id] bookshelf.id
  /// 返回 Novel 对象，不存在则返回 null
  Future<Novel?> getNovelById(int id);

  /// 根据 ID 获取小说 URL（内部 ID→URL 解析用）
  ///
  /// [id] bookshelf.id
  /// 返回小说 URL，不存在则返回 null
  Future<String?> getNovelUrlById(int id);

  /// 根据 ID 检查小说是否存在
  ///
  /// [id] bookshelf.id
  /// 返回是否存在的布尔值
  Future<bool> novelExistsById(int id);

  /// 根据 ID 更新小说背景设定（解析 URL 后委托 updateBackgroundSetting）
  ///
  /// [id] bookshelf.id
  /// [setting] 背景设定内容
  /// 返回受影响的行数，ID 不存在则返回 0
  Future<int> updateBackgroundSettingById(int id, String? setting);
}
