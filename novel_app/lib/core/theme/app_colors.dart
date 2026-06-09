/// 应用自定义颜色主题扩展
///
/// 通过 [ThemeData.extensions] 注入到主题中，提供品牌色、语义色等
/// Material 3 [ColorScheme] 之外的扩展颜色。
///
/// 使用方式：
/// ```dart
/// final colors = context.appColors; // BuildContext 扩展
/// Container(color: colors.hermesAccent);
/// ```
library;

import 'package:flutter/material.dart';

/// 应用自定义颜色主题扩展
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // ─── Hermes 品牌色 ────────────────────────────────────────────
  /// Hermes 渐变起始色（紫蓝 Indigo-500）
  final Color hermesBrandStart;

  /// Hermes 渐变结束色（紫色 Violet-500）
  final Color hermesBrandEnd;

  /// Hermes 用户气泡/发送按钮主色
  final Color hermesAccent;

  /// Hermes 头部主文字/图标色
  final Color hermesOnBrand;

  /// Hermes 头部次要图标色
  final Color hermesOnBrandMuted;

  // ─── TTS ──────────────────────────────────────────────────────
  /// TTS 加载图标色（Material Blue 500）
  final Color ttsAccent;

  /// TTS 提示文字色（Material Grey 500）
  final Color ttsHint;

  // ─── 语义色（Toast/状态）─────────────────────────────────────
  final Color success;
  final Color error;
  final Color warning;
  final Color info;
  final Color neutral;

  /// 语义色上的文字色
  final Color onSemantic;

  // ─── 语义容器色（卡片背景/边框/次级文字）───────────────────────
  /// 错误容器背景（替代 Colors.red.shade50）
  final Color errorContainer;

  /// 错误容器上的文字/图标（替代 Colors.red.shade700）
  final Color onErrorContainer;

  /// 成功容器背景（替代 Colors.green.shade50）
  final Color successContainer;

  /// 成功容器上的文字/图标（替代 Colors.green.shade700）
  final Color onSuccessContainer;

  /// 警告容器背景（替代 Colors.orange.shade50）
  final Color warningContainer;

  /// 警告容器上的文字/图标（替代 Colors.orange.shade700）
  final Color onWarningContainer;

  /// 信息容器背景（替代 Colors.blue.shade50）
  final Color infoContainer;

  /// 信息容器上的文字/图标（替代 Colors.blue.shade700）
  final Color onInfoContainer;

  // ─── Gallery 覆盖层 ──────────────────────────────────────────
  /// Gallery 错误页半透明覆盖（70% 白）
  final Color galleryOverlay;

  /// Gallery 深色背景上的纯白文字/图标
  final Color galleryOnDark;

  // ─── 关系图调色板（业务数据色，集中管理）───────────────────────
  /// 中心节点强调渐变起始色（亮主题为浅橙，暗主题沿用）
  final Color graphCenterStart;

  /// 中心节点强调渐变结束色
  final Color graphCenterEnd;

  /// 中心节点轮廓/光晕颜色
  final Color graphCenterGlow;

  /// 中心节点次级轮廓色
  final Color graphCenterBorder;

  /// 中心节点深色背景上的文字/光晕色
  final Color graphCenterOnDark;

  // ─── 角色性别色（业务数据色）─────────────────────────────────
  /// 男角色节点色
  final Color graphGenderMale;

  /// 女角色节点色
  final Color graphGenderFemale;

  /// 未指定性别角色节点色
  final Color graphGenderUnknown;

  // ─── 关系类型色（业务数据色）─────────────────────────────────
  /// 关系类型"亲密关系"色
  final Color graphRelationIntimate;

  /// 关系类型"家庭"色
  final Color graphRelationFamily;

  /// 关系类型"恋人"色
  final Color graphRelationLover;

  /// 关系类型"朋友"色
  final Color graphRelationFriend;

  /// 关系类型"敌对"色
  final Color graphRelationHostile;

  /// 关系类型"敌对（深）"色
  final Color graphRelationHostileDeep;

  /// 关系类型"竞争对手"色
  final Color graphRelationRival;

  /// 关系类型"同事"色
  final Color graphRelationColleague;

  /// 关系类型"师徒"色
  final Color graphRelationMaster;

  /// 关系类型"盟友"色
  final Color graphRelationAlly;

  /// 关系类型"默认"色
  final Color graphRelationDefault;

  // ─── 聊天暗色系 ──────────────────────────────────────────────
  final Color chatInputBackground;
  final Color chatPrimaryText;
  final Color chatSecondaryText;
  final Color chatHintText;
  final Color chatRoleBubble;
  final Color chatUserBubble;
  final Color chatUserBubbleBorder;
  final Color chatDivider;
  final Color chatButtonPrimary;
  final Color chatButtonDisabled;

  // ─── 其他 ─────────────────────────────────────────────────────
  /// 头像/沉浸式半透明阴影（30% 黑）
  final Color avatarShadow;

  /// 旧版 Material 错误红
  final Color errorAccent;

  const AppColors({
    required this.hermesBrandStart,
    required this.hermesBrandEnd,
    required this.hermesAccent,
    required this.hermesOnBrand,
    required this.hermesOnBrandMuted,
    required this.ttsAccent,
    required this.ttsHint,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.neutral,
    required this.onSemantic,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.galleryOverlay,
    required this.galleryOnDark,
    required this.graphCenterStart,
    required this.graphCenterEnd,
    required this.graphCenterGlow,
    required this.graphCenterBorder,
    required this.graphCenterOnDark,
    required this.graphGenderMale,
    required this.graphGenderFemale,
    required this.graphGenderUnknown,
    required this.graphRelationIntimate,
    required this.graphRelationFamily,
    required this.graphRelationLover,
    required this.graphRelationFriend,
    required this.graphRelationHostile,
    required this.graphRelationHostileDeep,
    required this.graphRelationRival,
    required this.graphRelationColleague,
    required this.graphRelationMaster,
    required this.graphRelationAlly,
    required this.graphRelationDefault,
    required this.chatInputBackground,
    required this.chatPrimaryText,
    required this.chatSecondaryText,
    required this.chatHintText,
    required this.chatRoleBubble,
    required this.chatUserBubble,
    required this.chatUserBubbleBorder,
    required this.chatDivider,
    required this.chatButtonPrimary,
    required this.chatButtonDisabled,
    required this.avatarShadow,
    required this.errorAccent,
  });

  /// 亮色主题配色
  ///
  /// 聊天/角色气泡使用浅色填充 + 深色文字，确保浅色背景下可读。
  /// 语义色使用中度饱和度（Material 700/800）以在白色背景上保持对比度。
  static const AppColors light = AppColors(
    hermesBrandStart: Color(0xFF6366F1),
    hermesBrandEnd: Color(0xFF8B5CF6),
    hermesAccent: Color(0xFF6366F1),
    hermesOnBrand: Colors.white,
    hermesOnBrandMuted: Colors.white70,
    ttsAccent: Color(0xFF2196F3),
    ttsHint: Color(0xFF9E9E9E),
    success: Color(0xFF2E7D32),
    error: Color(0xFFC62828),
    warning: Color(0xFFEF6C00),
    info: Color(0xFF1976D2),
    neutral: Color(0xFF616161),
    onSemantic: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    successContainer: Color(0xFFD7EFD9),
    onSuccessContainer: Color(0xFF002106),
    warningContainer: Color(0xFFFFE2B7),
    onWarningContainer: Color(0xFF2A1700),
    infoContainer: Color(0xFFD7E3F4),
    onInfoContainer: Color(0xFF001D36),
    galleryOverlay: Color(0xB3FFFFFF),
    galleryOnDark: Color(0xFFFFFFFF),
    // 关系图调色板（沿用原硬编码值，保持视觉一致）
    graphCenterStart: Color(0xFFFFA726),         // orange.shade400
    graphCenterEnd: Color(0xFFEF6C00),           // orange.shade600
    graphCenterGlow: Color(0x80EF6C00),          // orange.shade600 @ 50%
    graphCenterBorder: Color(0xFFFFCC80),         // orange.shade100
    graphCenterOnDark: Color(0xFFFBE9E7),         // orange.shade50
    graphGenderMale: Color(0xFF1976D2),           // Colors.blue
    graphGenderFemale: Color(0xFFE91E63),         // Colors.pink
    graphGenderUnknown: Color(0xFF9C27B0),        // Colors.purple
    graphRelationIntimate: Color(0xFFE53935),     // red.shade600
    graphRelationFamily: Color(0xFF00897B),      // teal.shade600
    graphRelationLover: Color(0xFFEC407A),       // pink.shade500
    graphRelationFriend: Color(0xFF1E88E5),       // blue.shade600
    graphRelationHostile: Color(0xFFD32F2F),      // red.shade600
    graphRelationHostileDeep: Color(0xFFB71C1C),  // red.shade800
    graphRelationRival: Color(0xFFEF6C00),        // orange.shade600
    graphRelationColleague: Color(0xFFFFA000),    // amber.shade700
    graphRelationMaster: Color(0xFF3949AB),       // indigo.shade600
    graphRelationAlly: Color(0xFF43A047),         // green.shade600
    graphRelationDefault: Color(0xFF757575),      // grey.shade600
    chatInputBackground: Color(0xFFF5F5F5),
    chatPrimaryText: Color(0xFF1A1A1A),
    chatSecondaryText: Color(0xFF555555),
    chatHintText: Color(0xFF888888),
    chatRoleBubble: Color(0xFFD7E3F4),
    chatUserBubble: Color(0xFFD7EFD9),
    chatUserBubbleBorder: Color(0xFFA5C9A8),
    chatDivider: Color(0xFFE0E0E0),
    chatButtonPrimary: Color(0xFF2196F3),
    chatButtonDisabled: Color(0xFFBDBDBD),
    avatarShadow: Color(0x4D000000),
    errorAccent: Color(0xFFB00020),
  );

  /// 暗色主题配色
  ///
  /// 沿用项目原 `0xFF...` 深色值与 Material 默认 `Colors.X`，
  /// 保留原观感。
  static const AppColors dark = AppColors(
    hermesBrandStart: Color(0xFF6366F1),
    hermesBrandEnd: Color(0xFF8B5CF6),
    hermesAccent: Color(0xFF6366F1),
    hermesOnBrand: Colors.white,
    hermesOnBrandMuted: Colors.white70,
    ttsAccent: Color(0xFF2196F3),
    ttsHint: Color(0xFF9E9E9E),
    success: Colors.green,
    error: Colors.red,
    warning: Colors.orange,
    info: Colors.blue,
    neutral: Color(0xFF616161),
    onSemantic: Colors.white,
    // 暗色容器色（深色低饱和度）
    errorContainer: Color(0xFF601410),
    onErrorContainer: Color(0xFFF9DEDC),
    successContainer: Color(0xFF1B5E20),
    onSuccessContainer: Color(0xFFD7EFD9),
    warningContainer: Color(0xFF8C5A00),
    onWarningContainer: Color(0xFFFFE2B7),
    infoContainer: Color(0xFF0D47A1),
    onInfoContainer: Color(0xFFD7E3F4),
    galleryOverlay: Color(0xB3FFFFFF),
    galleryOnDark: Color(0xFFFFFFFF),
    // 关系图调色板（暗色实例与亮色保持一致，关系图强调色不随主题变化）
    graphCenterStart: Color(0xFFFFA726),
    graphCenterEnd: Color(0xFFEF6C00),
    graphCenterGlow: Color(0x80EF6C00),
    graphCenterBorder: Color(0xFFFFCC80),
    graphCenterOnDark: Color(0xFFFBE9E7),
    graphGenderMale: Color(0xFF1976D2),
    graphGenderFemale: Color(0xFFE91E63),
    graphGenderUnknown: Color(0xFF9C27B0),
    graphRelationIntimate: Color(0xFFE53935),
    graphRelationFamily: Color(0xFF00897B),
    graphRelationLover: Color(0xFFEC407A),
    graphRelationFriend: Color(0xFF1E88E5),
    graphRelationHostile: Color(0xFFD32F2F),
    graphRelationHostileDeep: Color(0xFFB71C1C),
    graphRelationRival: Color(0xFFEF6C00),
    graphRelationColleague: Color(0xFFFFA000),
    graphRelationMaster: Color(0xFF3949AB),
    graphRelationAlly: Color(0xFF43A047),
    graphRelationDefault: Color(0xFF757575),
    chatInputBackground: Color(0xFF1E1E1E),
    chatPrimaryText: Color(0xFFE3E3E3),
    chatSecondaryText: Color(0xFFB0B0B0),
    chatHintText: Color(0xFF8E8E8E),
    chatRoleBubble: Color(0xFF1E3A5F),
    chatUserBubble: Color(0xFF1F3D2F),
    chatUserBubbleBorder: Color(0xFF3A6B4A),
    chatDivider: Color(0xFF3C3C3C),
    chatButtonPrimary: Color(0xFF2196F3),
    chatButtonDisabled: Color(0xFF3C3C3C),
    avatarShadow: Color(0x4D000000),
    errorAccent: Color(0xFFB00020),
  );

  @override
  AppColors copyWith({
    Color? hermesBrandStart,
    Color? hermesBrandEnd,
    Color? hermesAccent,
    Color? hermesOnBrand,
    Color? hermesOnBrandMuted,
    Color? ttsAccent,
    Color? ttsHint,
    Color? success,
    Color? error,
    Color? warning,
    Color? info,
    Color? neutral,
    Color? onSemantic,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? galleryOverlay,
    Color? galleryOnDark,
    Color? graphCenterStart,
    Color? graphCenterEnd,
    Color? graphCenterGlow,
    Color? graphCenterBorder,
    Color? graphCenterOnDark,
    Color? graphGenderMale,
    Color? graphGenderFemale,
    Color? graphGenderUnknown,
    Color? graphRelationIntimate,
    Color? graphRelationFamily,
    Color? graphRelationLover,
    Color? graphRelationFriend,
    Color? graphRelationHostile,
    Color? graphRelationHostileDeep,
    Color? graphRelationRival,
    Color? graphRelationColleague,
    Color? graphRelationMaster,
    Color? graphRelationAlly,
    Color? graphRelationDefault,
    Color? chatInputBackground,
    Color? chatPrimaryText,
    Color? chatSecondaryText,
    Color? chatHintText,
    Color? chatRoleBubble,
    Color? chatUserBubble,
    Color? chatUserBubbleBorder,
    Color? chatDivider,
    Color? chatButtonPrimary,
    Color? chatButtonDisabled,
    Color? avatarShadow,
    Color? errorAccent,
  }) {
    return AppColors(
      hermesBrandStart: hermesBrandStart ?? this.hermesBrandStart,
      hermesBrandEnd: hermesBrandEnd ?? this.hermesBrandEnd,
      hermesAccent: hermesAccent ?? this.hermesAccent,
      hermesOnBrand: hermesOnBrand ?? this.hermesOnBrand,
      hermesOnBrandMuted: hermesOnBrandMuted ?? this.hermesOnBrandMuted,
      ttsAccent: ttsAccent ?? this.ttsAccent,
      ttsHint: ttsHint ?? this.ttsHint,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
      onSemantic: onSemantic ?? this.onSemantic,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      galleryOverlay: galleryOverlay ?? this.galleryOverlay,
      galleryOnDark: galleryOnDark ?? this.galleryOnDark,
      graphCenterStart: graphCenterStart ?? this.graphCenterStart,
      graphCenterEnd: graphCenterEnd ?? this.graphCenterEnd,
      graphCenterGlow: graphCenterGlow ?? this.graphCenterGlow,
      graphCenterBorder: graphCenterBorder ?? this.graphCenterBorder,
      graphCenterOnDark: graphCenterOnDark ?? this.graphCenterOnDark,
      graphGenderMale: graphGenderMale ?? this.graphGenderMale,
      graphGenderFemale: graphGenderFemale ?? this.graphGenderFemale,
      graphGenderUnknown: graphGenderUnknown ?? this.graphGenderUnknown,
      graphRelationIntimate: graphRelationIntimate ?? this.graphRelationIntimate,
      graphRelationFamily: graphRelationFamily ?? this.graphRelationFamily,
      graphRelationLover: graphRelationLover ?? this.graphRelationLover,
      graphRelationFriend: graphRelationFriend ?? this.graphRelationFriend,
      graphRelationHostile: graphRelationHostile ?? this.graphRelationHostile,
      graphRelationHostileDeep: graphRelationHostileDeep ?? this.graphRelationHostileDeep,
      graphRelationRival: graphRelationRival ?? this.graphRelationRival,
      graphRelationColleague: graphRelationColleague ?? this.graphRelationColleague,
      graphRelationMaster: graphRelationMaster ?? this.graphRelationMaster,
      graphRelationAlly: graphRelationAlly ?? this.graphRelationAlly,
      graphRelationDefault: graphRelationDefault ?? this.graphRelationDefault,
      chatInputBackground: chatInputBackground ?? this.chatInputBackground,
      chatPrimaryText: chatPrimaryText ?? this.chatPrimaryText,
      chatSecondaryText: chatSecondaryText ?? this.chatSecondaryText,
      chatHintText: chatHintText ?? this.chatHintText,
      chatRoleBubble: chatRoleBubble ?? this.chatRoleBubble,
      chatUserBubble: chatUserBubble ?? this.chatUserBubble,
      chatUserBubbleBorder:
          chatUserBubbleBorder ?? this.chatUserBubbleBorder,
      chatDivider: chatDivider ?? this.chatDivider,
      chatButtonPrimary: chatButtonPrimary ?? this.chatButtonPrimary,
      chatButtonDisabled: chatButtonDisabled ?? this.chatButtonDisabled,
      avatarShadow: avatarShadow ?? this.avatarShadow,
      errorAccent: errorAccent ?? this.errorAccent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      hermesBrandStart:
          Color.lerp(hermesBrandStart, other.hermesBrandStart, t)!,
      hermesBrandEnd: Color.lerp(hermesBrandEnd, other.hermesBrandEnd, t)!,
      hermesAccent: Color.lerp(hermesAccent, other.hermesAccent, t)!,
      hermesOnBrand: Color.lerp(hermesOnBrand, other.hermesOnBrand, t)!,
      hermesOnBrandMuted:
          Color.lerp(hermesOnBrandMuted, other.hermesOnBrandMuted, t)!,
      ttsAccent: Color.lerp(ttsAccent, other.ttsAccent, t)!,
      ttsHint: Color.lerp(ttsHint, other.ttsHint, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onSemantic: Color.lerp(onSemantic, other.onSemantic, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer:
          Color.lerp(onErrorContainer, other.onErrorContainer, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      galleryOverlay: Color.lerp(galleryOverlay, other.galleryOverlay, t)!,
      galleryOnDark: Color.lerp(galleryOnDark, other.galleryOnDark, t)!,
      graphCenterStart: Color.lerp(graphCenterStart, other.graphCenterStart, t)!,
      graphCenterEnd: Color.lerp(graphCenterEnd, other.graphCenterEnd, t)!,
      graphCenterGlow: Color.lerp(graphCenterGlow, other.graphCenterGlow, t)!,
      graphCenterBorder: Color.lerp(graphCenterBorder, other.graphCenterBorder, t)!,
      graphCenterOnDark: Color.lerp(graphCenterOnDark, other.graphCenterOnDark, t)!,
      graphGenderMale: Color.lerp(graphGenderMale, other.graphGenderMale, t)!,
      graphGenderFemale: Color.lerp(graphGenderFemale, other.graphGenderFemale, t)!,
      graphGenderUnknown: Color.lerp(graphGenderUnknown, other.graphGenderUnknown, t)!,
      graphRelationIntimate: Color.lerp(graphRelationIntimate, other.graphRelationIntimate, t)!,
      graphRelationFamily: Color.lerp(graphRelationFamily, other.graphRelationFamily, t)!,
      graphRelationLover: Color.lerp(graphRelationLover, other.graphRelationLover, t)!,
      graphRelationFriend: Color.lerp(graphRelationFriend, other.graphRelationFriend, t)!,
      graphRelationHostile: Color.lerp(graphRelationHostile, other.graphRelationHostile, t)!,
      graphRelationHostileDeep: Color.lerp(graphRelationHostileDeep, other.graphRelationHostileDeep, t)!,
      graphRelationRival: Color.lerp(graphRelationRival, other.graphRelationRival, t)!,
      graphRelationColleague: Color.lerp(graphRelationColleague, other.graphRelationColleague, t)!,
      graphRelationMaster: Color.lerp(graphRelationMaster, other.graphRelationMaster, t)!,
      graphRelationAlly: Color.lerp(graphRelationAlly, other.graphRelationAlly, t)!,
      graphRelationDefault: Color.lerp(graphRelationDefault, other.graphRelationDefault, t)!,
      chatInputBackground:
          Color.lerp(chatInputBackground, other.chatInputBackground, t)!,
      chatPrimaryText: Color.lerp(chatPrimaryText, other.chatPrimaryText, t)!,
      chatSecondaryText:
          Color.lerp(chatSecondaryText, other.chatSecondaryText, t)!,
      chatHintText: Color.lerp(chatHintText, other.chatHintText, t)!,
      chatRoleBubble: Color.lerp(chatRoleBubble, other.chatRoleBubble, t)!,
      chatUserBubble: Color.lerp(chatUserBubble, other.chatUserBubble, t)!,
      chatUserBubbleBorder:
          Color.lerp(chatUserBubbleBorder, other.chatUserBubbleBorder, t)!,
      chatDivider: Color.lerp(chatDivider, other.chatDivider, t)!,
      chatButtonPrimary:
          Color.lerp(chatButtonPrimary, other.chatButtonPrimary, t)!,
      chatButtonDisabled:
          Color.lerp(chatButtonDisabled, other.chatButtonDisabled, t)!,
      avatarShadow: Color.lerp(avatarShadow, other.avatarShadow, t)!,
      errorAccent: Color.lerp(errorAccent, other.errorAccent, t)!,
    );
  }
}

/// 便捷访问 [AppColors] 的 [BuildContext] 扩展
///
/// 当 [ThemeData] 未注入 [AppColors] 时（如 loading 兜底分支），
/// 兜底返回 [AppColors.dark] 保持行为稳定。
extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
