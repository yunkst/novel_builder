import 'package:flutter/material.dart';
import '../models/chat_scene.dart';
import '../repositories/chat_scene_repository.dart';
import '../services/database_service.dart';
import '../utils/toast_utils.dart';
import '../widgets/chat_scene_edit_dialog.dart';
import '../widgets/common/common_widgets.dart';

/// 聊天场景管理页面
///
/// 用于管理所有预设的聊天场景，支持增删改查和搜索功能
class ChatSceneManagementScreen extends StatefulWidget {
  /// 可选的依赖注入参数 - 用于测试
  final ChatSceneRepository? chatSceneRepository;

  const ChatSceneManagementScreen({
    super.key,
    this.chatSceneRepository,
  });

  @override
  State<ChatSceneManagementScreen> createState() =>
      _ChatSceneManagementScreenState();
}

class _ChatSceneManagementScreenState extends State<ChatSceneManagementScreen> {
  late final ChatSceneRepository _chatSceneRepository;
  late final DatabaseService _databaseService;
  List<ChatScene> _scenes = [];
  List<ChatScene> _filteredScenes = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    // 使用注入的依赖或创建默认实例
    _databaseService = DatabaseService();
    _chatSceneRepository =
        widget.chatSceneRepository ?? _databaseService.chatSceneRepository;

    _loadScenes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载所有场景
  Future<void> _loadScenes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final scenes = await _chatSceneRepository.getAllChatScenes();
      if (mounted) {
        setState(() {
          _scenes = scenes;
          _filteredScenes = scenes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ToastUtils.showError('加载场景失败: $e');
      }
    }
  }

  /// 添加新场景
  Future<void> _addScene() async {
    final result = await showDialog<ChatScene>(
      context: context,
      builder: (context) => const ChatSceneEditDialog(),
    );

    if (result != null) {
      try {
        await _chatSceneRepository.insertChatScene(result);
        await _loadScenes();
        if (mounted) {
          ToastUtils.showSuccess('场景添加成功');
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError('添加失败: $e');
        }
      }
    }
  }

  /// 编辑场景
  Future<void> _editScene(ChatScene scene) async {
    final result = await showDialog<ChatScene>(
      context: context,
      builder: (context) => ChatSceneEditDialog(scene: scene),
    );

    if (result != null) {
      try {
        await _chatSceneRepository.updateChatScene(result);
        await _loadScenes();
        if (mounted) {
          ToastUtils.showSuccess('场景更新成功');
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError('更新失败: $e');
        }
      }
    }
  }

  /// 删除场景
  Future<void> _deleteScene(ChatScene scene) async {
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
        await _chatSceneRepository.deleteChatScene(scene.id!);
        await _loadScenes();
        if (mounted) {
          ToastUtils.showSuccess('场景删除成功');
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError('删除失败: $e');
        }
      }
    }
  }

  /// 选择场景并返回
  void _selectScene(ChatScene scene) {
    Navigator.of(context).pop(scene.content);
  }

  /// 搜索场景
  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredScenes = _scenes;
      });
    } else {
      setState(() {
        _filteredScenes = _scenes.where((scene) {
          return scene.title.toLowerCase().contains(query.toLowerCase()) ||
              scene.content.toLowerCase().contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  /// 切换搜索状态
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredScenes = _scenes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
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
                onChanged: _onSearchChanged,
              )
            : const Text('场景管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: '搜索',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredScenes.isEmpty
              ? _buildEmptyState()
              : _buildSceneList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addScene,
        tooltip: '添加场景',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final hasScenes = _scenes.isNotEmpty;
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
  Widget _buildSceneList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredScenes.length,
      itemBuilder: (context, index) {
        final scene = _filteredScenes[index];
        return _buildSceneCard(scene);
      },
    );
  }

  /// 构建场景卡片
  Widget _buildSceneCard(ChatScene scene) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectScene(scene),
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
                    onPressed: () => _editScene(scene),
                    tooltip: '编辑',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _deleteScene(scene),
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
