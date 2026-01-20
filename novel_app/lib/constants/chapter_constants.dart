/// 章节相关常量定义
///
/// 统一管理章节列表、缓存和上下文相关的所有魔法数字
class ChapterConstants {
  // 私有构造函数，防止实例化
  ChapterConstants._();

  /// 章节上下文数量
  ///
  /// 用于AI生成章节时获取前N章作为上下文
  /// 统一使用5章，避免之前的4章和5章不一致问题
  static const int contextChapterCount = 5;

  /// 滚动位置比例
  ///
  /// 滚动到目标章节时，章节在视口中的位置比例
  /// 0.25 表示章节顶部在视口顶部向下25%的位置
  static const double scrollPositionRatio = 0.25;

  /// 列表项高度
  ///
  /// ListTile的默认高度，用于计算滚动位置
  static const double listItemHeight = 56.0;

  /// 最大内存缓存章节数
  ///
  /// DatabaseService中内存缓存的最大章节数量
  static const int maxMemoryCacheSize = 1000;

  /// 用户章节URL前缀
  ///
  /// 用户插入的章节使用此URL前缀
  static const String userChapterUrlPrefix = 'user_chapter_';

  /// 每页章节数量
  ///
  /// 章节列表分页显示时，每页显示的章节数量
  static const int chaptersPerPage = 100;
}
