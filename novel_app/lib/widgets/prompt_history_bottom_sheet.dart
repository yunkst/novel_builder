import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prompt_history.dart';
import '../core/providers/database_providers.dart';
import '../core/theme/app_colors.dart';

/// 历史提示词选择面板
///
/// 显示用户历史提示词列表，支持搜索、选中、删除。
class PromptHistoryBottomSheet extends ConsumerStatefulWidget {
  const PromptHistoryBottomSheet({super.key});

  @override
  ConsumerState<PromptHistoryBottomSheet> createState() =>
      _PromptHistoryBottomSheetState();
}

class _PromptHistoryBottomSheetState
    extends ConsumerState<PromptHistoryBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.neutral,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '历史提示词',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: '搜索关键词...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _keyword = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _keyword = v),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // 列表
            Expanded(
              child: _PromptHistoryList(
                keyword: _keyword,
                scrollController: scrollController,
                onSelected: (item) => Navigator.pop(context, item.promptText),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PromptHistoryList extends ConsumerStatefulWidget {
  const _PromptHistoryList({
    required this.keyword,
    required this.scrollController,
    required this.onSelected,
  });

  final String keyword;
  final ScrollController scrollController;
  final ValueChanged<PromptHistory> onSelected;

  @override
  ConsumerState<_PromptHistoryList> createState() => _PromptHistoryListState();
}

class _PromptHistoryListState extends ConsumerState<_PromptHistoryList> {
  Future<List<PromptHistory>> _fetch() {
    final repo = ref.read(promptHistoryRepositoryProvider);
    return widget.keyword.isEmpty ? repo.getAll() : repo.search(widget.keyword);
  }

  Future<void> _delete(PromptHistory item) async {
    final repo = ref.read(promptHistoryRepositoryProvider);
    await repo.delete(item.id!);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PromptHistory>>(
      future: _fetch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              widget.keyword.isEmpty ? '暂无历史提示词' : '未找到匹配项',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        return ListView.separated(
          controller: widget.scrollController,
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return _PromptHistoryTile(
              item: item,
              onTap: () => widget.onSelected(item),
              onDelete: () => _delete(item),
            );
          },
        );
      },
    );
  }
}

class _PromptHistoryTile extends StatelessWidget {
  const _PromptHistoryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final PromptHistory item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除该历史记录'),
            content: const Text('确认删除这条提示词吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirm == true) onDelete();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.promptText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(item.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDelete,
              tooltip: '删除',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
