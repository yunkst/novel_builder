import 'package:flutter/material.dart';

/// 书架空状态提示组件
///
/// 当书架中没有任何小说时显示，引导用户创建原创小说。
///
/// 使用方式：
/// ```dart
/// if (bookshelf.isEmpty) {
///   return EmptyBookshelfView(
///     onCreateNovel: () { /* 创建原创小说 */ },
///   );
/// }
/// ```
class EmptyBookshelfView extends StatelessWidget {
  /// 点击「创建新小说」时的回调
  final VoidCallback? onCreateNovel;

  const EmptyBookshelfView({
    super.key,
    this.onCreateNovel,
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
            // 空状态图标
            Icon(
              Icons.library_books_outlined,
              size: 80,
              color: colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 24),
            // 标题
            Text(
              '书架是空的',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            // 描述
            Text(
              '创建属于你自己的原创作品',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 「创建新小说」按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onCreateNovel,
                icon: const Icon(Icons.create_outlined),
                label: const Text('创建新小说'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
