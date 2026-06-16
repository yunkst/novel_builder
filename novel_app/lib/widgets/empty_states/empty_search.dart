import 'package:flutter/material.dart';

/// 搜索页空状态提示
///
/// 适用于以下情况：
/// - 用户首次进入搜索页（还没输入关键词）
/// - 搜索结果为空但无错误信息
///
/// 显示插图 + 引导文案，提示用户输入关键词。
/// 如果搜索是因为 API 配置错误无结果，可传入 [onOpenSettings] 回调
/// 显示"打开设置"按钮，引导用户跳到设置页检查后端配置。
///
/// 使用方式：
/// ```dart
/// if (searchState.results.isEmpty && !searchState.isLoading) {
///   return EmptySearchView(
///     onOpenSettings: () => ref
///         .read(homeTabIndexNotifierProvider.notifier)
///         .switchTo(HomeTabIndex.settings),
///   );
/// }
/// ```
class EmptySearchView extends StatelessWidget {
  /// 点击「打开设置」时的回调（不传则不显示按钮）
  final VoidCallback? onOpenSettings;

  const EmptySearchView({
    super.key,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 72,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            Text(
              '输入书名或作者',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在上方搜索框输入关键词，从多个站点一键检索',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center,
            ),
            if (onOpenSettings != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('打开设置'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
