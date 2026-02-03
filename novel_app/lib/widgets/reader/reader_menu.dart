/// ReaderMenu Widget - 阅读器菜单组件
///
/// 职责：
/// - 构建阅读器菜单项列表
/// - 根据状态动态显示菜单项
/// - 提高菜单可维护性和可测试性
///
/// 架构：
/// - 独立Widget组件，无状态依赖
/// - 支持动态菜单项配置
/// - 清晰的菜单项分组逻辑

library;
import 'package:flutter/material.dart';

/// 阅读器菜单配置
///
/// 用于构建阅读器菜单项列表，根据当前状态动态显示菜单项
class ReaderMenu {
  final bool isContentAvailable;
  final bool isUpdatingRoleCards;

  const ReaderMenu({
    required this.isContentAvailable,
    required this.isUpdatingRoleCards,
  });

  /// 构建菜单项列表
  List<PopupMenuItem<String>> buildItems() {
    return [
      _buildMenuItem(
        value: 'refresh',
        label: '刷新章节',
        icon: Icons.refresh,
      ),
      _buildMenuItem(
        value: 'scroll_speed',
        label: '滚动速度',
        icon: Icons.speed,
      ),
      _buildMenuItem(
        value: 'font_size',
        label: '字体大小',
        icon: Icons.text_fields,
      ),
      _buildMenuItem(
        value: 'summarize',
        label: '总结',
        icon: Icons.summarize,
      ),
      _buildMenuItem(
        value: 'tts_read',
        label: '朗读',
        icon: Icons.headphones,
      ),
      _buildMenuItem(
        value: 'full_rewrite',
        label: '全文重写',
        icon: Icons.auto_stories,
      ),
      _buildMenuItem(
        value: 'update_character_cards',
        label: isUpdatingRoleCards ? '更新中...' : '更新角色卡',
        icon: Icons.person_search,
        enabled: !isUpdatingRoleCards,
      ),
      _buildMenuItem(
        value: 'ai_companion',
        label: 'AI伴读',
        icon: Icons.auto_stories,
      ),
    ];
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
