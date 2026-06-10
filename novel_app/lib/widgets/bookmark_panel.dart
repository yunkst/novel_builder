import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/webview_providers.dart';
import '../../services/bookmark_service.dart';

/// 收藏夹弹出面板
///
/// 功能：
/// - 展示收藏夹列表
/// - 点击收藏项跳转到对应 URL
/// - 长按/滑动删除收藏
/// - 底部添加当前页面到收藏
class BookmarkPanel extends ConsumerStatefulWidget {
  /// 点击收藏项时的回调（跳转 URL）
  final void Function(String url) onNavigate;

  const BookmarkPanel({super.key, required this.onNavigate});

  @override
  ConsumerState<BookmarkPanel> createState() => _BookmarkPanelState();
}

class _BookmarkPanelState extends ConsumerState<BookmarkPanel> {
  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final currentUrl = ref.watch(webviewCurrentUrlProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部把手
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.bookmark, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '收藏夹',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // 添加当前页面
                _AddBookmarkButton(currentUrl: currentUrl),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // 收藏列表
          Flexible(child: _buildBookmarkList(bookmarksAsync, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildBookmarkList(
      AsyncValue<List<Bookmark>> bookmarksAsync, ColorScheme colorScheme) {
    return bookmarksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('加载失败',
              style: TextStyle(color: colorScheme.error)),
        ),
      ),
      data: (bookmarks) {
        if (bookmarks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border,
                      size: 48,
                      color: colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    '暂无收藏',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击右上角添加当前页面',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: bookmarks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return _BookmarkTile(
              bookmark: bookmark,
              onTap: () {
                widget.onNavigate(bookmark.url);
                Navigator.of(context).pop();
              },
              onDelete: () {
                ref
                    .read(bookmarkListProvider.notifier)
                    .removeBookmark(bookmark.id);
              },
            );
          },
        );
      },
    );
  }
}

/// 单个收藏项
class _BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.error,
        child: Icon(Icons.delete_outline, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除收藏'),
            content: Text('确定删除「${bookmark.title}」吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        dense: true,
        leading:
            Icon(Icons.language, size: 20, color: colorScheme.primary),
        title: Text(
          bookmark.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
        ),
        subtitle: Text(
          bookmark.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.4)),
          tooltip: '删除',
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除收藏'),
                content: Text('确定删除「${bookmark.title}」吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirmed == true) onDelete();
          },
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 添加收藏按钮
class _AddBookmarkButton extends ConsumerWidget {
  final String currentUrl;

  const _AddBookmarkButton({required this.currentUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final isBookmarked =
        bookmarksAsync.value?.any((b) => b.url == currentUrl) ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
        size: 22,
        color: isBookmarked
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      tooltip: isBookmarked ? '已收藏' : '收藏当前页面',
      onPressed: isBookmarked
          ? null
          : () async {
              // 提取域名作为默认标题
              final uri = Uri.tryParse(currentUrl);
              final defaultTitle = uri?.host ?? currentUrl;

              final title = await showDialog<String>(
                context: context,
                builder: (ctx) => _AddBookmarkDialog(
                  defaultTitle: defaultTitle,
                  url: currentUrl,
                ),
              );

              if (title != null && title.isNotEmpty) {
                ref
                    .read(bookmarkListProvider.notifier)
                    .addBookmark(title: title, url: currentUrl);
              }
            },
    );
  }
}

/// 添加收藏对话框
class _AddBookmarkDialog extends StatefulWidget {
  final String defaultTitle;
  final String url;

  const _AddBookmarkDialog({
    required this.defaultTitle,
    required this.url,
  });

  @override
  State<_AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<_AddBookmarkDialog> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加收藏'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '标题',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isNotEmpty) {
              Navigator.of(context).pop(title);
            }
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
