import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/chat_scene_management_providers.dart';
import '../models/chat_scene.dart';
import '../widgets/chat_scene_edit_dialog.dart';
import '../widgets/common/common_widgets.dart';
import '../utils/toast_utils.dart';

/// 聊天场景管理页面 - Riverpod版本
///
/// 用于管理所有预设的聊天场景,支持增删改查和搜索功能
/// 这是原始 ChatSceneManagementScreen 的 Riverpod 包装器
class ChatSceneManagementScreenRiverpod extends ConsumerWidget {
  const ChatSceneManagementScreenRiverpod({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatSceneManagementProvider);
    final notifier = ref.read(chatSceneManagementProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: state.isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索场景...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withValues(alpha: 0.7)),
                ),
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                onChanged: (query) => notifier.searchScenes(query),
              )
            : const Text('场景管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(state.isSearching ? Icons.close : Icons.search),
            onPressed: () => notifier.toggleSearch(),
            tooltip: '搜索',
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.filteredScenes.isEmpty
              ? _buildEmptyState(context, state.scenes.isNotEmpty)
              : _buildSceneList(context, state.filteredScenes, notifier),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSceneDialog(context, notifier),
        tooltip: '添加场景',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, bool hasScenes) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasScenes ? Icons.search_off : Icons.bookmark_outline,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            hasScenes ? '没有找到匹配的场景' : '暂无预设场景',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasScenes ? '请尝试其他关键词' : '点击右下角的 + 按钮创建第一个场景',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建场景列表
  Widget _buildSceneList(
    BuildContext context,
    List<ChatScene> scenes,
    ChatSceneManagement notifier,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scenes.length,
      itemBuilder: (context, index) {
        final scene = scenes[index];
        return _buildSceneCard(context, scene, notifier);
      },
    );
  }

  /// 构建场景卡片
  Widget _buildSceneCard(
    BuildContext context,
    ChatScene scene,
    ChatSceneManagement notifier,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectScene(context, scene),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和操作按钮
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scene.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditSceneDialog(context, scene, notifier),
                    tooltip: '编辑',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _showDeleteConfirmDialog(context, scene, notifier),
                    tooltip: '删除',
                    visualDensity: VisualDensity.compact,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 内容预览
              Text(
                scene.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // 底部信息
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(scene.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '点击选择',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选择场景并返回
  void _selectScene(BuildContext context, ChatScene scene) {
    Navigator.of(context).pop(scene.content);
  }

  /// 显示添加场景对话框
  Future<void> _showAddSceneDialog(
    BuildContext context,
    ChatSceneManagement notifier,
  ) async {
    final result = await showDialog<ChatScene>(
      context: context,
      builder: (context) => const ChatSceneEditDialog(),
    );

    if (result != null) {
      try {
        await notifier.addScene(result);
        if (context.mounted) {
          ToastUtils.showSuccess('场景添加成功');
        }
      } catch (e) {
        if (context.mounted) {
          ToastUtils.showError('添加失败: $e');
        }
      }
    }
  }

  /// 显示编辑场景对话框
  Future<void> _showEditSceneDialog(
    BuildContext context,
    ChatScene scene,
    ChatSceneManagement notifier,
  ) async {
    final result = await showDialog<ChatScene>(
      context: context,
      builder: (context) => ChatSceneEditDialog(scene: scene),
    );

    if (result != null) {
      try {
        await notifier.updateScene(result);
        if (context.mounted) {
          ToastUtils.showSuccess('场景更新成功');
        }
      } catch (e) {
        if (context.mounted) {
          ToastUtils.showError('更新失败: $e');
        }
      }
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(
    BuildContext context,
    ChatScene scene,
    ChatSceneManagement notifier,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '删除场景',
      message: '确定要删除场景"${scene.title}"吗？此操作无法撤销。',
      confirmText: '删除',
      icon: Icons.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed == true) {
      try {
        await notifier.deleteScene(scene.id!);
        if (context.mounted) {
          ToastUtils.showSuccess('场景删除成功');
        }
      } catch (e) {
        if (context.mounted) {
          ToastUtils.showError('删除失败: $e');
        }
      }
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
