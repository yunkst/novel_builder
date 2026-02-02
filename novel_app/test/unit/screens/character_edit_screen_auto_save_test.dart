import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/screens/character_edit_screen.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/services/dify_service.dart';
import 'package:novel_app/services/character_avatar_service.dart';
import 'package:novel_app/core/providers/character_screen_providers.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/core/providers/service_providers.dart';
import '../../test_bootstrap.dart';
import '../../base/database_test_base.dart';

// 生成 Nice Mock 类（不需要手动 stub 每个方法）
@GenerateNiceMocks([
  MockSpec<ApiServiceWrapper>(),
  MockSpec<DifyService>(),
  MockSpec<CharacterAvatarService>(),
])
import 'character_edit_screen_auto_save_test.mocks.dart';

/// CharacterEditScreen 自动保存功能单元测试
///
/// **重要修复说明** (2025-02-01):
/// - 使用 DatabaseTestBase 创建独立的数据库实例
/// - 避免多个测试共享同一个数据库导致锁定冲突
/// - 每个测试完成后正确清理数据库连接
///
/// 测试目标:
/// 1. 验证生成提示词后自动保存功能正常工作
/// 2. 验证新建模式下自动创建角色
/// 3. 验证编辑模式下自动更新角色
/// 4. 验证防重复保存机制
/// 5. 验证延迟保存机制
/// 6. 验证错误处理和提示
///
/// 注意:
/// - 测试使用 Riverpod ProviderScope
/// - CharacterEditScreen 使用 ConsumerStatefulWidget
/// - 主要测试UI元素的存在和基本交互
/// - 完整的自动保存逻辑需要集成测试支持
void main() {
  // 初始化测试环境
  initDatabaseTests();

  group('CharacterEditScreen - 提示词生成后自动保存功能', () {
    late DatabaseTestBase testBase;
    late Character testCharacter;
    late Novel testNovel;
    late MockApiServiceWrapper mockApiService;
    late MockDifyService mockDifyService;
    late MockCharacterAvatarService mockAvatarService;

    setUpAll(() async {
      // 创建 Mock 实例
      mockApiService = MockApiServiceWrapper();
      mockDifyService = MockDifyService();
      mockAvatarService = MockCharacterAvatarService();
    });

    setUp(() async {
      // 每个测试使用独立的数据库实例（关键修复！）
      testBase = DatabaseTestBase();
      await testBase.setUp();

      // 准备测试用小说
      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/test-novel',
      );

      // 准备测试用角色
      testCharacter = Character(
        id: 1,
        novelUrl: 'https://example.com/test-novel',
        name: '张三',
        age: 25,
        gender: '男',
        occupation: '程序员',
        personality: '开朗',
        bodyType: '标准',
        clothingStyle: '休闲',
        appearanceFeatures: '特征明显',
        backgroundStory: '背景故事',
        aliases: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        facePrompts: 'face prompt',
        bodyPrompts: 'body prompt',
        cachedImageUrl: null,
      );
    });

    tearDown(() async {
      // 清理测试数据库（关键修复！）
      await testBase.tearDown();
    });

    /// 创建测试用的 ProviderScope
    ProviderScope createTestScope({required Widget child}) {
      return ProviderScope(
        overrides: [
          // 使用测试数据库服务
          databaseServiceProvider.overrideWithValue(testBase.databaseService),
          // Mock API 服务
          apiServiceWrapperProvider.overrideWithValue(mockApiService),
          // Mock Dify 服务
          difyServiceProvider.overrideWithValue(mockDifyService),
          // Mock 头像服务
          characterAvatarServiceProvider.overrideWithValue(mockAvatarService),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('测试1: 新建模式下UI应包含生成提示词按钮',
        (WidgetTester tester) async {
      // 构建测试界面（新建模式）- 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            novel: testNovel,
          ),
        ),
      );

      // 等待初始渲染（不使用pumpAndSettle避免超时）
      await tester.pump();

      // 验证存在生成提示词按钮
      expect(find.text('生成提示词'), findsOneWidget,
          reason: '应该显示生成提示词按钮');
    });

    testWidgets('测试2: 编辑模式下UI应包含生成提示词按钮',
        (WidgetTester tester) async {
      // 构建测试界面（编辑模式）- 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 验证存在生成提示词按钮
      expect(find.text('生成提示词'), findsOneWidget,
          reason: '编辑模式下应该显示生成提示词按钮');
    });

    testWidgets('测试3: 编辑模式下提示词字段应显示现有值',
        (WidgetTester tester) async {
      // 构建测试界面（编辑模式）- 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 验证显示现有提示词
      expect(find.text('face prompt'), findsOneWidget,
          reason: '应该显示现有的人物提示词');
      expect(find.text('body prompt'), findsOneWidget,
          reason: '应该显示现有的人物提示词');
    });

    testWidgets('测试4: 新建模式下必填字段验证',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 验证姓名字段存在 - 使用更通用的查找方式
      expect(find.byType(TextField), findsWidgets,
          reason: '应该存在输入框');

      // 验证生成提示词按钮初始存在
      final generateButton = find.text('生成提示词');
      expect(generateButton, findsOneWidget);
    });

    testWidgets('测试5: 验证表单字段完整性',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 验证存在多个输入框字段（简化验证）
      expect(find.byType(TextField), findsWidgets,
          reason: '应该存在多个输入框');
    });

    testWidgets('测试6: 验证保存按钮存在',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 验证保存按钮存在
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('测试7: 新建模式下的AppBar标题',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 验证标题
      expect(find.text('创建人物'), findsOneWidget);
    });

    testWidgets('测试8: 编辑模式下的AppBar标题',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 验证标题
      expect(find.text('编辑人物'), findsOneWidget);
    });

    testWidgets('测试9: 验证头像显示区域存在',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 查找头像相关的容器
      // 注意: ClipOval只在有实际头像文件时渲染,测试环境中可能没有文件
      // 因此验证Container(备用头像也会使用Container)
      final containers = find.byType(Container);
      expect(containers, findsWidgets,
          reason: '应该存在头像区域的Container');

      // 验证至少有一个圆形的Container(备用头像或实际头像)
      final circularContainers = tester.widgetList<Container>(containers).where((container) {
        final decoration = container.decoration as BoxDecoration?;
        return decoration?.shape == BoxShape.circle;
      });

      expect(circularContainers.isNotEmpty, true,
          reason: '应该存在圆形的头像区域(实际头像或备用头像)');
    });

    testWidgets('测试10: 验证提示词输入框是可编辑的',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 找到提示词输入框
      final promptFields = find.byType(TextField);
      expect(promptFields, findsWidgets);

      // 尝试在第一个提示词框中输入文字
      await tester.enterText(promptFields.first, 'new prompt text');
      await tester.pump();

      // 验证文字已输入（使用更精确的匹配）
      expect(find.text('new prompt text', skipOffstage: false), findsWidgets);
    });

    testWidgets('测试11: 验证生成提示词按钮存在',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 查找所有"生成提示词"按钮
      final buttons = find.text('生成提示词');
      expect(buttons, findsWidgets);

      // 验证至少有一个
      expect(buttons, findsAtLeastNWidgets(1));
    });

    testWidgets('测试12: 验证姓名字段可正常输入',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 查找姓名输入框 - 简化查找方式
      final nameField = find.byType(TextField).first;
      expect(nameField, findsOneWidget);

      // 输入姓名
      await tester.enterText(nameField, '李四');
      await tester.pump();

      // 验证输入成功
      expect(find.text('李四', skipOffstage: false), findsWidgets);
    });

    testWidgets('测试13: 验证性别选择框存在',
        (WidgetTester tester) async {
      // 构建测试界面 - 使用统一的 ProviderScope
      await tester.pumpWidget(
        createTestScope(
          child: CharacterEditScreen(
            character: testCharacter,
            novel: testNovel,
          ),
        ),
      );

      await tester.pump();

      // 查找性别选择框（DropdownButtonFormField）
      expect(find.widgetWithText(DropdownButtonFormField<String>, '性别'),
          findsOneWidget,
          reason: '应该存在性别选择下拉框');
    });
  });
}
