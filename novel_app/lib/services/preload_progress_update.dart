/// 预加载进度更新事件
///
/// 用于在 PreloadService 和 UI 层之间传递预加载进度信息
class PreloadProgressUpdate {
  /// 小说URL
  final String novelUrl;

  /// 章节URL（可选，用于精确更新单个章节的缓存状态）
  final String? chapterUrl;

  /// 是否正在预加载
  final bool isPreloading;

  /// 已缓存章节数
  final int cachedChapters;

  /// 总章节数（估算值，队列长度 + 已缓存数）
  final int totalChapters;

  /// 时间戳
  final DateTime timestamp;

  /// 创建预加载进度更新事件
  PreloadProgressUpdate({
    required this.novelUrl,
    this.chapterUrl,
    required this.isPreloading,
    required this.cachedChapters,
    required this.totalChapters,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'PreloadProgressUpdate(novelUrl: $novelUrl, '
        'chapterUrl: $chapterUrl, '
        'isPreloading: $isPreloading, '
        'cachedChapters: $cachedChapters, '
        'totalChapters: $totalChapters, '
        'timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PreloadProgressUpdate &&
        other.novelUrl == novelUrl &&
        other.chapterUrl == chapterUrl &&
        other.isPreloading == isPreloading &&
        other.cachedChapters == cachedChapters &&
        other.totalChapters == totalChapters;
  }

  @override
  int get hashCode {
    return novelUrl.hashCode ^
        (chapterUrl?.hashCode ?? 0) ^
        isPreloading.hashCode ^
        cachedChapters.hashCode ^
        totalChapters.hashCode;
  }
}
