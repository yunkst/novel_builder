import 'package:flutter/material.dart';
import '../models/character.dart';

/// 角色颜色管理器
///
/// 为多个角色分配不同的颜色，用于在多人对话中区分不同角色。
/// 拥有亮/暗两套调色板，根据 [BuildContext] 的 [Brightness] 自动选择。
class RoleColorManager {
  /// 暗色主题调色板（用于深色聊天气泡）
  static const List<Color> _darkPalette = [
    Color(0xFF1E3A5F), // 深蓝色
    Color(0xFF1F3D2F), // 深绿色
    Color(0xFF3D1E5F), // 深紫色
    Color(0xFF5F3D1E), // 深棕色
    Color(0xFF5F1E3D), // 深红色
    Color(0xFF1E5F3D), // 青绿色
    Color(0xFF5F5F1E), // 深黄色
    Color(0xFF3D3D3D), // 深灰色
  ];

  /// 亮色主题调色板（用于浅色聊天气泡，深色背景上区分）
  static const List<Color> _lightPalette = [
    Color(0xFFD7E3F4), // 浅蓝色
    Color(0xFFD7EFD9), // 浅绿色
    Color(0xFFE3D7F4), // 浅紫色
    Color(0xFFF4E3D7), // 浅棕色
    Color(0xFFF4D7E3), // 浅红色
    Color(0xFFD7F4E3), // 浅青绿
    Color(0xFFF4F4D7), // 浅黄色
    Color(0xFFE0E0E0), // 浅灰色
  ];

  /// 根据 context 选取调色板；context 为空时使用暗色调色板
  static List<Color> _palette(BuildContext? context) {
    if (context == null) return _darkPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkPalette : _lightPalette;
  }

  /// 为角色分配颜色
  ///
  /// 按顺序为角色分配颜色，如果角色数量超过预设颜色数量，
  /// 则循环使用颜色列表。
  ///
  /// 参数：
  /// - [characters] 角色列表
  /// - [context] 用于判断亮/暗主题；为空时使用暗色调色板
  ///
  /// 返回：角色名到颜色的映射表
  static Map<String, Color> assignColors(
    List<Character> characters, {
    BuildContext? context,
  }) {
    final palette = _palette(context);
    final Map<String, Color> colorMap = {};

    for (int i = 0; i < characters.length; i++) {
      final colorIndex = i % palette.length;
      colorMap[characters[i].name] = palette[colorIndex];
    }

    return colorMap;
  }

  /// 获取角色颜色
  ///
  /// 从颜色映射表中获取指定角色的颜色，
  /// 如果找不到则返回默认颜色（第一个颜色）。
  ///
  /// 参数：
  /// - [characterName] 角色名称
  /// - [colorMap] 颜色映射表
  /// - [context] 用于在缺失时选择亮/暗调色板
  ///
  /// 返回：角色对应的颜色
  static Color getColor(
    String characterName,
    Map<String, Color> colorMap, {
    BuildContext? context,
  }) {
    return colorMap[characterName] ?? _palette(context).first;
  }
}
