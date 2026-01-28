import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../services/database_service.dart';
import '../utils/toast_utils.dart';

/// 角色关系图可视化页面 - 使用力导向布局
///
/// 特性:
/// - 力导向自动布局 - 避免节点重叠
/// - 交互式拖拽 - 用户可以拖动节点调整位置
/// - 缩放和平移 - 双指缩放,单指拖动画布
/// - 动态节点大小 - 根据关系数量自动调整
/// - 颜色编码 - 按性别区分角色
/// - 高性能 - 支持大量节点渲染
class CharacterRelationshipGraphScreen extends StatefulWidget {
  final Character character;

  const CharacterRelationshipGraphScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterRelationshipGraphScreen> createState() =>
      _CharacterRelationshipGraphScreenState();
}

class _CharacterRelationshipGraphScreenState
    extends State<CharacterRelationshipGraphScreen> {
  final DatabaseService _databaseService = DatabaseService();

  // 控制器
  late final ForceDirectedGraphController<int> _controller;

  // 数据
  List<Character> _allCharacters = [];
  List<CharacterRelationship> _relationships = [];

  // 角色映射表: id -> Character
  final Map<int, Character> _characterMap = {};

  // 关系列表映射表: (sourceId, targetId) -> CharacterRelationship
  final Map<String, CharacterRelationship> _relationshipMap = {};

  // 头像缓存
  final Map<int, ImageProvider> _avatarProviders = {};

  bool _isLoading = true;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = ForceDirectedGraphController<int>(
      minScale: 0.3,
      maxScale: 3.0,
    )..setOnScaleChange((scale) {
        if (mounted) {
          setState(() {
            _currentScale = scale;
          });
        }
      });
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 加载关系数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 加载所有角色
      final allCharacters =
          await _databaseService.getCharacters(widget.character.novelUrl);

      // 加载当前角色的所有关系
      final relationships =
          await _databaseService.getRelationships(widget.character.id!);

      // 收集相关角色ID
      final relatedCharacterIds = <int>{};
      for (final rel in relationships) {
        relatedCharacterIds.add(rel.sourceCharacterId);
        relatedCharacterIds.add(rel.targetCharacterId);
      }

      // 过滤出相关角色
      final relatedCharacters = allCharacters
          .where((c) => c.id != null && relatedCharacterIds.contains(c.id))
          .toList();

      // 构建映射表
      for (final character in relatedCharacters) {
        if (character.id != null) {
          _characterMap[character.id!] = character;
        }
      }

      for (final rel in relationships) {
        final key = '${rel.sourceCharacterId}-${rel.targetCharacterId}';
        _relationshipMap[key] = rel;
      }

      // 预加载头像
      await _preloadAvatars(relatedCharacters);

      // 构建图数据
      _buildGraph(relatedCharacters, relationships);

      setState(() {
        _allCharacters = relatedCharacters;
        _relationships = relationships;
        _isLoading = false;
      });

      debugPrint(
          '✅ 关系图加载完成: ${_characterMap.length} 个节点, ${relationships.length} 条边');
    } catch (e) {
      debugPrint('❌ 加载关系图数据失败: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ToastUtils.showError('加载数据失败: $e');
      }
    }
  }

  /// 预加载头像
  Future<void> _preloadAvatars(List<Character> characters) async {
    for (final character in characters) {
      if (character.id == null) continue;

      if (character.cachedImageUrl != null &&
          character.cachedImageUrl!.isNotEmpty) {
        try {
          final imageFile = File(character.cachedImageUrl!);
          if (await imageFile.exists()) {
            _avatarProviders[character.id!] = FileImage(imageFile);
          }
        } catch (e) {
          debugPrint('⚠️ 加载头像失败: ${character.name}, $e');
        }
      }
    }
  }

  /// 构建图数据
  void _buildGraph(
    List<Character> characters,
    List<CharacterRelationship> relationships,
  ) {
    // 添加所有节点
    for (final character in characters) {
      if (character.id != null) {
        _controller.addNode(character.id!);
      }
    }

    // 添加所有边
    for (final rel in relationships) {
      _controller.addEdgeByData(
        rel.sourceCharacterId,
        rel.targetCharacterId,
      );
    }

    // 首次加载后居中
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.center();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name} - 关系图'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          // 显示缩放比例
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${(_currentScale * 100).toInt()}%',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // 重新居中
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: '适应屏幕',
            onPressed: () {
              _controller.center();
              ToastUtils.showSuccess('已重新居中');
            },
          ),
          // 定位到中心角色
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: '定位到主角',
            onPressed: widget.character.id != null
                ? () {
                    _controller.locateTo(widget.character.id!);
                    ToastUtils.showSuccess('已定位到${widget.character.name}');
                  }
                : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characterMap.isEmpty
              ? _buildEmptyState()
              : _buildForceDirectedGraph(),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '还没有任何关系',
            style: TextStyle(
                fontSize: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  /// 构建关系图
  Widget _buildForceDirectedGraph() {
    return ForceDirectedGraphWidget<int>(
      controller: _controller,
      onDraggingStart: (characterId) {
        final character = _characterMap[characterId];
        debugPrint('开始拖拽: ${character?.name}');
      },
      onDraggingEnd: (characterId) {
        final character = _characterMap[characterId];
        debugPrint('结束拖拽: ${character?.name}');
      },
      onDraggingUpdate: (characterId) {
        // 拖拽中,可以添加实时更新逻辑
      },
      nodesBuilder: (context, nodeId) {
        return _buildNodeWidget(nodeId);
      },
      edgesBuilder: (context, sourceId, targetId, distance) {
        return _buildEdgeWidget(sourceId, targetId, distance);
      },
    );
  }

  /// 构建节点Widget
  Widget _buildNodeWidget(int characterId) {
    final character = _characterMap[characterId];

    if (character == null) {
      return const SizedBox.shrink();
    }

    // 计算节点的度数(关系数量)
    final degree = _relationships
        .where((r) =>
            r.sourceCharacterId == characterId ||
            r.targetCharacterId == characterId)
        .length;

    // 是否是中心节点
    final isCenter = character.id == widget.character.id;

    // 根据度数和是否是中心节点计算大小
    final baseSize = isCenter ? 70.0 : 50.0;
    final size = baseSize + degree * 2.0;
    final maxSize = 90.0;
    final finalSize = size > maxSize ? maxSize : size;

    return GestureDetector(
      onTap: () {
        _showNodeDetails(character, degree);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 节点圆形
          Container(
            width: finalSize,
            height: finalSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCenter
                    ? [
                        Colors.orange.shade400,
                        Colors.orange.shade600,
                      ]
                    : [
                        _getGenderColor(character.gender)
                            .withValues(alpha: 0.9),
                        _getGenderColor(character.gender),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isCenter
                      ? Colors.orange.withValues(alpha: 0.5)
                      : _getGenderColor(character.gender)
                          .withValues(alpha: 0.4),
                  blurRadius: isCenter ? 16 : 12,
                  spreadRadius: isCenter ? 3 : 2,
                ),
              ],
              border: Border.all(
                color: isCenter
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.7),
                width: isCenter ? 4 : 3,
              ),
            ),
            child: ClipOval(
              child: _avatarProviders.containsKey(character.id)
                  ? Image(
                      image: _avatarProviders[character.id]!,
                      width: finalSize,
                      height: finalSize,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        character.name.isNotEmpty ? character.name[0] : '?',
                        style: TextStyle(
                          fontSize: finalSize * 0.4,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.surface,
                          shadows: [
                            Shadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // 角色名称标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCenter
                  ? Colors.orange.shade100
                  : Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCenter
                    ? Colors.orange.shade300
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              character.name,
              style: TextStyle(
                fontSize: isCenter ? 14 : 12,
                fontWeight: isCenter ? FontWeight.bold : FontWeight.w600,
                color: isCenter
                    ? Colors.orange.shade900
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.87),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建边Widget
  Widget _buildEdgeWidget(int sourceId, int targetId, double distance) {
    // 查找这两个节点之间的关系
    final key = '$sourceId-$targetId';
    final reverseKey = '$targetId-$sourceId';

    final relationship = _relationshipMap[key] ?? _relationshipMap[reverseKey];

    if (relationship == null) {
      // 默认灰色线
      return Container(
        height: 2,
        width: distance,
        color: Theme.of(context).colorScheme.outlineVariant,
      );
    }

    // 根据关系类型返回不同颜色和粗细
    final color = _getRelationshipColor(relationship.relationshipType);
    final thickness = _getRelationshipThickness(relationship.relationshipType);

    return Container(
      height: thickness,
      width: distance,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.6),
            color,
            color.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  /// 显示节点详情
  void _showNodeDetails(Character character, int degree) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.person,
              color: _getGenderColor(character.gender),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                character.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_avatarProviders.containsKey(character.id))
                Center(
                  child: ClipOval(
                    child: Image(
                      image: _avatarProviders[character.id]!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('关系数量', '$degree 个'),
              if (character.gender != null && character.gender!.isNotEmpty)
                _buildDetailRow('性别', character.gender!),
              if (character.age != null)
                _buildDetailRow('年龄', '${character.age} 岁'),
              if (character.appearanceFeatures != null &&
                  character.appearanceFeatures!.isNotEmpty)
                _buildDetailRow('外貌特征', character.appearanceFeatures!),
              if (character.personality != null &&
                  character.personality!.isNotEmpty)
                _buildDetailRow('性格', character.personality!),
              if (character.backgroundStory != null &&
                  character.backgroundStory!.isNotEmpty)
                _buildDetailRow('背景故事', character.backgroundStory!,
                    maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.87),
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 获取性别颜色
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

  /// 获取关系类型颜色
  Color _getRelationshipColor(String relationshipType) {
    switch (relationshipType) {
      case '亲密关系':
        return Colors.red.shade600;
      case '家庭':
        return Colors.teal.shade600;
      case '恋人':
        return Colors.pink.shade500;
      case '朋友':
        return Colors.blue.shade600;
      case '敌对':
        return Colors.red.shade800;
      case '竞争对手':
        return Colors.orange.shade600;
      case '同事':
        return Colors.amber.shade700;
      case '师徒':
        return Colors.indigo.shade600;
      case '盟友':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  /// 获取关系类型线条粗细
  double _getRelationshipThickness(String relationshipType) {
    switch (relationshipType) {
      case '亲密关系':
        return 4.0;
      case '恋人':
        return 3.5;
      case '家庭':
        return 3.0;
      case '师徒':
        return 2.5;
      default:
        return 2.0;
    }
  }
}
