import 'package:flutter/material.dart';
import 'dart:math' as math;

/// CustomPainter 绘制示例
///
/// 展示如何用CustomPainter绘制简单的力导向图
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CustomPainter 示例',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CustomPainterExample(),
    );
  }
}

/// CustomPainter 示例页面
class CustomPainterExample extends StatefulWidget {
  const CustomPainterExample({super.key});

  @override
  State<CustomPainterExample> createState() => _CustomPainterExampleState();
}

class _CustomPainterExampleState extends State<CustomPainterExample> {
  // 简单的节点数据
  final List<NodeData> _nodes = [
    NodeData(id: 1, x: 200, y: 300, color: Colors.blue, label: '张三'),
    NodeData(id: 2, x: 400, y: 200, color: Colors.pink, label: '李四'),
    NodeData(id: 3, x: 400, y: 400, color: Colors.blue, label: '王五'),
    NodeData(id: 4, x: 600, y: 300, color: Colors.purple, label: '赵六'),
  ];

  // 边(关系)数据
  final List<EdgeData> _edges = [
    EdgeData(from: 1, to: 2),
    EdgeData(from: 1, to: 3),
    EdgeData(from: 2, to: 4),
    EdgeData(from: 3, to: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CustomPainter 绘制力导向图'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'CustomPainter 自定义绘制',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 800,
              height: 600,
              child: CustomPaint(
                painter: ForceDirectedGraphPainter(
                  nodes: _nodes,
                  edges: _edges,
                ),
                child: const Center(
                  child: Text('画布区域'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '特点:\n'
                '• 完全控制绘制逻辑\n'
                '• 可以绘制任何图形\n'
                '• 性能较好\n'
                '• 需要手动处理交互',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 节点数据模型
class NodeData {
  final int id;
  final double x;
  final double y;
  final Color color;
  final String label;

  NodeData({
    required this.id,
    required this.x,
    required this.y,
    required this.color,
    required this.label,
  });
}

/// 边数据模型
class EdgeData {
  final int from;
  final int to;

  EdgeData({required this.from, required this.to});
}

/// 力导向图绘制器 - 继承自CustomPainter
class ForceDirectedGraphPainter extends CustomPainter {
  final List<NodeData> nodes;
  final List<EdgeData> edges;

  ForceDirectedGraphPainter({
    required this.nodes,
    required this.edges,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // 2. 绘制边(连线)
    final linePaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final fromNode = nodes.firstWhere((n) => n.id == edge.from);
      final toNode = nodes.firstWhere((n) => n.id == edge.to);

      canvas.drawLine(
        Offset(fromNode.x, fromNode.y),
        Offset(toNode.x, toNode.y),
        linePaint,
      );
    }

    // 3. 绘制节点
    for (final node in nodes) {
      // 绘制圆形
      final circlePaint = Paint()
        ..color = node.color
        ..style = PaintingStyle.fill;

      final radius = 40.0;
      canvas.drawCircle(
        Offset(node.x, node.y),
        radius,
        circlePaint,
      );

      // 绘制白色边框
      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(
        Offset(node.x, node.y),
        radius,
        borderPaint,
      );

      // 绘制阴影
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(
        Offset(node.x, node.y),
        radius,
        shadowPaint,
      );

      // 绘制文字标签
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      // 居中绘制文字
      textPainter.paint(
        canvas,
        Offset(node.x - textPainter.width / 2, node.y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(ForceDirectedGraphPainter oldDelegate) {
    // 当数据改变时重新绘制
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges;
  }
}

/// CustomPainter 详细说明文档
///
/// 什么是 CustomPainter?
/// CustomPainter 是 Flutter 中用于自定义绘制的基类。
/// 继承它后,你可以完全控制画布上的绘制内容。
///
/// 核心概念:
/// 1. Canvas (画布): 提供各种绘制方法
///    - drawCircle(): 画圆
///    - drawLine(): 画线
///    -.drawRect(): 画矩形
///    - drawText(): 画文字(通过TextPainter)
///
/// 2. Paint (画笔): 控制绘制的样式
///    - color: 颜色
///    - strokeWidth: 线宽
///    - style: 填充或描边
///    - shader: 渐变
///    - maskFilter: 阴影/模糊
///
/// 3. Size (尺寸): 画布的大小
///
/// 使用步骤:
/// 1. 创建一个类继承 CustomPainter
/// 2. 实现 paint() 方法 - 在这里绘制
/// 3. 实现 shouldRepaint() 方法 - 决定何时重绘
/// 4. 使用 CustomPaint widget 包裹你的painter
///
/// 优点:
/// ✅ 完全的绘制控制权
/// ✅ 性能优秀
/// ✅ 可以绘制任何复杂的图形
/// ✅ 不受现有widget限制
///
/// 缺点:
/// ❌ 需要手动处理所有细节
/// ❌ 交互事件需要自己实现
/// ❌ 需要处理不同屏幕尺寸
/// ❌ 代码量较大
///
/// 适用场景:
/// • 绘制图表、图形
/// • 自定义进度指示器
/// • 游戏画面
/// • 复杂的动画效果
/// • 像素级控制的绘制
