/// 媒体标记解析工具类
/// 支持解析格式：[!插图!](taskId), [!视频!](videoId) 等
class MediaMarkupParser {
  /// 正则表达式匹配媒体标记
  /// 格式：[!媒体类型!](媒体ID)
  static final RegExp _mediaMarkupRegex = RegExp(r'\[!([^!]+)!\]\(([^)]+)\)');

  /// 解析文本中的所有媒体标记
  /// 返回：(媒体类型, 媒体ID, 完整标记, 起始位置, 结束位置) 列表
  static List<MediaMarkup> parseMediaMarkup(String text) {
    final matches = _mediaMarkupRegex.allMatches(text);
    return matches.map((match) {
      return MediaMarkup(
        type: match.group(1)!,
        id: match.group(2)!,
        fullMarkup: match.group(0)!,
        start: match.start,
        end: match.end,
      );
    }).toList();
  }

  /// 检查字符串是否为媒体标记
  static bool isMediaMarkup(String text) {
    return _mediaMarkupRegex.hasMatch(text);
  }

  /// 获取媒体标记的类型
  static String getMarkupType(String markup) {
    final match = _mediaMarkupRegex.firstMatch(markup);
    return match?.group(1) ?? '';
  }

  /// 获取媒体标记的ID
  static String getMarkupId(String markup) {
    final match = _mediaMarkupRegex.firstMatch(markup);
    return match?.group(2) ?? '';
  }

  /// 创建媒体标记
  static String createMediaMarkup(String type, String id) {
    return '[!$type!]($id)';
  }

  /// 创建插图标记
  static String createIllustrationMarkup(String taskId) {
    return '[!插图!]($taskId)';
  }

  /// 创建视频标记
  static String createVideoMarkup(String videoId) {
    return '[!视频!]($videoId)';
  }

  /// 从文本中移除所有媒体标记
  static String removeMediaMarkup(String text) {
    return text.replaceAll(_mediaMarkupRegex, '');
  }

  /// 替换文本中的媒体标记
  static String replaceMediaMarkup(
    String text,
    String Function(MediaMarkup markup) replacer,
  ) {
    final markups = parseMediaMarkup(text);
    String result = text;

    // 从后往前替换，避免位置偏移
    for (final markup in markups.reversed) {
      final replacement = replacer(markup);
      result = result.replaceRange(markup.start, markup.end, replacement);
    }

    return result;
  }

  /// 统计文本中的媒体标记数量
  static int countMediaMarkup(String text, {String? type}) {
    final markups = parseMediaMarkup(text);
    if (type == null) {
      return markups.length;
    }
    return markups.where((m) => m.type == type).length;
  }

  /// 检查文本是否包含指定类型的媒体标记
  static bool containsMediaType(String text, String type) {
    return countMediaMarkup(text, type: type) > 0;
  }
}

/// 媒体标记数据模型
class MediaMarkup {
  final String type;      // 媒体类型：插图、视频、音频等
  final String id;        // 媒体ID：taskId、videoId等
  final String fullMarkup; // 完整标记文本
  final int start;        // 在原文中的起始位置
  final int end;          // 在原文中的结束位置

  const MediaMarkup({
    required this.type,
    required this.id,
    required this.fullMarkup,
    required this.start,
    required this.end,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaMarkup &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id;

  @override
  int get hashCode => type.hashCode ^ id.hashCode;

  @override
  String toString() => 'MediaMarkup(type: $type, id: $id)';

  /// 是否为插图标记
  bool get isIllustration => type == '插图';

  /// 是否为视频标记
  bool get isVideo => type == '视频';

  /// 是否为音频标记
  bool get isAudio => type == '音频';

  /// 复制并修改属性
  MediaMarkup copyWith({
    String? type,
    String? id,
    String? fullMarkup,
    int? start,
    int? end,
  }) {
    return MediaMarkup(
      type: type ?? this.type,
      id: id ?? this.id,
      fullMarkup: fullMarkup ?? this.fullMarkup,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}