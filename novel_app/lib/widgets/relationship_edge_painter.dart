import 'package:flutter/material.dart';
import 'package:graphview/graphview.dart';

/// 关系边绘制器
///
/// 在连线中间绘制关系类型标签
class RelationshipEdgePainter extends CustomPainter {
  final Graph graph;
  final Map<int, Offset> nodePositions;
  final Map<String, String> edgeLabels;
  final Map<String, double> edgeWeights;
  final double scale;

  RelationshipEdgePainter({
    required this.graph,
    required this.nodePositions,
    required this.edgeLabels,
    required this.edgeWeights,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制每一条边
    for (final edge in graph.edges) {
      final sourceNode = edge.source;
      final targetNode = edge.destination;

      final sourcePos = nodePositions[sourceNode];
      final targetPos = nodePositions[targetNode];

      if (sourcePos == null || targetPos == null) continue;

      // 获取边的标识和权重
      final edgeKey = _getEdgeKey(
        _getNodeId(sourceNode),
        _getNodeId(targetNode),
      );
      final weight = edgeWeights[edgeKey] ?? 1.0;
      final label = edgeLabels[edgeKey];

      // 绘制连线
      _drawEdge(canvas, sourcePos, targetPos, weight);

      // 绘制标签（如果有）
      if (label != null && label.isNotEmpty) {
        _drawLabel(canvas, sourcePos, targetPos, label, weight);
      }
    }
  }

  /// 绘制连线
  void _drawEdge(Canvas canvas, Offset start, Offset end, double weight) {
    final paint = Paint()
      ..color = weight > 1.5 ? Colors.orange : Colors.grey
      ..strokeWidth = weight > 1.5 ? 3.0 : 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  /// 绘制标签
  void _drawLabel(
    Canvas canvas,
    Offset start,
    Offset end,
    String label,
    double weight,
  ) {
    // 计算连线中点
    final midPoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    // 测量文字大小
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 12 / scale,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 绘制背景
    final padding = 8.0 / scale;
    final backgroundRect = Rect.fromCenter(
      center: midPoint,
      width: textPainter.width + padding * 2,
      height: textPainter.height + padding * 2,
    );

    final bgPaint = Paint()
      ..color = weight > 1.5 ? Colors.amber[100]! : Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = weight > 1.5 ? Colors.orange : Colors.grey
      ..strokeWidth = 1.0 / scale
      ..style = PaintingStyle.stroke;

    final rRect = RRect.fromRectAndRadius(
      backgroundRect,
      Radius.circular(4 / scale),
    );

    canvas.drawRRect(rRect, bgPaint);
    canvas.drawRRect(rRect, borderPaint);

    // 绘制文字
    textPainter.paint(
      canvas,
      Offset(
        midPoint.dx - textPainter.width / 2,
        midPoint.dy - textPainter.height / 2,
      ),
    );
  }

  /// 从节点对象获取ID
  int? _getNodeId(Node node) {
    final keyValue = node.key?.value;
    if (keyValue is int) return keyValue;
    if (keyValue != null) {
      final keyString = keyValue.toString();
      if (keyString.contains('Id(')) {
        final match = RegExp(r'\d+').firstMatch(keyString);
        if (match != null) return int.tryParse(match.group(0) ?? '');
      }
      return int.tryParse(keyString);
    }
    return null;
  }

  /// 根据ID获取节点
  Node? _getNodeById(dynamic id) {
    try {
      for (final node in graph.nodes) {
        final nodeId = _getNodeId(node);
        if (nodeId == id) return node;
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  /// 生成方向无关的边键
  String _getEdgeKey(int? id1, int? id2) {
    if (id1 == null || id2 == null) return '$id1-$id2';
    final smaller = id1 < id2 ? id1 : id2;
    final larger = id1 < id2 ? id2 : id1;
    return '$smaller-$larger';
  }

  @override
  bool shouldRepaint(covariant RelationshipEdgePainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.edgeLabels != edgeLabels ||
        oldDelegate.edgeWeights != edgeWeights;
  }
}
