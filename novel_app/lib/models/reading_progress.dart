import 'dart:convert';

/// TTS朗读进度模型
class ReadingProgress {
  /// 小说URL
  final String novelUrl;

  /// 小说标题
  final String novelTitle;

  /// 章节URL
  final String chapterUrl;

  /// 章节标题
  final String chapterTitle;

  /// 段落索引
  final int paragraphIndex;

  /// 语速
  final double speechRate;

  /// 音调
  final double pitch;

  /// 保存时间戳
  final DateTime timestamp;

  const ReadingProgress({
    required this.novelUrl,
    required this.novelTitle,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.paragraphIndex,
    required this.speechRate,
    required this.pitch,
    required this.timestamp,
  });

  /// 从JSON创建
  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      novelUrl: json['novelUrl'] as String,
      novelTitle: json['novelTitle'] as String,
      chapterUrl: json['chapterUrl'] as String,
      chapterTitle: json['chapterTitle'] as String,
      paragraphIndex: json['paragraphIndex'] as int,
      speechRate: (json['speechRate'] as num).toDouble(),
      pitch: (json['pitch'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// 从JSON字符串创建
  static ReadingProgress? fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ReadingProgress.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'novelUrl': novelUrl,
      'novelTitle': novelTitle,
      'chapterUrl': chapterUrl,
      'chapterTitle': chapterTitle,
      'paragraphIndex': paragraphIndex,
      'speechRate': speechRate,
      'pitch': pitch,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 检查进度是否过期
  bool isExpired({int days = 7}) {
    return DateTime.now().difference(timestamp).inDays > days;
  }

  /// 获取位置文本描述
  String get positionText => '$chapterTitle (第${paragraphIndex + 1}段)';

  /// 复制并修改部分字段
  ReadingProgress copyWith({
    String? novelUrl,
    String? novelTitle,
    String? chapterUrl,
    String? chapterTitle,
    int? paragraphIndex,
    double? speechRate,
    double? pitch,
    DateTime? timestamp,
  }) {
    return ReadingProgress(
      novelUrl: novelUrl ?? this.novelUrl,
      novelTitle: novelTitle ?? this.novelTitle,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'ReadingProgress(novel: $novelTitle, chapter: $chapterTitle, paragraph: $paragraphIndex)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ReadingProgress &&
        other.novelUrl == novelUrl &&
        other.chapterUrl == chapterUrl &&
        other.paragraphIndex == paragraphIndex;
  }

  @override
  int get hashCode {
    return novelUrl.hashCode ^ chapterUrl.hashCode ^ paragraphIndex.hashCode;
  }
}
