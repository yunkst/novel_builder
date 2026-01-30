import 'package:flutter/material.dart';
import '../../models/novel.dart';

/// 空章节状态视图组件
/// 当章节列表为空时显示，提供创建章节或从源网站获取章节的操作
class EmptyChaptersView extends StatelessWidget {
  final Novel novel;
  final VoidCallback onGenerateChapter;
  final VoidCallback onLoadFromSource;

  const EmptyChaptersView({
    required this.novel,
    required this.onGenerateChapter,
    required this.onLoadFromSource,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCustomNovel = novel.url.startsWith('custom://');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有章节',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCustomNovel ? '点击下方按钮创建第一个章节' : '你可以从源网站获取章节，或创建自己的章节',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onGenerateChapter,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI生成章节'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          if (!isCustomNovel) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onLoadFromSource,
              icon: const Icon(Icons.refresh),
              label: const Text('从源网站获取章节'),
            ),
          ],
        ],
      ),
    );
  }
}
