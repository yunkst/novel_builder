import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../services/database_service.dart';
import '../widgets/relationship_edit_dialog.dart';
import 'character_relationship_graph_screen.dart';

/// 角色关系列表页面
///
/// 显示某个角色的所有关系，支持按Tab分类查看：
/// - Tab 1: 全部关系 (出度 + 入度)
/// - Tab 2: Ta的关系 (出度：Ta → 其他人)
/// - Tab 3: 关系Ta的人 (入度：其他人 → Ta)
class CharacterRelationshipScreen extends StatefulWidget {
  final Character character;

  const CharacterRelationshipScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterRelationshipScreen> createState() =>
      _CharacterRelationshipScreenState();
}

class _CharacterRelationshipScreenState
    extends State<CharacterRelationshipScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();

  late TabController _tabController;

  // 数据状态
  List<CharacterRelationship> _outgoingRelationships = [];
  List<CharacterRelationship> _incomingRelationships = [];

  // 角色缓存（用于显示目标角色信息）
  final Map<int, Character> _characterCache = {};

  // 加载状态
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载关系数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 并行加载两种关系数据
      final results = await Future.wait([
        _databaseService.getOutgoingRelationships(widget.character.id!),
        _databaseService.getIncomingRelationships(widget.character.id!),
      ]);

      final outgoing = results[0];
      final incoming = results[1];

      // 收集所有相关的角色ID
      final characterIds = <int>{};
      for (final rel in outgoing) {
        characterIds.add(rel.sourceCharacterId);
        characterIds.add(rel.targetCharacterId);
      }
      for (final rel in incoming) {
        characterIds.add(rel.sourceCharacterId);
        characterIds.add(rel.targetCharacterId);
      }
      characterIds.remove(widget.character.id!); // 移除当前角色

      // 加载相关角色信息
      await _loadCharacters(characterIds.toList());

      setState(() {
        _outgoingRelationships = outgoing;
        _incomingRelationships = incoming;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 加载关系失败: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载关系失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 加载角色信息
  Future<void> _loadCharacters(List<int> characterIds) async {
    if (characterIds.isEmpty) return;

    try {
      final novelUrl = widget.character.novelUrl;
      final characters =
          await _databaseService.getCharacters(novelUrl);

      // 过滤出相关的角色并缓存
      for (final character in characters) {
        if (character.id != null && characterIds.contains(character.id)) {
          _characterCache[character.id!] = character;
        }
      }
    } catch (e) {
      debugPrint('❌ 加载角色信息失败: $e');
    }
  }

  /// 添加新关系
  Future<void> _addRelationship() async {
    // 获取所有可选角色（排除当前角色）
    final allCharacters =
        await _databaseService.getCharacters(widget.character.novelUrl);
    final availableCharacters = allCharacters
        .where((c) => c.id != widget.character.id)
        .toList();

    if (availableCharacters.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('没有其他角色可以建立关系'),
            backgroundColor: Colors.orange,
          ),
        );
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
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('关系添加成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 查看关系图
  Future<void> _viewGraph() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterRelationshipGraphScreen(
          character: widget.character,
        ),
      ),
    );

    // 刷新列表
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name} - 人物关系'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Colors.white,
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ta的关系'),
            Tab(text: '关系Ta的人'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildTabView(),
    );
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildRelationshipList(_outgoingRelationships, isOutgoing: true),
        _buildRelationshipList(_incomingRelationships, isOutgoing: false),
      ],
    );
  }

  /// 构建关系列表
  Widget _buildRelationshipList(
    List<CharacterRelationship> relationships, {
    bool isOutgoing = true,
  }) {
    if (relationships.isEmpty) {
      return _buildEmptyState(isOutgoing);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: relationships.length,
      itemBuilder: (context, index) {
        return _buildRelationshipCard(
          relationships[index],
          isOutgoing: isOutgoing,
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
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
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
  }) {
    // 确定显示的目标角色
    final targetCharacterId = isOutgoing
        ? relationship.targetCharacterId
        : relationship.sourceCharacterId;

    final targetCharacter = _characterCache[targetCharacterId];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getGenderColor(targetCharacter?.gender),
          child: Text(
            targetCharacter?.name.isNotEmpty ?? false
                ? targetCharacter!.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
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
                    color: Colors.grey[600],
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
    final allCharacters =
        await _databaseService.getCharacters(widget.character.novelUrl);
    final availableCharacters = allCharacters
        .where((c) => c.id != widget.character.id)
        .toList();

    if (!mounted) return;

    final result = await RelationshipEditDialog.show(
      context: context,
      currentCharacter: widget.character,
      availableCharacters: availableCharacters,
      relationship: relationship,
    );

    if (result != null) {
      // 刷新列表
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('关系更新成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 删除关系
  Future<void> _deleteRelationship(CharacterRelationship relationship) async {
    // 二次确认
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除关系'),
        content: Text(
          '确定要删除 "${relationship.relationshipType}" 这个关系吗？\n此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _databaseService.deleteRelationship(relationship.id!);

      // 刷新列表
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('关系删除成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 删除关系失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
