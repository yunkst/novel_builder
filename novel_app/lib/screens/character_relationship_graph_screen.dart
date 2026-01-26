import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../services/database_service.dart';

/// 角色关系图可视化页面
///
/// 使用CustomPainter绘制关系网络图
/// - 节点：角色圆形头像
/// - 边：有向箭头 + 关系类型文字
/// - 交互：点击节点高亮相关关系
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

  // 数据
  List<Character> _allCharacters = [];
  List<CharacterRelationship> _relationships = [];

  // 布局数据
  final Map<int, Offset> _nodePositions = {};
  final Map<int, double> _nodeRadii = {};

  // 交互状态
  int? _selectedCharacterId;
  final Set<int> _highlightedNodeIds = {};
  final Set<CharacterRelationship> _highlightedRelationships = {};

  // 画布配置
  static const double _baseNodeRadius = 40.0;
  static const double _centerNodeRadius = 50.0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

      // 计算布局
      _calculateLayout(relatedCharacters, relationships);

      setState(() {
        _allCharacters = relatedCharacters;
        _relationships = relationships;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 加载关系图数据失败: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 计算节点布局（层次布局）
  void _calculateLayout(
    List<Character> characters,
    List<CharacterRelationship> relationships,
  ) {
    _nodePositions.clear();
    _nodeRadii.clear();

    if (characters.isEmpty) return;

    // 中心节点（当前角色）
    final centerNodeId = widget.character.id!;

    // 找到画布中心（假设尺寸）
    final center = Offset.zero; // 临时，绘制时调整

    // 设置中心节点位置
    _nodePositions[centerNodeId] = center;
    _nodeRadii[centerNodeId] = _centerNodeRadius;

    // 其他节点按圆形分布
    final otherNodes = characters.where((c) => c.id != centerNodeId).toList();

    if (otherNodes.isEmpty) return;

    final radius = _calculateCircleRadius(otherNodes.length);
    final angleStep = 2 * math.pi / otherNodes.length;

    for (int i = 0; i < otherNodes.length; i++) {
      final character = otherNodes[i];
      final angle = i * angleStep - math.pi / 2; // 从顶部开始

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (character.id != null) {
        _nodePositions[character.id!] = Offset(x, y);
        _nodeRadii[character.id!] = _baseNodeRadius;
      }
    }
  }

  /// 计算圆形分布的半径
  double _calculateCircleRadius(int nodeCount) {
    // 基础半径 + 每个节点增加的间距
    return 150.0 + nodeCount * 10.0;
  }

  /// 处理节点点击
  void _handleNodeTap(int characterId) {
    setState(() {
      if (_selectedCharacterId == characterId) {
        // 取消选择
        _selectedCharacterId = null;
        _highlightedNodeIds.clear();
        _highlightedRelationships.clear();
      } else {
        // 选中新节点
        _selectedCharacterId = characterId;
        _updateHighlights(characterId);
      }
    });
  }

  /// 更新高亮状态
  void _updateHighlights(int characterId) {
    _highlightedNodeIds.clear();
    _highlightedRelationships.clear();

    // 找出所有相关关系
    for (final rel in _relationships) {
      if (rel.sourceCharacterId == characterId) {
        _highlightedRelationships.add(rel);
        _highlightedNodeIds.add(rel.targetCharacterId);
      } else if (rel.targetCharacterId == characterId) {
        _highlightedRelationships.add(rel);
        _highlightedNodeIds.add(rel.sourceCharacterId);
      }
    }

    // 添加当前节点
    _highlightedNodeIds.add(characterId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name} - 关系图'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置视图',
            onPressed: () {
              setState(() {
                _selectedCharacterId = null;
                _highlightedNodeIds.clear();
                _highlightedRelationships.clear();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allCharacters.isEmpty
              ? _buildEmptyState()
              : _buildGraph(),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有任何关系',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 构建关系图
  Widget _buildGraph() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 2.0,
      constrained: false,
      child: SizedBox(
        // 设置固定尺寸，避免 CustomPaint 无限大小错误
        width: 800,
        height: 800,
        child: GestureDetector(
          onTapDown: (details) {
            // 检测是否点击了节点
            _checkNodeTap(details.globalPosition, details.localPosition);
          },
          child: CustomPaint(
            size: const Size(800, 800),
            painter: _RelationshipGraphPainter(
              characters: _allCharacters,
              relationships: _relationships,
              nodePositions: _nodePositions,
              nodeRadii: _nodeRadii,
              selectedCharacterId: _selectedCharacterId,
              highlightedNodeIds: _highlightedNodeIds,
              highlightedRelationships: _highlightedRelationships,
              centerCharacterId: widget.character.id!,
            ),
          ),
        ),
      ),
    );
  }

  /// 检测节点点击
  void _checkNodeTap(Offset globalPosition, Offset localPosition) {
    // 获取CustomPaint的实际尺寸
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final canvasSize = renderBox.size;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

    // 调整节点位置（从相对坐标转为绝对坐标）
    for (final entry in _nodePositions.entries) {
      final characterId = entry.key;
      final relativePos = entry.value;
      final radius = _nodeRadii[characterId] ?? _baseNodeRadius;

      final absolutePos = Offset(
        center.dx + relativePos.dx,
        center.dy + relativePos.dy,
      );

      // 检测点击是否在节点范围内
      final distance = (localPosition - absolutePos).distance;
      if (distance <= radius) {
        _handleNodeTap(characterId);
        return;
      }
    }

    // 点击空白处，取消选择
    setState(() {
      _selectedCharacterId = null;
      _highlightedNodeIds.clear();
      _highlightedRelationships.clear();
    });
  }
}

/// 关系图绘制器
class _RelationshipGraphPainter extends CustomPainter {
  final List<Character> characters;
  final List<CharacterRelationship> relationships;
  final Map<int, Offset> nodePositions;
  final Map<int, double> nodeRadii;
  final int? selectedCharacterId;
  final Set<int> highlightedNodeIds;
  final Set<CharacterRelationship> highlightedRelationships;
  final int centerCharacterId;

  _RelationshipGraphPainter({
    required this.characters,
    required this.relationships,
    required this.nodePositions,
    required this.nodeRadii,
    this.selectedCharacterId,
    required this.highlightedNodeIds,
    required this.highlightedRelationships,
    required this.centerCharacterId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 先绘制边（在节点下方）
    _drawEdges(canvas, center);

    // 再绘制节点
    _drawNodes(canvas, center);
  }

  /// 绘制边（关系）
  void _drawEdges(Canvas canvas, Offset center) {
    final edgePaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final highlightedEdgePaint = Paint()
      ..color = Colors.blue[600]!
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final rel in relationships) {
      final sourcePos = nodePositions[rel.sourceCharacterId];
      final targetPos = nodePositions[rel.targetCharacterId];

      if (sourcePos == null || targetPos == null) continue;

      final sourceAbsolute = center + sourcePos;
      final targetAbsolute = center + targetPos;

      // 判断是否高亮
      final isHighlighted = highlightedRelationships.contains(rel);
      final paint = isHighlighted ? highlightedEdgePaint : edgePaint;

      // 绘制线段
      canvas.drawLine(sourceAbsolute, targetAbsolute, paint);

      // 绘制箭头
      _drawArrow(canvas, sourceAbsolute, targetAbsolute, paint);

      // 绘制关系类型文字
      _drawRelationshipLabel(canvas, sourceAbsolute, targetAbsolute,
          rel.relationshipType, isHighlighted);
    }
  }

  /// 绘制箭头
  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from);
    final length = direction.distance;
    if (length < 1) return;

    final normalized = direction / length;
    final arrowSize = 10.0;

    // 计算箭头位置（线段终点略向内）
    final targetRadius = 40.0; // 使用基础半径

    final arrowTip = to - normalized * targetRadius;
    final arrowBase = arrowTip - normalized * arrowSize;

    // 计算箭头两翼
    final perpendicular = Offset(-normalized.dy, normalized.dx);
    final arrowLeft = arrowBase + perpendicular * (arrowSize / 2);
    final arrowRight = arrowBase - perpendicular * (arrowSize / 2);

    // 绘制箭头三角形
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(arrowLeft.dx, arrowLeft.dy)
      ..lineTo(arrowRight.dx, arrowRight.dy)
      ..close();

    canvas.drawPath(path, arrowPaint);
  }

  /// 绘制关系类型标签
  void _drawRelationshipLabel(Canvas canvas, Offset from, Offset to,
      String label, bool isHighlighted) {
    final midPoint = (from + to) / 2;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 12,
          color: isHighlighted ? Colors.blue[700] : Colors.grey[700],
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 绘制背景
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final bgRect = Rect.fromCenter(
      center: midPoint,
      width: textPainter.width + 8,
      height: textPainter.height + 4,
    );

    final rRect = RRect.fromRectAndRadius(bgRect, Radius.circular(4));
    canvas.drawRRect(rRect, bgPaint);

    // 绘制文字
    textPainter.paint(
      canvas,
      Offset(midPoint.dx - textPainter.width / 2,
          midPoint.dy - textPainter.height / 2),
    );
  }

  /// 绘制节点（角色）
  void _drawNodes(Canvas canvas, Offset center) {
    for (final character in characters) {
      if (character.id == null) continue;

      final pos = nodePositions[character.id];
      final radius = nodeRadii[character.id];

      if (pos == null || radius == null) continue;

      final absolutePos = center + pos;

      // 判断节点状态
      final isCenter = character.id == centerCharacterId;
      final isSelected = character.id == selectedCharacterId;
      final isHighlighted = highlightedNodeIds.contains(character.id);

      _drawSingleNode(
        canvas: canvas,
        position: absolutePos,
        radius: radius,
        character: character,
        isCenter: isCenter,
        isSelected: isSelected,
        isHighlighted: isHighlighted,
      );
    }
  }

  /// 绘制单个节点
  void _drawSingleNode({
    required Canvas canvas,
    required Offset position,
    required double radius,
    required Character character,
    required bool isCenter,
    required bool isSelected,
    required bool isHighlighted,
  }) {
    // 外圈高亮
    if (isSelected || isHighlighted) {
      final highlightPaint = Paint()
        ..color = isCenter ? Colors.orange : Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;

      canvas.drawCircle(position, radius + 4, highlightPaint);
    }

    // 节点背景
    final bgColor = _getGenderColor(character.gender);
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, radius, bgPaint);

    // 节点边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(position, radius, borderPaint);

    // 绘制名字首字母
    final initial = character.name.isNotEmpty
        ? character.name[0].toUpperCase()
        : '?';

    final textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // 绘制文字阴影
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          foreground: Paint()
            ..color = Colors.black.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    shadowPainter.layout();
    shadowPainter.paint(
      canvas,
      Offset(position.dx - shadowPainter.width / 2 + 1,
          position.dy - shadowPainter.height / 2 + 1),
    );

    // 绘制文字
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2),
    );

    // 绘制角色名（节点下方）
    final namePainter = TextPainter(
      text: TextSpan(
        text: character.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    namePainter.layout(maxWidth: radius * 2.5);
    namePainter.paint(
      canvas,
      Offset(position.dx - namePainter.width / 2, position.dy + radius + 4),
    );
  }

  Color _getGenderColor(String? gender) {
    switch (gender?.toLowerCase()) {
      case '男':
        return Colors.blue[600]!;
      case '女':
        return Colors.pink[400]!;
      default:
        return Colors.purple;
    }
  }

  @override
  bool shouldRepaint(_RelationshipGraphPainter oldDelegate) {
    return oldDelegate.selectedCharacterId != selectedCharacterId ||
        oldDelegate.highlightedNodeIds.length != highlightedNodeIds.length ||
        oldDelegate.highlightedRelationships.length !=
            highlightedRelationships.length;
  }
}
