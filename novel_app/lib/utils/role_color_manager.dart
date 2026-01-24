import 'package:flutter/material.dart';
import '../models/character.dart';

/// 角色颜色管理器
///
/// 为多个角色分配不同的颜色，用于在多人对话中区分不同角色
class RoleColorManager {
  /// 预定义的角色颜色列表
  static const List<Color> _roleColors = [
    Color(0xFF1E3A5F), // 深蓝色
    Color(0xFF1F3D2F), // 深绿色
    Color(0xFF3D1E5F), // 深紫色
    Color(0xFF5F3D1E), // 深棕色
    Color(0xFF5F1E3D), // 深红色
    Color(0xFF1E5F3D), // 青绿色
    Color(0xFF5F5F1E), // 深黄色
    Color(0xFF3D3D3D), // 深灰色
  ];

  /// 为角色分配颜色
  ///
  /// 按顺序为角色分配颜色，如果角色数量超过预设颜色数量，
  /// 则循环使用颜色列表。
  ///
  /// 参数：
  /// - [characters] 角色列表
  ///
  /// 返回：角色名到颜色的映射表
  static Map<String, Color> assignColors(List<Character> characters) {
    final Map<String, Color> colorMap = {};

    for (int i = 0; i < characters.length; i++) {
      final colorIndex = i % _roleColors.length;
      colorMap[characters[i].name] = _roleColors[colorIndex];
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
  ///
  /// 返回：角色对应的颜色
  static Color getColor(String characterName, Map<String, Color> colorMap) {
    return colorMap[characterName] ?? _roleColors.first;
  }
}
