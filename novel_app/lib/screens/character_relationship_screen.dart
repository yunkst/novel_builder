import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../widgets/relationship_edit_dialog.dart';
import '../widgets/common/common_widgets.dart';
import '../utils/toast_utils.dart';
import '../core/providers/character_relationship_providers.dart';
import '../core/providers/database_providers.dart';
import 'unified_relationship_graph_screen_riverpod.dart';

/// 角色关系列表页面
///
/// 显示某个角色的所有关系，支持按Tab分类查看：
/// - Tab 1: 全部关系 (出度 + 入度)
/// - Tab 2: Ta的关系 (出度：Ta → 其他人)
/// - Tab 3: 关系Ta的人 (入度：其他人 → Ta)
class CharacterRelationshipScreen extends ConsumerStatefulWidget {
  final Character character;

  const CharacterRelationshipScreen({
    super.key,
    required this.character,
  });

  @override
  ConsumerState<CharacterRelationshipScreen> createState() =>
      _CharacterRelationshipScreenState();
}

class _CharacterRelationshipScreenState
    extends ConsumerState<CharacterRelationshipScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 获取角色缓存（异步加载）
  Future<Map<int, Character>> _loadCharacterCache(
    List<int> characterIds,
  ) async {
    if (characterIds.isEmpty || widget.character.id == null) return {};

    try {
      final repository = ref.read(characterRepositoryProvider);
      final allCharacters =
          await repository.getCharacters(widget.character.novelUrl);

      // 过滤出相关的角色并缓存
      final cache = <int, Character>{};
      for (final character in allCharacters) {
        if (character.id != null && characterIds.contains(character.id)) {
          cache[character.id!] = character;
        }
      }
      return cache;
    } catch (e) {
      debugPrint('❌ 加载角色信息失败: $e');
      return {};
    }
  }

  /// 添加新关系
  Future<void> _addRelationship() async {
    // 获取所有可选角色（排除当前角色）
    final repository = ref.read(characterRepositoryProvider);
    final allCharacters =
        await repository.getCharacters(widget.character.novelUrl);
    final availableCharacters =
        allCharacters.where((c) => c.id != widget.character.id).toList();

    if (availableCharacters.isEmpty) {
      if (mounted) {
        ToastUtils.showWarning('没有其他角色可以建立关系');
      }
      return;
    }

    if (!mounted) return;

    final result = await RelationshipEditDialog.show(
      context: context,
      currentCharacter: widget.character,
      availableCharacters: availableCharacters,
    );

    if (result != null) {
      // 刷新列表
      invalidateRelationshipProviders(ref, widget.character.id!);
      if (mounted) {
        ToastUtils.showSuccess('关系添加成功');
      }
    }
  }

  /// 查看关系图
  Future<void> _viewGraph() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedRelationshipGraphScreenRiverpod(
          novelUrl: widget.character.novelUrl,
          focusCharacter: widget.character, // 单角色模式
        ),
      ),
    );
    // 刷新会由Provider自动处理
  }

  @override
  Widget build(BuildContext context) {
    // 监听出度/入度关系数据
    final outgoingAsync =
        ref.watch(outgoingRelationshipsProvider(widget.character.id!));
    final incomingAsync =
        ref.watch(incomingRelationshipsProvider(widget.character.id!));

    // 计算加载状态
    final isLoading = outgoingAsync.isLoading || incomingAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name} - 人物关系'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: '查看关系图',
            onPressed: _viewGraph,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加关系',
            onPressed: _addRelationship,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          tabs: const [
            Tab(text: 'Ta的关系'),
            Tab(text: '关系Ta的人'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTabView(outgoingAsync, incomingAsync),
    );
  }

  Widget _buildTabView(
    AsyncValue<List<CharacterRelationship>> outgoingAsync,
    AsyncValue<List<CharacterRelationship>> incomingAsync,
  ) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildRelationshipList(outgoingAsync, isOutgoing: true),
        _buildRelationshipList(incomingAsync, isOutgoing: false),
      ],
    );
  }

  /// 构建关系列表
  Widget _buildRelationshipList(
    AsyncValue<List<CharacterRelationship>> relationshipsAsync, {
    required bool isOutgoing,
  }) {
    return relationshipsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('加载失败: $error'),
          ],
        ),
      ),
      data: (relationships) {
        if (relationships.isEmpty) {
          return _buildEmptyState(isOutgoing);
        }

        // 收集相关角色ID
        final characterIds = <int>{};
        for (final rel in relationships) {
          final targetId = isOutgoing
              ? rel.targetCharacterId
              : rel.sourceCharacterId;
          characterIds.add(targetId);
        }
        characterIds.remove(widget.character.id);

        // 使用FutureBuilder加载角色缓存
        return FutureBuilder<Map<int, Character>>(
          future: _loadCharacterCache(characterIds.toList()),
          builder: (context, snapshot) {
            final characterCache = snapshot.data ?? {};

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: relationships.length,
              itemBuilder: (context, index) {
                return _buildRelationshipCard(
                  relationships[index],
                  isOutgoing: isOutgoing,
                  characterCache: characterCache,
                );
              },
            );
          },
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(bool isOutgoing) {
    String message;
    IconData icon;

    if (isOutgoing) {
      message = '${widget.character.name} 还没有定义与其他人的关系';
      icon = Icons.arrow_forward;
    } else {
      message = '还没有人定义与 ${widget.character.name} 的关系';
      icon = Icons.arrow_back;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 构建关系卡片
  Widget _buildRelationshipCard(
    CharacterRelationship relationship, {
    required bool isOutgoing,
    required Map<int, Character> characterCache,
  }) {
    // 确定显示的目标角色
    final targetCharacterId = isOutgoing
        ? relationship.targetCharacterId
        : relationship.sourceCharacterId;

    final targetCharacter = characterCache[targetCharacterId];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getGenderColor(targetCharacter?.gender),
          child: Text(
            targetCharacter?.name.isNotEmpty ?? false
                ? targetCharacter!.name[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          relationship.relationshipType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              targetCharacter?.name ?? '未知角色',
              style: const TextStyle(fontSize: 14),
            ),
            if (relationship.description != null &&
                relationship.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  relationship.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOutgoing)
              Icon(
                Icons.arrow_forward,
                color: Colors.blue[400],
                size: 20,
              )
            else
              Icon(
                Icons.arrow_back,
                color: Colors.green[400],
                size: 20,
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                _editRelationship(relationship, isOutgoing);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () {
                _deleteRelationship(relationship);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getGenderColor(String? gender) {
    switch (gender?.toLowerCase()) {
      case '男':
        return Colors.blue;
      case '女':
        return Colors.pink;
      default:
        return Colors.purple;
    }
  }

  /// 编辑关系
  Future<void> _editRelationship(
    CharacterRelationship relationship,
    bool isOutgoing,
  ) async {
    // 获取所有可选角色（排除当前角色）
    final repository = ref.read(characterRepositoryProvider);
    final allCharacters =
        await repository.getCharacters(widget.character.novelUrl);
    final availableCharacters =
        allCharacters.where((c) => c.id != widget.character.id).toList();

    if (!mounted) return;

    final result = await RelationshipEditDialog.show(
      context: context,
      currentCharacter: widget.character,
      availableCharacters: availableCharacters,
      relationship: relationship,
    );

    if (result != null) {
      // 刷新列表
      invalidateRelationshipProviders(ref, widget.character.id!);
      if (mounted) {
        ToastUtils.showSuccess('关系更新成功');
      }
    }
  }

  /// 删除关系
  Future<void> _deleteRelationship(CharacterRelationship relationship) async {
    // 二次确认
    final confirmed = await ConfirmDialog.show(
      context,
      title: '删除关系',
      message: '确定要删除 "${relationship.relationshipType}" 这个关系吗？\n此操作无法撤销。',
      confirmText: '删除',
      icon: Icons.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(characterRelationRepositoryProvider);
      await repository.deleteRelationship(relationship.id!);

      // 刷新列表
      invalidateRelationshipProviders(ref, widget.character.id!);

      if (mounted) {
        ToastUtils.showSuccess('关系删除成功');
      }
    } catch (e) {
      debugPrint('❌ 删除关系失败: $e');
      if (mounted) {
        ToastUtils.showError('删除失败: $e');
      }
    }
  }
}
