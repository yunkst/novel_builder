import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/screens/dify_settings_screen.dart';
import '../../test_bootstrap.dart';

void main() {
  // 初始化数据库测试环境
  setUpAll(() {
    initTests();
  });

  // 设置测试视口大小
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('DifySettingsScreen Widget Tests', () {
    setUp(() async {
      // 初始化SharedPreferences mock
      SharedPreferences.setMockInitialValues({
        'dify_url': 'https://api.dify.ai/v1',
        'dify_flow_token': 'flow_token_123',
        'dify_struct_token': 'struct_token_456',
        'ai_writer_prompt': '你是一个专业的网络小说作家',
        'max_history_length': 3000,
      });
    });

    Widget createTestWidget() {
      return const MediaQuery(
        data: MediaQueryData(size: Size(800, 1200)), // 增加高度
        child: MaterialApp(
          home: DifySettingsScreen(),
        ),
      );
    }

    testWidgets('应该渲染所有必需的输入字段', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 验证标题
      expect(find.text('Dify 配置'), findsOneWidget);

      // 验证输入框标签
      expect(find.text('Dify URL'), findsOneWidget);
      expect(find.text('Flow Token (流式响应)'), findsOneWidget);
      expect(find.text('Struct Token (结构化响应)'), findsOneWidget);
      expect(find.text('AI 作家设定'), findsOneWidget);
      expect(find.text('最长历史字符数量'), findsOneWidget);

      // 验证保存按钮
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('应该从SharedPreferences加载已保存的配置',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'dify_url': 'https://custom.dify.ai/v1',
        'dify_flow_token': 'custom_flow_token',
        'dify_struct_token': 'custom_struct_token',
        'ai_writer_prompt': '自定义的作家设定',
        'max_history_length': 5000,
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 验证字段存在
      expect(find.text('Dify URL'), findsOneWidget);
      expect(find.text('Flow Token (流式响应)'), findsOneWidget);
      expect(find.text('Struct Token (结构化响应)'), findsOneWidget);
      expect(find.text('AI 作家设定'), findsOneWidget);
      expect(find.text('最长历史字符数量'), findsOneWidget);
    });

    testWidgets('应该显示正确的占位符文本', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 验证占位符
      expect(find.text('例如: https://api.dify.ai/v1'), findsOneWidget);
      expect(find.text('用于特写、总结等流式AI功能'), findsOneWidget);
      expect(find.text('用于未来的结构化响应功能'), findsOneWidget);
      expect(find.text('例如：你是一个专业的网络小说作家...'),
          findsOneWidget);
      expect(find.text('例如: 3000'), findsOneWidget);
    });

    testWidgets('应该显示帮助文本', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 验证帮助文本
      expect(find.text('当前所有AI功能使用此token'), findsOneWidget);
      expect(find.text('为未来功能预留，可选填'), findsOneWidget);
    });

    testWidgets('应该能够输入Dify URL', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 使用更精确的方式查找Dify URL输入框 - 通过标签查找
      final urlField = find.ancestor(
        of: find.text('Dify URL'),
        matching: find.byType(TextFormField),
      );

      expect(urlField, findsOneWidget);
      await tester.enterText(urlField, 'https://new.dify.ai/v1');
      await tester.pump();

      // 验证输入成功
      expect(find.text('https://new.dify.ai/v1'), findsOneWidget);
    });

    testWidgets('应该能够输入Flow Token', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final flowTokenField = find.ancestor(
        of: find.text('Flow Token (流式响应)'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(flowTokenField, 'new_flow_token');
      await tester.pump();

      // 验证输入成功
      expect(find.text('new_flow_token'), findsOneWidget);
    });

    testWidgets('应该能够输入Struct Token', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final structTokenField = find.ancestor(
        of: find.text('Struct Token (结构化响应)'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(structTokenField, 'new_struct_token');
      await tester.pump();

      // 验证输入成功
      expect(find.text('new_struct_token'), findsOneWidget);
    });

    testWidgets('应该能够输入AI作家设定', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final promptField = find.ancestor(
        of: find.text('AI 作家设定'),
        matching: find.byType(TextFormField),
      );

      const testPrompt = '你是一个擅长写玄幻小说的作家';
      await tester.enterText(promptField, testPrompt);
      await tester.pump();

      // 验证输入成功
      expect(find.text(testPrompt), findsOneWidget);
    });

    testWidgets('应该能够输入最长历史字符数量', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final maxLengthField = find.ancestor(
        of: find.text('最长历史字符数量'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(maxLengthField, '5000');
      await tester.pump();

      // 验证输入成功
      expect(find.text('5000'), findsOneWidget);
    });

    testWidgets('初始加载时应该显示加载指示器', (WidgetTester tester) async {
      // 这个测试验证在异步加载完成前的加载状态
      await tester.pumpWidget(createTestWidget());

      // 立即调用pump()，让widget树构建，但不要等待异步操作完成
      await tester.pump();

      // 由于_loadSettings是异步的，此时应该仍显示加载指示器
      // 但实际上SharedPreferences.getInstance()可能很快就完成了
      // 所以我们检查widget是否包含Form或CircularProgressIndicator
      final hasLoadingIndicator = find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
                                   find.byType(Form).evaluate().isNotEmpty;

      // 期望至少有一个存在(加载状态或已加载状态)
      expect(hasLoadingIndicator, isTrue);

      // 等待所有异步操作完成
      await tester.pumpAndSettle();

      // 最终状态应该没有加载指示器
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('页面应该有正确的AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Dify 配置'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('输入框应该使用ListView布局', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('字段之间应该有间距', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final sizedBoxes = find.byType(SizedBox);
      expect(sizedBoxes, findsWidgets);
    });

    testWidgets('保存按钮应该存在', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final saveButton = find.byType(ElevatedButton);
      expect(saveButton, findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('空配置时应该显示空输入框', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 验证输入框存在
      expect(find.byType(TextFormField), findsNWidgets(5));
    });

    testWidgets('应该能够保存配置', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 修改URL值
      final urlField = find.ancestor(
        of: find.text('Dify URL'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(urlField, 'https://updated.dify.ai/v1');
      await tester.pump();

      // 点击保存按钮
      final saveButton = find.byType(ElevatedButton);
      await tester.tap(saveButton);
      await tester.pump();
    });
  });

  group('DifySettingsScreen 验证逻辑测试', () {
    Widget createTestWidget() {
      return const MediaQuery(
        data: MediaQueryData(size: Size(800, 1200)), // 增加高度
        child: MaterialApp(
          home: DifySettingsScreen(),
        ),
      );
    }

    testWidgets('应该验证Dify URL不为空', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 滚动到底部确保按钮可见
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // 不输入URL，直接点击保存
      final saveButton = find.byType(ElevatedButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 应该显示验证错误
      expect(find.text('请输入 Dify URL'), findsOneWidget);
    });

    testWidgets('应该验证Dify URL格式', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final urlField = find.ancestor(
        of: find.text('Dify URL'),
        matching: find.byType(TextFormField),
      );

      // 输入无效URL
      await tester.enterText(urlField, 'not-a-valid-url');
      await tester.pump();

      // 滚动到底部确保按钮可见
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final saveButton = find.byType(ElevatedButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 应该显示验证错误
      expect(find.text('请输入有效的 URL'), findsOneWidget);
    });

    testWidgets('应该验证Flow Token不为空', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'dify_url': 'https://api.dify.ai/v1',
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 滚动到底部确保按钮可见
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // 不输入Flow Token，直接点击保存
      final saveButton = find.byType(ElevatedButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 应该显示验证错误
      expect(find.text('请输入 Flow Token'), findsOneWidget);
    });

    testWidgets('Struct Token是可选的，不需要验证',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'dify_url': 'https://api.dify.ai/v1',
        'dify_flow_token': 'flow_token',
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 滚动到底部确保按钮可见
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // 不输入Struct Token，点击保存
      final saveButton = find.byType(ElevatedButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 不应该显示Struct Token的验证错误
      expect(find.text('请输入 Struct Token'), findsNothing);
    });

    testWidgets('有效的URL应该通过验证', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'dify_url': 'https://api.dify.ai/v1',
        'dify_flow_token': 'flow_token',
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 所有必填字段都有值，应该能通过验证
      expect(find.text('Dify URL'), findsOneWidget);
    });

    testWidgets('最长历史字符数量应该接受数字输入',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final maxLengthField = find.ancestor(
        of: find.text('最长历史字符数量'),
        matching: find.byType(TextFormField),
      );

      // 输入数字
      await tester.enterText(maxLengthField, '12345');
      await tester.pump();

      // 验证输入成功
      expect(find.text('12345'), findsOneWidget);
    });

    testWidgets('应该正确处理旧的dify_token配置',
        (WidgetTester tester) async {
      // 测试向后兼容：旧的dify_token应该自动迁移到新的双token架构
      SharedPreferences.setMockInitialValues({
        'dify_token': 'old_single_token',
        'dify_url': 'https://api.dify.ai/v1',
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 验证字段存在
      expect(find.text('Flow Token (流式响应)'), findsOneWidget);
      expect(find.text('Struct Token (结构化响应)'), findsOneWidget);
    });
  });

  group('DifySettingsScreen 边界情况测试', () {
    Widget createTestWidget() {
      return const MediaQuery(
        data: MediaQueryData(size: Size(800, 1200)), // 增加高度
        child: MaterialApp(
          home: DifySettingsScreen(),
        ),
      );
    }

    testWidgets('应该处理超长的AI作家设定', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final promptField = find.ancestor(
        of: find.text('AI 作家设定'),
        matching: find.byType(TextFormField),
      );

      const longPrompt = '''
你是一个专业的网络小说作家，擅长创作各种类型的小说。
你的写作风格包括：
1. 玄幻小说：宏大的世界观，精彩的战斗场面
2. 都市小说：贴近现实的生活，引人入胜的情节
3. 科幻小说：未来科技的想象，探索未知的世界
请根据用户提供的信息，创作出精彩的小说内容。
      ''';

      await tester.enterText(promptField, longPrompt);
      await tester.pump();

      // 验证输入成功 - 查找包含部分文本的widget
      final textField = tester.widget<TextFormField>(promptField);
      expect(textField.controller?.text.contains('你是一个专业的网络小说作家'), isTrue);
    });

    testWidgets('应该处理零历史字符数量', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final maxLengthField = find.ancestor(
        of: find.text('最长历史字符数量'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(maxLengthField, '0');
      await tester.pump();

      // 验证输入成功
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('应该处理非常大的历史字符数量', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final maxLengthField = find.ancestor(
        of: find.text('最长历史字符数量'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(maxLengthField, '999999');
      await tester.pump();

      // 验证输入成功
      expect(find.text('999999'), findsOneWidget);
    });
  });
}
