import 'package:flutter/material.dart';
import 'package:graphview/graphview.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../services/database_service.dart';
import '../utils/edge_weight_manager.dart';
import '../widgets/character_detail_dialog.dart';
import 'dart:async';

/// 增强版角色关系图可视化页面
///
/// 使用graphview库实现力导向布局算法
/// 显示所有角色之间的关系网络
class EnhancedRelationshipGraphScreen extends StatefulWidget {
  final String novelUrl;
  final Character? initialCharacter;

  const EnhancedRelationshipGraphScreen({
    super.key,
    required this.novelUrl,
    this.initialCharacter,
  });

  @override
  State<EnhancedRelationshipGraphScreen> createState() =>
      _EnhancedRelationshipGraphScreenState();
}

class _EnhancedRelationshipGraphScreenState
    extends State<EnhancedRelationshipGraphScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final TransformationController _transformationController =
      TransformationController();

  // 数据
  List<Character> _allCharacters = [];
  List<CharacterRelationship> _relationships = [];

  // GraphView相关
  late Graph _graph;
  late FruchtermanReingoldAlgorithm _algorithm;

  // 节点关系数量缓存(用于调整节点大小)
  final Map<int, int> _nodeConnectionCount = {};

  // 边权重管理器
  final EdgeWeightManager _edgeWeightManager = EdgeWeightManager();

  // 交互状态
  int? _selectedNodeId;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  /// 加载关系数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 加载所有角色
      final allCharacters =
          await _databaseService.getCharacters(widget.novelUrl);

      if (allCharacters.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 加载所有角色的关系
      final Set<CharacterRelationship> allRelationships = {};
      for (final character in allCharacters) {
        if (character.id != null) {
          final rels = await _databaseService.getRelationships(character.id!);
          allRelationships.addAll(rels);
        }
      }

      // 构建图结构
      _buildGraphStructure(allCharacters, allRelationships.toList());

      setState(() {
        _allCharacters = allCharacters;
        _relationships = allRelationships.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 加载增强关系图数据失败: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// 构建图结构
  void _buildGraphStructure(
    List<Character> characters,
    List<CharacterRelationship> relationships,
  ) {
    // 创建图
    _graph = Graph()..isTree = false;

    // 创建节点映射
    final Map<int, Node> nodeMap = {};

    // 创建节点
    for (final character in characters) {
      final node = Node.Id(character.id);
      nodeMap[character.id!] = node;
      // 初始化关系计数
      _nodeConnectionCount[character.id!] = 0;
    }

    // 创建边 - 去重（因为关系是双向的）
    final Set<String> edgeSet = {};

    for (final relationship in relationships) {
      final sourceId = relationship.sourceCharacterId;
      final targetId = relationship.targetCharacterId;

      // 创建边的唯一标识（忽略方向）
      final edgeKey = '${sourceId < targetId ? sourceId : targetId}-${sourceId < targetId ? targetId : sourceId}';

      if (!edgeSet.contains(edgeKey)) {
        edgeSet.add(edgeKey);

        final sourceNode = nodeMap[sourceId];
        final targetNode = nodeMap[targetId];

        if (sourceNode != null && targetNode != null) {
          _graph.addEdge(sourceNode, targetNode);

          // 统计每个节点的关系数量
          _nodeConnectionCount[sourceId] = (_nodeConnectionCount[sourceId] ?? 0) + 1;
          _nodeConnectionCount[targetId] = (_nodeConnectionCount[targetId] ?? 0) + 1;
        }
      }
    }

    // 根据节点数量计算最优迭代次数
    final iterations = _calculateIterations(characters.length);

    // 创建力导向布局算法 - 使用优化参数
    final config = FruchtermanReingoldConfiguration(
      iterations: iterations,
      repulsionRate: 0.2,          // 斥力强度
      attractionRate: 0.06,        // 引力强度(降低使节点更分散)
      repulsionPercentage: 0.4,
      attractionPercentage: 0.15,
      clusterPadding: 50,          // 增加聚类间距
      epsilon: 0.0001,
      lerpFactor: 0.05,
      movementThreshold: 0.6,
      shuffleNodes: true,          // 随机初始位置
    );
    _algorithm = FruchtermanReingoldAlgorithm(config);
  }

  /// 根据节点数量计算迭代次数
  int _calculateIterations(int nodeCount) {
    if (nodeCount < 10) return 500;
    if (nodeCount < 20) return 800;
    if (nodeCount < 30) return 1000;
    if (nodeCount < 50) return 1500;
    return 2000;
  }

  /// 根据关系数量计算节点大小
  double _calculateNodeSize(int characterId) {
    final connectionCount = _nodeConnectionCount[characterId] ?? 0;
    // 基础大小60,每个关系增加5,最大120
    final size = 60.0 + connectionCount * 5.0;
    return size.clamp(60.0, 120.0);
  }

  /// 根据性别获取颜色
  Color _getGenderColor(String? gender) {
    switch (gender?.toLowerCase()) {
      case '男':
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.6);
      case '女':
        return Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4);
      default:
        return Theme.of(context).colorScheme.tertiary;
    }
  }

  /// 获取角色名称的首字母
  String _getCharacterInitial(Character character) {
    if (character.name.isNotEmpty) {
      return character.name[0].toUpperCase();
    }
    return '?';
  }

  /// 处理节点单击事件
  void _handleNodeTap(int characterId) {
    // 检查是否点击已选中的节点
    if (_selectedNodeId == characterId) {
      // 取消选中
      _resetNodeSelection();
    } else {
      // 选中新节点
      _selectNode(characterId);
    }
  }

  /// 选中节点并加强相关引力
  void _selectNode(int nodeId) {
    setState(() {
      _selectedNodeId = nodeId;

      // 找出与该节点相连的所有节点
      final connectedNodeIds = <int>[];
      for (final rel in _relationships) {
        if (rel.sourceCharacterId == nodeId) {
          connectedNodeIds.add(rel.targetCharacterId);
        } else if (rel.targetCharacterId == nodeId) {
          connectedNodeIds.add(rel.sourceCharacterId);
        }
      }

      // 提高这些边的权重（用于未来的布局增强）
      _edgeWeightManager.enhanceNodeEdges(nodeId, connectedNodeIds);

      // 重新构建图以应用新的权重
      _buildGraphStructure(_allCharacters, _relationships);
    });
  }

  /// 重置节点选择
  void _resetNodeSelection() {
    setState(() {
      _selectedNodeId = null;
      _edgeWeightManager.reset();

      // 重新构建图以重置权重
      _buildGraphStructure(_allCharacters, _relationships);
    });
  }

  /// 处理节点双击事件
  void _handleNodeDoubleTap(int characterId) {
    // 找到对应的角色
    final character = _allCharacters.firstWhere(
      (c) => c.id == characterId,
      orElse: () => Character(
        id: characterId,
        novelUrl: widget.novelUrl,
        name: '未知',
      ),
    );

    // 显示详情对话框
    CharacterDetailDialog.show(context, character);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_allCharacters.isNotEmpty ? "全局角色关系图" : "角色关系图"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (_allCharacters.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '角色: ${_allCharacters.length} | 关系: ${_relationships.length}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新加载',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '使用说明',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('使用说明'),
                  content: const SingleChildScrollView(
                    child: ListBody(
                      children: [
                        Text('🔍 交互操作:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• 捏合手势: 缩放视图 (0.01x - 10.0x)'),
                        Text('• 拖拽: 移动视图位置'),
                        Text('• 单击节点: 选中节点，查看关系'),
                        Text('• 双击节点: 查看角色详情'),
                        Text('• 点击空白: 取消选中'),
                        Text(''),
                        Text('🎨 节点说明:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• 蓝色: 男性角色'),
                        Text('• 粉色: 女性角色'),
                        Text('• 紫色: 性别未知'),
                        Text('• 节点大小: 根据关系数量自动调整'),
                        Text('• 橙色徽章: 关系数量>3时显示'),
                        Text(''),
                        Text('🔗 布局特点:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• 关系紧密的角色会自动靠近'),
                        Text('• 连接多的角色节点更大'),
                        Text('• 使用Fruchterman-Reingold算法'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 主图区域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _allCharacters.isEmpty
                        ? _buildEmptyView()
                        : _buildGraphView(),
          ),
          // 选中节点的关系信息面板
          if (_selectedNodeId != null)
            _buildRelationshipPanel(),
        ],
      ),
    );
  }

  /// 构建关系信息面板
  Widget _buildRelationshipPanel() {
    // 查找选中的角色
    final selectedCharacter = _allCharacters.firstWhere(
      (c) => c.id == _selectedNodeId,
      orElse: () => Character(
        id: _selectedNodeId,
        novelUrl: widget.novelUrl,
        name: '未知',
      ),
    );

    // 找出所有与该角色相关的关系
    final relationships = _relationships
        .where((r) =>
            r.sourceCharacterId == _selectedNodeId ||
            r.targetCharacterId == _selectedNodeId)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${selectedCharacter.name} 的关系 (${relationships.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedNodeId = null;
                    });
                  },
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
          // 关系列表
          if (relationships.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无关系数据'),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: relationships.length,
                itemBuilder: (context, index) {
                  final rel = relationships[index];
                  final isSource = rel.sourceCharacterId == _selectedNodeId;
                  final otherCharacterId = isSource
                      ? rel.targetCharacterId
                      : rel.sourceCharacterId;

                  final otherCharacter = _allCharacters.firstWhere(
                    (c) => c.id == otherCharacterId,
                    orElse: () => Character(
                      id: otherCharacterId,
                      novelUrl: widget.novelUrl,
                      name: '未知',
                    ),
                  );

                  return Container(
                    width: 200,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 关系类型
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rel.relationshipType,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 关系方向描述
                        Text(
                          isSource ? '→ ${otherCharacter.name}' : '← ${otherCharacter.name}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rel.description != null &&
                            rel.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            rel.description!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 构建空视图
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '暂无角色数据',
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 8),
          Text(
            '请先添加角色后再查看关系图',
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  /// 构建关系图视图 - 使用graphview
  Widget _buildGraphView() {
    // 创建角色ID到角色的映射
    final Map<int, Character> characterMap = {
      for (var c in _allCharacters) if (c.id != null) c.id!: c
    };

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.01,
      maxScale: 10.0,
      constrained: false,
      boundaryMargin: EdgeInsets.zero,
      child: GraphViewCustomPainter(
        graph: _graph,
        algorithm: _algorithm,
        paint: Paint()
          ..color = Theme.of(context).colorScheme.surface
          ..style = PaintingStyle.fill,
        builder: (Node node) {
          // 获取对应的角色
          // node.key 是 ValueKey 对象,需要访问 .value 属性
          final keyValue = node.key?.value;

          // 尝试将keyValue转换为int
          int? characterId;
          if (keyValue is int) {
            characterId = keyValue;
          } else if (keyValue != null) {
            // 如果不是int,尝试从字符串中提取数字
            final keyString = keyValue.toString();
            if (keyString.contains('Id(')) {
              final match = RegExp(r'\d+').firstMatch(keyString);
              if (match != null) {
                characterId = int.tryParse(match.group(0) ?? '');
              }
            } else {
              characterId = int.tryParse(keyString);
            }
          }

          final character = characterMap[characterId];

          if (character == null) {
            // 如果找不到角色,显示灰色问号节点
            final size = _calculateNodeSize(characterId ?? 0);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
              ),
              child: Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            );
          }

          // 计算节点大小(根据关系数量)
          final nodeSize = _calculateNodeSize(characterId ?? 0);
          final connectionCount = _nodeConnectionCount[characterId ?? 0] ?? 0;
          final isSelected = _selectedNodeId == characterId;

          // 自定义节点渲染 - 添加手势检测
          return GestureDetector(
            onTap: () => _handleNodeTap(characterId ?? 0),
            onDoubleTap: () => _handleNodeDoubleTap(characterId ?? 0),
            child: Container(
              width: nodeSize,
              height: nodeSize,
              decoration: BoxDecoration(
                color: _getGenderColor(character.gender),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.surface,
                  width: isSelected ? 5 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  // 选中状态添加发光效果
                  if (isSelected)
                    BoxShadow(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // 中心显示角色首字母
                  Center(
                    child: Text(
                      _getCharacterInitial(character),
                      style: TextStyle(
                        fontSize: nodeSize * 0.3,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                  // 如果关系数>3,在右下角显示数量徽章
                  if (connectionCount > 3)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            '$connectionCount',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.surface,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
