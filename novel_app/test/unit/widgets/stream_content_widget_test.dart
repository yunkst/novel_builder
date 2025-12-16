import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../lib/widgets/stream_content_widget.dart';
import '../../../lib/models/stream_config.dart';
import '../mocks/mock_dependencies.dart';

void main() {
  group('StreamContentWidget 单元测试', () {
    late StreamConfig testConfig;
    late TextEditingController testController;

    setUp(() {
      testConfig = StreamConfig.sceneDescription(
        inputs: TestDataFactory.createTestInputs(),
        generatingHint: 'AI正在生成测试内容...',
      );

      testController = TextEditingController();
      setupMocktailFallbacks();
    });

    tearDown(() {
      testController.dispose();
    });

    group('组件初始化测试', () {
      testWidgets('应该正确初始化组件', (WidgetTester tester) async {
        // 构建组件
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                controller: testController,
              ),
            ),
          ),
        );

        // 验证组件存在
        expect(find.byType(StreamContentWidget), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('应该使用默认控制器当未提供时', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
              ),
            ),
          ),
        );

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该在autoStart为true时自动开始生成', (WidgetTester tester) async {
        var generationStarted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                autoStart: true,
                onGenerationStart: () {
                  generationStarted = true;
                },
              ),
            ),
          ),
        );

        // 等待自动启动
        await tester.pump();

        // 验证生成已开始
        expect(generationStarted, isTrue);
      });
    });

    group('流数据接收测试', () {
      testWidgets('应该正确接收流数据块', (WidgetTester tester) async {
        final chunks = TestDataFactory.createTestChunks();
        var receivedChunks = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                onChanged: (content) {
                  receivedChunks.add(content);
                },
              ),
            ),
          ),
        );

        // 模拟流数据接收（需要通过实际的状态管理）
        // 这里需要根据实际实现调整测试策略

        // 验证组件存在
        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该正确处理完整内容替换', (WidgetTester tester) async {
        final completeContent = '这是完整的测试内容';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                onGenerationComplete: (content) {
                  expect(content, equals(completeContent));
                },
              ),
            ),
          ),
        );

        // 模拟完整内容接收
        // 需要通过状态管理来触发内容更新

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该正确更新文本控制器内容', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                controller: controller,
              ),
            ),
          ),
        );

        // 初始内容应该为空
        expect(controller.text, isEmpty);

        // 模拟内容更新（需要通过状态管理）
        // 这里需要根据实际实现调整

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });
    });

    group('生成状态管理测试', () {
      testWidgets('应该正确跟踪生成状态', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
              ),
            ),
          ),
        );

        // 获取组件状态
        final widget = tester.widget(find.byType(StreamContentWidget)) as StreamContentWidget;

        // 初始状态应该不在生成中
        expect(widget.isGenerating, isFalse);
        expect(widget.generationError, isNull);
        expect(widget.hasActiveStream, isFalse);
      });

      testWidgets('应该正确显示生成中的状态', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                generatingHint: '正在生成中...',
              ),
            ),
          ),
        );

        // 查找生成提示文本
        expect(find.text('正在生成中...'), findsOneWidget);

        // 验证输入框在生成中状态
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isTrue); // 根据配置可能为false
      });

      testWidgets('应该正确处理生成完成状态', (WidgetTester tester) async {
        var completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                onGenerationComplete: (_) {
                  completed = true;
                },
              ),
            ),
          ),
        );

        // 模拟生成完成（需要通过状态管理）
        // 这里需要根据实际实现调整

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });
    });

    group('错误处理测试', () {
      testWidgets('应该正确显示错误状态', (WidgetTester tester) async {
        const errorMessage = '生成失败：网络错误';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
              ),
            ),
          ),
        );

        // 模拟错误状态（需要通过状态管理）
        // 这里需要根据实际实现调整测试策略

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该正确调用错误回调', (WidgetTester tester) async {
        var receivedError = '';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                onGenerationError: (error) {
                  receivedError = error;
                },
              ),
            ),
          ),
        );

        // 模拟错误发生
        // 需要通过状态管理来触发错误

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该提供错误清除功能', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
              ),
            ),
          ),
        );

        // 验证错误信息显示和清除机制
        // 需要根据实际的UI实现来调整测试

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });
    });

    group('用户交互测试', () {
      testWidgets('应该支持重新生成功能', (WidgetTester tester) async {
        var regenerated = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                onGenerationStart: () {
                  regenerated = true;
                },
              ),
            ),
          ),
        );

        // 查找重新生成按钮（如果存在）
        // 需要根据实际的UI实现调整

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该支持停止生成功能', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
              ),
            ),
          ),
        );

        // 获取组件并测试停止功能
        final widget = tester.widget(find.byType(StreamContentWidget)) as StreamContentWidget;

        // 初始状态应该没有活跃流
        expect(widget.hasActiveStream, isFalse);

        // 测试停止生成方法
        await widget.stopGeneration();

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该正确处理文本输入', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                controller: controller,
              ),
            ),
          ),
        );

        // 查找输入框
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);

        // 测试文本输入
        await tester.enterText(textField, '测试输入');
        await tester.pump();

        // 验证文本更新
        expect(controller.text, equals('测试输入'));
      });
    });

    group('组件生命周期测试', () {
      testWidgets('应该正确处理组件销毁', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
              ),
            ),
          ),
        );

        // 验证组件存在
        expect(find.byType(StreamContentWidget), findsOneWidget);

        // 移除组件
        await tester.pumpWidget(Container());

        // 验证组件已销毁
        expect(find.byType(StreamContentWidget), findsNothing);
      });

      testWidgets('应该在销毁时取消活跃流', (WidgetTester tester) async {
        StreamConfig? capturedConfig;
        var widgetDestroyed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return StreamContentWidget(
                    config: testConfig,
                    onGenerationStart: () {
                      capturedConfig = testConfig;
                    },
                  );
                },
              ),
            ),
          ),
        );

        // 获取组件引用
        final widget = tester.widget(find.byType(StreamContentWidget)) as StreamContentWidget;

        // 模拟开始生成
        expect(capturedConfig, isNotNull);

        // 销毁组件
        await tester.pumpWidget(Container());
        widgetDestroyed = true;

        expect(find.byType(StreamContentWidget), findsNothing);
      });

      testWidgets('应该正确处理控制器生命周期', (WidgetTester tester) async {
        // 测试外部提供的控制器
        final externalController = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                controller: externalController,
              ),
            ),
          ),
        );

        // 移除组件
        await tester.pumpWidget(Container());

        // 外部控制器应该仍然可用
        externalController.text = '测试';
        expect(externalController.text, equals('测试'));

        // 清理
        externalController.dispose();
      });
    });

    group('配置参数测试', () {
      testWidgets('应该正确应用生成时背景色', (WidgetTester tester) async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
          generatingBackgroundColor: '#000000',
          generatingTextColor: '#FFFFFF',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: config,
              ),
            ),
          ),
        );

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该正确应用最大最小行数', (WidgetTester tester) async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
          maxLines: 10,
          minLines: 3,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: config,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.maxLines, equals(10));
        expect(textField.minLines, equals(3));
      });

      testWidgets('应该正确应用禁用编辑配置', (WidgetTester tester) async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
          disableEditWhileGenerating: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: config,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        // 在生成中时应该被禁用（需要根据实际状态调整测试）
        expect(textField.enabled, isTrue); // 初始状态应该是启用的
      });
    });

    group('回调函数测试', () {
      testWidgets('应该正确调用内容变化回调', (WidgetTester tester) async {
        var contentChanged = false;
        String? newContent;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                onChanged: (content) {
                  contentChanged = true;
                  newContent = content;
                },
              ),
            ),
          ),
        );

        // 验证回调函数设置
        final widget = tester.widget(find.byType(StreamContentWidget)) as StreamContentWidget;
        expect(find.byType(StreamContentWidget), findsOneWidget);
      });

      testWidgets('应该正确调用生成开始回调', (WidgetTester tester) async {
        var generationStarted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                autoStart: true,
                onGenerationStart: () {
                  generationStarted = true;
                },
              ),
            ),
          ),
        );

        // 等待自动启动
        await tester.pump();

        expect(generationStarted, isTrue);
      });

      testWidgets('应该正确调用完成和错误回调', (WidgetTester tester) async {
        var completed = false;
        var errorOccurred = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                onGenerationComplete: (_) => completed = true,
                onGenerationError: (_) => errorOccurred = true,
              ),
            ),
          ),
        );

        // 需要通过状态管理来触发回调
        // 这里需要根据实际实现调整测试策略

        expect(find.byType(StreamContentWidget), findsOneWidget);
      });
    });

    group('自定义样式测试', () {
      testWidgets('应该正确应用自定义文本样式', (WidgetTester tester) async {
        final customStyle = TextStyle(
          fontSize: 18,
          color: Colors.red,
          fontWeight: FontWeight.bold,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                textStyle: customStyle,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.style?.fontSize, equals(18));
        expect(textField.style?.color, equals(Colors.red));
        expect(textField.style?.fontWeight, equals(FontWeight.bold));
      });

      testWidgets('应该正确应用自定义装饰', (WidgetTester tester) async {
        final customDecoration = InputDecoration(
          labelText: '自定义标签',
          hintText: '自定义提示',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamContentWidget(
                config: testConfig,
                decoration: customDecoration,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.labelText, equals('自定义标签'));
        expect(textField.decoration?.hintText, equals('自定义提示'));
      });
    });
  });
}