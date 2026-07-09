/// OutlineReadTracker — 大纲 read-before-write 跨工具共享状态
///
/// 抽离自原 ToolExecutor._readOutlineUrls。get_outline / update_outline /
/// write_outline 三个工具共享此状态：
/// - get_outline 读成功 → markRead(novelUrl)
/// - update_outline / write_outline 写之前 → checkHasRead 校验，写后 markRead
///
/// 生命周期 = 一个 ToolExecutor 实例 ≈ 一次用户消息触发的整个 Agent 循环
/// （WritingScenario 每次 sendMessage 新建，其 _executor 随之重建）。
library;

/// 大纲 read-before-write 状态跟踪器
class OutlineReadTracker {
  final Set<String> _readOutlineUrls = {};

  /// 标记某小说的大纲在本循环内已读
  void markRead(String novelUrl) {
    _readOutlineUrls.add(novelUrl);
  }

  /// 检查某小说的大纲是否已读
  bool hasRead(String novelUrl) => _readOutlineUrls.contains(novelUrl);
}
