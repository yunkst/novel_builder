import 'package:flutter/material.dart';

/// 通用标题行组件
///
/// 提供统一的标题行布局，包含可选图标、标题和尾部组件。
///
/// 示例:
/// ```dart
/// TitleRow(
///   title: '章节列表',
///   icon: Icons.menu_book,
///   trailing: TextButton(
///     onPressed: () {},
///     child: Text('更多'),
///   ),
/// )
/// ```
class TitleRow extends StatelessWidget {
  /// 标题文本
  final String title;

  /// 标题前的图标
  final IconData? icon;

  /// 尾部组件（如按钮、图标等）
  final Widget? trailing;

  /// 副标题文本
  final String? subtitle;

  /// 标题和图标之间的间距
  final double spacing;

  /// 是否显示底部边框
  final bool showBorder;

  /// 内边距
  final EdgeInsets padding;

  const TitleRow({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.subtitle,
    this.spacing = 8.0,
    this.showBorder = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 12.0,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: showBorder
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: colorScheme.primary,
            ),
            SizedBox(width: spacing),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 带动作按钮的标题行组件
///
/// 在TitleRow基础上提供常用的动作按钮配置。
///
/// 示例:
/// ```dart
/// TitleRowWithAction(
///   title: '角色列表',
///   icon: Icons.people,
///   actionText: '添加',
///   actionIcon: Icons.add,
///   onPressed: () {},
/// )
/// ```
class TitleRowWithAction extends StatelessWidget {
  /// 标题文本
  final String title;

  /// 标题前的图标
  final IconData? icon;

  /// 副标题文本
  final String? subtitle;

  /// 动作按钮文本
  final String? actionText;

  /// 动作按钮图标
  final IconData? actionIcon;

  /// 动作按钮点击事件
  final VoidCallback? onPressed;

  /// 是否显示底部边框
  final bool showBorder;

  /// 内边距
  final EdgeInsets padding;

  const TitleRowWithAction({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.actionText,
    this.actionIcon,
    this.onPressed,
    this.showBorder = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 12.0,
    ),
  });

  @override
  Widget build(BuildContext context) {
    Widget? trailing;

    if (actionText != null || actionIcon != null) {
      trailing = TextButton.icon(
        onPressed: onPressed,
        icon: actionIcon != null ? Icon(actionIcon, size: 18) : const SizedBox(),
        label: Text(actionText ?? ''),
      );
    }

    return TitleRow(
      title: title,
      icon: icon,
      subtitle: subtitle,
      trailing: trailing,
      showBorder: showBorder,
      padding: padding,
    );
  }
}
