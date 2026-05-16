/// 章节内容获取结果
///
/// 包含内容文本和来源标识，用于智能速率控制。
class ChapterContentResult {
  final String content;
  final bool fromCache;

  const ChapterContentResult({
    required this.content,
    this.fromCache = false,
  });
}