/// 流式内容处理配置
/// 用于统一管理不同类型的流式内容生成和处理行为
class StreamConfig {
  /// 流式类型
  final StreamType type;

  /// Dify API 输入参数
  final Map<String, dynamic> inputs;

  /// 是否实时显示流式内容
  final bool showRealTime;

  /// 是否自动滚动到最新内容
  final bool autoScroll;

  /// 滚动动画时长
  final Duration scrollDuration;

  /// 生成时是否禁用编辑
  final bool disableEditWhileGenerating;

  /// 生成时背景色
  final String? generatingBackgroundColor;

  /// 生成时文字颜色
  final String? generatingTextColor;

  /// 自定义生成提示文本
  final String? generatingHint;

  /// 最大行数限制
  final int? maxLines;

  /// 最小行数限制
  final int? minLines;

  const StreamConfig({
    required this.type,
    required this.inputs,
    this.showRealTime = true,
    this.autoScroll = true,
    this.scrollDuration = const Duration(milliseconds: 100),
    this.disableEditWhileGenerating = true,
    this.generatingBackgroundColor,
    this.generatingTextColor,
    this.generatingHint,
    this.maxLines,
    this.minLines,
  });

  /// 创建特写功能配置
  factory StreamConfig.closeUp({
    required Map<String, dynamic> inputs,
    String? generatingHint,
  }) {
    return StreamConfig(
      type: StreamType.closeUp,
      inputs: inputs,
      generatingHint: generatingHint ?? 'AI正在生成特写内容，请稍候...',
      maxLines: 8,
      minLines: 4,
    );
  }

  /// 创建场景描写功能配置
  factory StreamConfig.sceneDescription({
    required Map<String, dynamic> inputs,
    String? generatingHint,
  }) {
    return StreamConfig(
      type: StreamType.sceneDescription,
      inputs: inputs,
      generatingBackgroundColor: '#000000',
      generatingTextColor: '#FFFFFF',
      generatingHint: generatingHint ?? 'AI正在生成场景描写，请稍候...',
      maxLines: 4,
      minLines: 2,
    );
  }

  /// 创建自定义配置
  factory StreamConfig.custom({
    required Map<String, dynamic> inputs,
    bool showRealTime = true,
    bool autoScroll = true,
    Duration scrollDuration = const Duration(milliseconds: 100),
    bool disableEditWhileGenerating = true,
    String? generatingBackgroundColor,
    String? generatingTextColor,
    String? generatingHint,
    int? maxLines,
    int? minLines,
  }) {
    return StreamConfig(
      type: StreamType.custom,
      inputs: inputs,
      showRealTime: showRealTime,
      autoScroll: autoScroll,
      scrollDuration: scrollDuration,
      disableEditWhileGenerating: disableEditWhileGenerating,
      generatingBackgroundColor: generatingBackgroundColor,
      generatingTextColor: generatingTextColor,
      generatingHint: generatingHint,
      maxLines: maxLines,
      minLines: minLines,
    );
  }

  /// 复制配置并修改部分属性
  StreamConfig copyWith({
    StreamType? type,
    Map<String, dynamic>? inputs,
    bool? showRealTime,
    bool? autoScroll,
    Duration? scrollDuration,
    bool? disableEditWhileGenerating,
    String? generatingBackgroundColor,
    String? generatingTextColor,
    String? generatingHint,
    int? maxLines,
    int? minLines,
  }) {
    return StreamConfig(
      type: type ?? this.type,
      inputs: inputs ?? this.inputs,
      showRealTime: showRealTime ?? this.showRealTime,
      autoScroll: autoScroll ?? this.autoScroll,
      scrollDuration: scrollDuration ?? this.scrollDuration,
      disableEditWhileGenerating: disableEditWhileGenerating ?? this.disableEditWhileGenerating,
      generatingBackgroundColor: generatingBackgroundColor ?? this.generatingBackgroundColor,
      generatingTextColor: generatingTextColor ?? this.generatingTextColor,
      generatingHint: generatingHint ?? this.generatingHint,
      maxLines: maxLines ?? this.maxLines,
      minLines: minLines ?? this.minLines,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreamConfig &&
        other.type == type &&
        other.showRealTime == showRealTime &&
        other.autoScroll == autoScroll &&
        other.scrollDuration == scrollDuration &&
        other.disableEditWhileGenerating == disableEditWhileGenerating &&
        other.generatingBackgroundColor == generatingBackgroundColor &&
        other.generatingTextColor == generatingTextColor &&
        other.generatingHint == generatingHint &&
        other.maxLines == maxLines &&
        other.minLines == minLines;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        showRealTime.hashCode ^
        autoScroll.hashCode ^
        scrollDuration.hashCode ^
        disableEditWhileGenerating.hashCode ^
        generatingBackgroundColor.hashCode ^
        generatingTextColor.hashCode ^
        generatingHint.hashCode ^
        maxLines.hashCode ^
        minLines.hashCode;
  }

  @override
  String toString() {
    return 'StreamConfig(type: $type, showRealTime: $showRealTime, autoScroll: $autoScroll)';
  }
}

/// 流式类型枚举
enum StreamType {
  /// 特写内容生成
  closeUp,

  /// 场景描写生成
  sceneDescription,

  /// 自定义类型
  custom,
}

/// 流式状态枚举
enum StreamStatus {
  /// 空闲状态
  idle,

  /// 连接中
  connecting,

  /// 流式传输中
  streaming,

  /// 已完成
  completed,

  /// 生成错误
  error,
}

/// 场景描写流式生成状态
enum SceneDescriptionState {
  idle,        // 空闲状态
  generating,  // 生成中
  completed,   // 已完成
  error        // 生成错误
}