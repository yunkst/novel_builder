/// 应用自定义颜色主题扩展
///
/// 通过 [ThemeData.extensions] 注入到主题中，提供品牌色、语义色等
/// Material 3 [ColorScheme] 之外的扩展颜色。
///
/// 使用方式：
/// ```dart
/// final colors = context.appColors; // BuildContext 扩展
/// Container(color: colors.agentAccent);
/// ```
library;

import 'package:flutter/material.dart';

/// 应用自定义颜色主题扩展
@immutable
class AppColors extends ThemeExtension<AppColors> {
  // ─── Agent 品牌色 ────────────────────────────────────────────
  /// Agent 渐变起始色（紫蓝 Indigo-500）
  final Color agentBrandStart;

  /// Agent 渐变结束色（紫色 Violet-500）
  final Color agentBrandEnd;

  /// Agent 用户气泡/发送按钮主色
  final Color agentAccent;

  /// Agent 头部主文字/图标色
  final Color agentOnBrand;

  /// Agent 头部次要图标色
  final Color agentOnBrandMuted;

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
    required this.agentBrandStart,
    required this.agentBrandEnd,
    required this.agentAccent,
    required this.agentOnBrand,
    required this.agentOnBrandMuted,
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

  /// 亮色主题配色 · 晨读书馆
  ///
  /// 暖白纸底 + 墨色字 + 琥珀强调，护眼且有书卷气。
  /// 业务色（关系图/性别/Agent 品牌）与暗色保持一致，不随主题变化。
  static const AppColors light = AppColors(
    agentBrandStart: Color(0xFF6366F1),
    agentBrandEnd: Color(0xFF8B5CF6),
    agentAccent: Color(0xFF6366F1),
    agentOnBrand: Colors.white,
    agentOnBrandMuted: Colors.white70,
    success: Color(0xFF5E7A3C),
    error: Color(0xFFB23A2E),
    warning: Color(0xFFB8732A),
    info: Color(0xFF3A6A9E),
    neutral: Color(0xFF6B5D48),
    onSemantic: Colors.white,
    // 容器色 · 米白纸感
    errorContainer: Color(0xFFF3DAD5),
    onErrorContainer: Color(0xFF5C1A12),
    successContainer: Color(0xFFE0E8CF),
    onSuccessContainer: Color(0xFF2A3A14),
    warningContainer: Color(0xFFF3E2C5),
    onWarningContainer: Color(0xFF4A2E08),
    infoContainer: Color(0xFFD8E2EE),
    onInfoContainer: Color(0xFF0E2840),
    galleryOverlay: Color(0xB3F3EADA),
    galleryOnDark: Color(0xFFFFFFFF),
    // 关系图调色板（业务色，与暗色一致）
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
    // 聊天 · 暖纸色系
    chatInputBackground: Color(0xFFEBE3D2),
    chatPrimaryText: Color(0xFF2A2018),
    chatSecondaryText: Color(0xFF6B5D48),
    chatHintText: Color(0xFF9C8A6E),
    chatRoleBubble: Color(0xFFDCE6F0),
    chatUserBubble: Color(0xFFE0E8CF),
    chatUserBubbleBorder: Color(0xFFB8C8A0),
    chatDivider: Color(0xFFDCCFB3),
    chatButtonPrimary: Color(0xFFB8843A),
    chatButtonDisabled: Color(0xFFC9BC9E),
    avatarShadow: Color(0x2A000000),
    errorAccent: Color(0xFFB23A2E),
  );

  /// 暗色主题配色 · 暗夜书馆
  ///
  /// 深炭黑底 + 羊皮纸字 + 琥珀暖光，沉浸夜读。
  static const AppColors dark = AppColors(
    agentBrandStart: Color(0xFF6366F1),
    agentBrandEnd: Color(0xFF8B5CF6),
    agentAccent: Color(0xFF6366F1),
    agentOnBrand: Colors.white,
    agentOnBrandMuted: Colors.white70,
    success: Color(0xFF7A9A55),
    error: Color(0xFFD9685A),
    warning: Color(0xFFE0A050),
    info: Color(0xFF6E9FD6),
    neutral: Color(0xFF8A7C66),
    onSemantic: Color(0xFF1A1610),
    // 容器色 · 深炭低饱和
    errorContainer: Color(0xFF4A1A14),
    onErrorContainer: Color(0xFFF3DAD5),
    successContainer: Color(0xFF2A3A14),
    onSuccessContainer: Color(0xFFE0E8CF),
    warningContainer: Color(0xFF4A2E08),
    onWarningContainer: Color(0xFFF3E2C5),
    infoContainer: Color(0xFF142A42),
    onInfoContainer: Color(0xFFD8E2EE),
    galleryOverlay: Color(0xB3FFFFFF),
    galleryOnDark: Color(0xFFFFFFFF),
    // 关系图调色板（业务色，与亮色一致）
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
    // 聊天 · 深炭羊皮纸系
    chatInputBackground: Color(0xFF241F16),
    chatPrimaryText: Color(0xFFE8DCC4),
    chatSecondaryText: Color(0xFFB5A482),
    chatHintText: Color(0xFF7A6B52),
    chatRoleBubble: Color(0xFF1F2E44),
    chatUserBubble: Color(0xFF2A3A1E),
    chatUserBubbleBorder: Color(0xFF4A5C3A),
    chatDivider: Color(0xFF3A3128),
    chatButtonPrimary: Color(0xFFD9A05B),
    chatButtonDisabled: Color(0xFF3A3128),
    avatarShadow: Color(0x4D000000),
    errorAccent: Color(0xFFD9685A),
  );

  @override
  AppColors copyWith({
    Color? agentBrandStart,
    Color? agentBrandEnd,
    Color? agentAccent,
    Color? agentOnBrand,
    Color? agentOnBrandMuted,
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
      agentBrandStart: agentBrandStart ?? this.agentBrandStart,
      agentBrandEnd: agentBrandEnd ?? this.agentBrandEnd,
      agentAccent: agentAccent ?? this.agentAccent,
      agentOnBrand: agentOnBrand ?? this.agentOnBrand,
      agentOnBrandMuted: agentOnBrandMuted ?? this.agentOnBrandMuted,
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
      agentBrandStart:
          Color.lerp(agentBrandStart, other.agentBrandStart, t)!,
      agentBrandEnd: Color.lerp(agentBrandEnd, other.agentBrandEnd, t)!,
      agentAccent: Color.lerp(agentAccent, other.agentAccent, t)!,
      agentOnBrand: Color.lerp(agentOnBrand, other.agentOnBrand, t)!,
      agentOnBrandMuted:
          Color.lerp(agentOnBrandMuted, other.agentOnBrandMuted, t)!,
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
