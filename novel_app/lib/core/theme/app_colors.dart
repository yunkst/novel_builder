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

  // ─── Gallery 覆盖层 ──────────────────────────────────────────
  /// Gallery 错误页半透明覆盖（70% 白）
  final Color galleryOverlay;

  /// Gallery 深色背景上的纯白文字/图标
  final Color galleryOnDark;

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
    required this.galleryOverlay,
    required this.galleryOnDark,
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
    galleryOverlay: Color(0xB3FFFFFF),
    galleryOnDark: Color(0xFFFFFFFF),
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
    galleryOverlay: Color(0xB3FFFFFF),
    galleryOnDark: Color(0xFFFFFFFF),
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
    Color? galleryOverlay,
    Color? galleryOnDark,
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
      galleryOverlay: galleryOverlay ?? this.galleryOverlay,
      galleryOnDark: galleryOnDark ?? this.galleryOnDark,
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
      galleryOverlay: Color.lerp(galleryOverlay, other.galleryOverlay, t)!,
      galleryOnDark: Color.lerp(galleryOnDark, other.galleryOnDark, t)!,
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
