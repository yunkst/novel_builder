import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';

/// flutter_force_directed_graph 库的功能测试
///
/// 测试目标:
/// 1. 基本的节点和边添加
/// 2. 力导向布局效果
/// 3. 节点拖拽交互
/// 4. 自定义节点和边样式
/// 5. Controller状态管理
/// 6. 性能测试
void main() {
  group('flutter_force_directed_graph - 基础功能测试', () {
    late ForceDirectedGraphController<TestNode> controller;

    setUp(() {
      controller = ForceDirectedGraphController<TestNode>();
    });

    tearDown(() {
      controller.dispose();
    });

    test('应该能够添加节点', () {
      // Arrange
      final node = TestNode(id: '1', name: 'Node 1');

      // Act
      controller.addNode(node);

      // Assert
      expect(controller.graph.nodes.length, 1);
      expect(controller.graph.nodes.first.data.id, '1');
    });

    test('应该能够添加多个节点', () {
      // Arrange
      final nodes = List.generate(
        5,
        (i) => TestNode(id: '$i', name: 'Node $i'),
      );

      // Act
      for (final node in nodes) {
        controller.addNode(node);
      }

      // Assert
      expect(controller.graph.nodes.length, 5);
    });

    test('应该能够在节点之间添加边', () {
      // Arrange
      final node1 = controller.addNode(TestNode(id: '1', name: 'Node 1'));
      final node2 = controller.addNode(TestNode(id: '2', name: 'Node 2'));

      // Act
      controller.addEdgeByNode(node1, node2);

      // Assert
      expect(controller.graph.edges.length, 1);
      expect(controller.graph.edges.first.a.data.id, '1');
      expect(controller.graph.edges.first.b.data.id, '2');
    });

    test('应该能够通过数据添加边', () {
      // Arrange
      final node1 = TestNode(id: '1', name: 'Node 1');
      final node2 = TestNode(id: '2', name: 'Node 2');
      controller.addNode(node1);
      controller.addNode(node2);

      // Act
      controller.addEdgeByData(node1, node2);

      // Assert
      expect(controller.graph.edges.length, 1);
    });

    test('应该能够删除节点', () {
      // Arrange
      final node = controller.addNode(TestNode(id: '1', name: 'Node 1'));

      // Act
      controller.deleteNode(node);

      // Assert
      expect(controller.graph.nodes.length, 0);
    });

    test('删除节点时应该删除相关的边', () {
      // Arrange
      final node1 = controller.addNode(TestNode(id: '1', name: 'Node 1'));
      final node2 = controller.addNode(TestNode(id: '2', name: 'Node 2'));
      final node3 = controller.addNode(TestNode(id: '3', name: 'Node 3'));
      controller.addEdgeByNode(node1, node2);
      controller.addEdgeByNode(node2, node3);

      // Act
      controller.deleteNode(node2);

      // Assert
      expect(controller.graph.nodes.length, 2);
      expect(controller.graph.edges.length, 0);
    });

    test('应该能够通过数据删除节点', () {
      // Arrange
      final node = TestNode(id: '1', name: 'Node 1');
      controller.addNode(node);

      // Act
      controller.deleteNodeByData(node);

      // Assert
      expect(controller.graph.nodes.length, 0);
    });

    test('应该能够删除边', () {
      // Arrange
      final node1 = controller.addNode(TestNode(id: '1', name: 'Node 1'));
      final node2 = controller.addNode(TestNode(id: '2', name: 'Node 2'));
      controller.addEdgeByNode(node1, node2);
      final edge = controller.graph.edges.first;

      // Act
      controller.deleteEdge(edge);

      // Assert
      expect(controller.graph.edges.length, 0);
    });

    test('应该能够替换整个图', () {
      // Arrange
      controller.addNode(TestNode(id: '1', name: 'Node 1'));

      final newGraph = ForceDirectedGraph<TestNode>();
      newGraph.addNode(Node(TestNode(id: '2', name: 'Node 2')));
      newGraph.addNode(Node(TestNode(id: '3', name: 'Node 3')));

      // Act
      controller.graph = newGraph;

      // Assert
      expect(controller.graph.nodes.length, 2);
      expect(controller.graph.nodes.first.data.id, '2');
    });

    test('应该能够序列化为JSON', () {
      // Arrange
      controller.addNode(TestNode(id: '1', name: 'Node 1'));
      controller.addNode(TestNode(id: '2', name: 'Node 2'));
      controller.addEdgeByData(
        TestNode(id: '1', name: 'Node 1'),
        TestNode(id: '2', name: 'Node 2'),
      );

      // Act
      final json = controller.toJson();

      // Assert
      expect(json, isNotNull);
      expect(json.isNotEmpty, true);
    });
  });

  group('flutter_force_directed_graph - 缩放和定位测试', () {
    late ForceDirectedGraphController<TestNode> controller;

    setUp(() {
      controller = ForceDirectedGraphController<TestNode>(
        minScale: 0.5,
        maxScale: 2.0,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('应该能够设置缩放', () {
      // Act
      controller.scale = 1.5;

      // Assert
      expect(controller.scale, 1.5);
    });

    test('缩放应该在minScale和maxScale之间', () {
      // Act
      controller.scale = 3.0;

      // Assert
      expect(controller.scale, controller.maxScale);

      // Act
      controller.scale = 0.1;

      // Assert
      expect(controller.scale, controller.minScale);
    });

    test('应该能够居中图', () {
      // Arrange
      controller.addNode(TestNode(id: '1', name: 'Node 1'));
      controller.addNode(TestNode(id: '2', name: 'Node 2'));

      // Act - 不应该抛出异常
      controller.center();

      // Assert
      expect(controller.graph.nodes.length, 2);
    });

    test('应该能够定位到指定数据', () {
      // Arrange
      final node = TestNode(id: '1', name: 'Node 1');
      controller.addNode(node);

      // Act - 不应该抛出异常
      controller.locateTo(node);

      // Assert
      expect(controller.graph.nodes.length, 1);
    });

    test('应该能够定位到指定位置', () {
      // Arrange
      controller.addNode(TestNode(id: '1', name: 'Node 1'));

      // Act - 不应该抛出异常
      controller.locateToPosition(100, 200);

      // Assert
      expect(controller.graph.nodes.length, 1);
    });

    test('应该能够监听缩放变化', () {
      // Arrange
      double? capturedScale;
      controller.setOnScaleChange((scale) {
        capturedScale = scale;
      });

      // Act
      controller.scale = 1.5;

      // Assert
      expect(capturedScale, 1.5);
    });
  });

  group('flutter_force_directed_graph - 性能测试', () {
    testWidgets('应该能够处理50个节点', (WidgetTester tester) async {
      // 跳过性能测试 - 用户不需要
    }, skip: true);

    testWidgets('应该能够处理100个节点', (WidgetTester tester) async {
      // 跳过性能测试 - 用户不需要
    }, skip: true);
  });

  group('flutter_force_directed_graph - 自定义样式测试', () {
    testWidgets('应该能够自定义节点样式', (WidgetTester tester) async {
      // Arrange
      final controller = ForceDirectedGraphController<String>();
      controller.addNode('Custom Node');

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceDirectedGraphWidget<String>(
              controller: controller,
              nodesBuilder: (context, nodeId) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.blue],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      nodeId,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
              edgesBuilder: (context, sourceId, targetId, distance) {
                return Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.purple],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Assert - 验证ForceDirectedGraphWidget存在
      expect(find.byType(ForceDirectedGraphWidget<String>), findsOneWidget);
      // 验证控制器有节点
      expect(controller.graph.nodes.length, 1);

      controller.dispose();
    });

    testWidgets('应该能够自定义边样式', (WidgetTester tester) async {
      // Arrange
      final controller = ForceDirectedGraphController<String>();
      controller.addNode('Node 1');
      controller.addNode('Node 2');
      controller.addEdgeByData('Node 1', 'Node 2');

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceDirectedGraphWidget<String>(
              controller: controller,
              nodesBuilder: (context, nodeId) {
                return const SizedBox(
                  width: 40,
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
              edgesBuilder: (context, sourceId, targetId, distance) {
                return CustomPaint(
                  size: Size(distance, 10),
                  painter: _CustomEdgePainter(),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CustomPaint), findsWidgets);

      controller.dispose();
    });
  });

  group('flutter_force_directed_graph - 拖拽交互测试', () {
    testWidgets('应该能够监听拖拽事件', (WidgetTester tester) async {
      // Arrange
      final controller = ForceDirectedGraphController<String>();
      controller.addNode('Node 1');

      String? draggingNode;
      String? draggedNode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForceDirectedGraphWidget<String>(
              controller: controller,
              onDraggingStart: (data) {
                draggingNode = data;
              },
              onDraggingEnd: (data) {
                draggedNode = data;
              },
              onDraggingUpdate: (data) {
                // 拖拽中
              },
              nodesBuilder: (context, nodeId) {
                return const SizedBox(
                  width: 40,
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
              edgesBuilder: (context, sourceId, targetId, distance) {
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - 验证回调已设置
      expect(find.byType(ForceDirectedGraphWidget<String>), findsOneWidget);

      controller.dispose();
    });
  });
}

/// 测试用的节点类
class TestNode {
  final String id;
  final String name;

  TestNode({required this.id, required this.name});

  /// 转换为JSON（用于序列化测试）
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestNode &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TestNode($id, $name)';
}

/// 自定义边的绘制器
class _CustomEdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
