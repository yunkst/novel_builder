/// AI伴读设置数据模型
///
/// 用于存储每本小说的AI伴读配置，包括自动伴读和信息提示开关
class AiAccompanimentSettings {
  /// 是否启用自动伴读
  final bool autoEnabled;

  /// 是否启用信息提示
  final bool infoNotificationEnabled;

  const AiAccompanimentSettings({
    this.autoEnabled = false,
    this.infoNotificationEnabled = false,
  });

  /// 转换为JSON格式（用于数据库存储）
  Map<String, dynamic> toJson() {
    return {
      'autoEnabled': autoEnabled,
      'infoNotificationEnabled': infoNotificationEnabled,
    };
  }

  /// 从JSON格式创建实例
  factory AiAccompanimentSettings.fromJson(Map<String, dynamic> json) {
    return AiAccompanimentSettings(
      autoEnabled: json['autoEnabled'] as bool? ?? false,
      infoNotificationEnabled:
          json['infoNotificationEnabled'] as bool? ?? false,
    );
  }

  /// 创建副本并可选择性地修改字段
  AiAccompanimentSettings copyWith({
    bool? autoEnabled,
    bool? infoNotificationEnabled,
  }) {
    return AiAccompanimentSettings(
      autoEnabled: autoEnabled ?? this.autoEnabled,
      infoNotificationEnabled:
          infoNotificationEnabled ?? this.infoNotificationEnabled,
    );
  }

  @override
  String toString() {
    return 'AiAccompanimentSettings(autoEnabled: $autoEnabled, '
        'infoNotificationEnabled: $infoNotificationEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AiAccompanimentSettings &&
        other.autoEnabled == autoEnabled &&
        other.infoNotificationEnabled == infoNotificationEnabled;
  }

  @override
  int get hashCode {
    return autoEnabled.hashCode ^ infoNotificationEnabled.hashCode;
  }
}
