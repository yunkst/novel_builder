/// TTS定时配置
///
/// 用于管理TTS播放器的定时结束功能
class TtsTimerConfig {
  /// 是否启用定时
  bool enabled;

  /// 读多少章后停止（1-99）
  int chapterCount;

  /// 起始章节索引（用于相对计数）
  int startChapterIndex;

  TtsTimerConfig({
    this.enabled = false,
    this.chapterCount = 0,
    this.startChapterIndex = 0,
  });

  /// 计算已完成章节数（相对计数）
  ///
  /// [currentChapterIndex] 当前章节索引
  /// 返回从起始章节到当前章节已完成的章节数
  int getCompletedChapters(int currentChapterIndex) {
    if (!enabled) return 0;
    return currentChapterIndex - startChapterIndex + 1;
  }

  /// 检查是否达到定时目标
  ///
  /// [currentChapterIndex] 当前章节索引
  /// 返回true表示已达到设置的章节数
  bool isTargetReached(int currentChapterIndex) {
    if (!enabled) return false;
    final completed = getCompletedChapters(currentChapterIndex);
    return completed >= chapterCount;
  }

  /// 复制配置
  TtsTimerConfig copyWith({
    bool? enabled,
    int? chapterCount,
    int? startChapterIndex,
  }) {
    return TtsTimerConfig(
      enabled: enabled ?? this.enabled,
      chapterCount: chapterCount ?? this.chapterCount,
      startChapterIndex: startChapterIndex ?? this.startChapterIndex,
    );
  }

  /// 重置定时配置
  void reset() {
    enabled = false;
    chapterCount = 0;
    startChapterIndex = 0;
  }

  @override
  String toString() {
    return 'TtsTimerConfig(enabled: $enabled, chapterCount: $chapterCount, startChapterIndex: $startChapterIndex)';
  }

  /// 转换为JSON（用于未来持久化扩展）
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'chapterCount': chapterCount,
      'startChapterIndex': startChapterIndex,
    };
  }

  /// 从JSON创建（用于未来持久化扩展）
  factory TtsTimerConfig.fromJson(Map<String, dynamic> json) {
    return TtsTimerConfig(
      enabled: json['enabled'] as bool? ?? false,
      chapterCount: json['chapterCount'] as int? ?? 0,
      startChapterIndex: json['startChapterIndex'] as int? ?? 0,
    );
  }
}
