/// 媒体标记解析工具类
/// 支持解析格式：[!插图!](taskId), [!视频!](videoId) 等
class MediaMarkupParser {
  /// 正则表达式匹配媒体标记
  /// 格式：[!媒体类型!](媒体ID)
  static final RegExp _mediaMarkupRegex = RegExp(r'\[!([^!]+)!\]\(([^)]+)\)');

  /// 检查字符串是否为媒体标记
  static bool isMediaMarkup(String text) {
    return _mediaMarkupRegex.hasMatch(text);
  }
}
