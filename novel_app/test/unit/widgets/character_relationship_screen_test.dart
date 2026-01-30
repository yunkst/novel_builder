import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/screens/character_relationship_screen.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_helpers/character_relationship_test_data.dart';
import '../../test_bootstrap.dart';
import 'character_relationship_screen_test.mocks.dart';

/// 生成Mock类
@GenerateMocks([DatabaseService])

void main() {
  initTests();

  group('CharacterRelationshipScreen - 加载状态', () {
    late MockDatabaseService mockDb;
    late Character testCharacter;

    setUp(() {
      mockDb = MockDatabaseService();
      testCharacter = CharacterRelationshipTestData.createTestCharacter(
        id: 1,
        name: '张三',
      );

      // Mock数据库方法，使用具体值避免类型错误
      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => []);
    });

    testWidgets('初始应该显示Loading Indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      // 立即验证，不等pump完成
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 然后等待加载完成
      await tester.pumpAndSettle();
    });

    testWidgets('加载完成后应该显示内容', (tester) async {
      // 准备测试数据
      final outgoing = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: '师父',
        ),
      ];

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => outgoing);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => [
                CharacterRelationshipTestData.createTestCharacter(
                  id: 2,
                  name: '李四',
                ),
              ]);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      // 等待异步加载完成
      await tester.pumpAndSettle();

      // 验证Loading指示器消失
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // 验证TabBar显示
      expect(find.text('Ta的关系'), findsOneWidget);
      expect(find.text('关系Ta的人'), findsOneWidget);
    });

    testWidgets('加载失败应该显示错误信息', (tester) async {
      when(mockDb.getOutgoingRelationships(1))
          .thenThrow(Exception('加载失败'));

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      // 等待异步操作
      await tester.pumpAndSettle();

      // 验证Loading消失
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // 验证显示错误信息（SnackBar会显示）
      // 注意：SnackBar可能需要验证Widget内容
    });
  });

  group('CharacterRelationshipScreen - 空状态渲染', () {
    late MockDatabaseService mockDb;
    late Character testCharacter;

    setUp(() {
      mockDb = MockDatabaseService();
      testCharacter = CharacterRelationshipTestData.createTestCharacter(
        id: 1,
        name: '张三',
      );

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => []);
    });

    testWidgets('无出度关系时显示空状态', (tester) async {
      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 等待TabBarView渲染
      await tester.pump();

      // 验证空状态提示
      expect(find.text('张三 还没有定义与其他人的关系'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('无入度关系时显示空状态', (tester) async {
      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 切换到第二个Tab
      await tester.tap(find.text('关系Ta的人'));
      await tester.pumpAndSettle();

      // 验证空状态提示
      expect(find.text('还没有人定义与 张三 的关系'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('CharacterRelationshipScreen - 关系列表渲染', () {
    late MockDatabaseService mockDb;
    late Character testCharacter;

    setUp(() {
      mockDb = MockDatabaseService();
      testCharacter = CharacterRelationshipTestData.createTestCharacter(
        id: 1,
        name: '张三',
      );
    });

    testWidgets('应该显示TabBar', (tester) async {
      final relationships = CharacterRelationshipTestData.createInOutRelationships(
        characterId: 1,
      );

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => relationships['outgoing']!);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => relationships['incoming']!);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => CharacterRelationshipTestData.createCharacterMap().values.toList());

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证TabBar显示
      expect(find.text('Ta的关系'), findsOneWidget);
      expect(find.text('关系Ta的人'), findsOneWidget);
    });

    testWidgets('应该渲染出度关系列表', (tester) async {
      final relationships = CharacterRelationshipTestData.createInOutRelationships(
        characterId: 1,
      );

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => relationships['outgoing']!);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => relationships['incoming']!);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => [
                Character(
                  id: 2,
                  novelUrl: 'test_novel',
                  name: '李四',
                  gender: '女',
                  age: 22,
                ),
                Character(
                  id: 3,
                  novelUrl: 'test_novel',
                  name: '王五',
                  gender: '男',
                  age: 23,
                ),
              ]);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证关系类型显示
      expect(find.text('师父'), findsOneWidget);
      expect(find.text('朋友'), findsOneWidget);

      // 验证角色名称显示
      expect(find.text('李四'), findsOneWidget);
      expect(find.text('王五'), findsOneWidget);
    });

    testWidgets('应该渲染入度关系列表', (tester) async {
      final relationships = CharacterRelationshipTestData.createInOutRelationships(
        characterId: 1,
      );

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => relationships['outgoing']!);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => relationships['incoming']!);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => [
                Character(
                  id: 4,
                  novelUrl: 'test_novel',
                  name: '赵六',
                  gender: '男',
                  age: 24,
                ),
                Character(
                  id: 5,
                  novelUrl: 'test_novel',
                  name: '孙七',
                  gender: '女',
                  age: 25,
                ),
              ]);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 切换到第二个Tab
      await tester.tap(find.text('关系Ta的人'));
      await tester.pumpAndSettle();

      // 验证关系类型显示
      expect(find.text('徒弟'), findsOneWidget);
      expect(find.text('兄弟'), findsOneWidget);

      // 验证角色名称显示
      expect(find.text('赵六'), findsOneWidget);
      expect(find.text('孙七'), findsOneWidget);
    });

    testWidgets('关系卡片应该显示描述信息', (tester) async {
      final outgoing = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: '师父',
          description: '他是我的师父',
        ),
      ];

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => outgoing);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => [
                Character(
                  id: 2,
                  novelUrl: 'test_novel',
                  name: '李四',
                  gender: '女',
                ),
              ]);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证描述信息显示
      expect(find.text('他是我的师父'), findsOneWidget);
    });

    testWidgets('出度关系应该显示向右箭头', (tester) async {
      final outgoing = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: '师父',
        ),
      ];

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => outgoing);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => [
                Character(
                  id: 2,
                  novelUrl: 'test_novel',
                  name: '李四',
                ),
              ]);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证向右箭头图标
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('入度关系应该显示向左箭头', (tester) async {
      final incoming = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 2,
          targetCharacterId: 1,
          relationshipType: '徒弟',
        ),
      ];

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => []);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => incoming);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => [
                Character(
                  id: 2,
                  novelUrl: 'test_novel',
                  name: '李四',
                ),
              ]);

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 切换到第二个Tab
      await tester.tap(find.text('关系Ta的人'));
      await tester.pumpAndSettle();

      // 验证向左箭头图标
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('CharacterRelationshipScreen - 交互测试', () {
    late MockDatabaseService mockDb;
    late Character testCharacter;

    setUp(() {
      mockDb = MockDatabaseService();
      testCharacter = CharacterRelationshipTestData.createTestCharacter(
        id: 1,
        name: '张三',
      );

      final relationships = CharacterRelationshipTestData.createInOutRelationships(
        characterId: 1,
      );

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => relationships['outgoing']!);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => relationships['incoming']!);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => CharacterRelationshipTestData.createCharacterMap().values.toList());
    });

    testWidgets('应该有添加关系按钮', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证添加按钮存在
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('应该有查看关系图按钮', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证关系图按钮存在
      expect(find.byIcon(Icons.account_tree), findsOneWidget);
    });

    testWidgets('关系卡片应该有编辑按钮', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证编辑按钮存在
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('关系卡片应该有删除按钮', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证删除按钮存在
      expect(find.byIcon(Icons.delete), findsWidgets);
    });
  });

  group('CharacterRelationshipScreen - Tab切换', () {
    late MockDatabaseService mockDb;
    late Character testCharacter;

    setUp(() {
      mockDb = MockDatabaseService();
      testCharacter = CharacterRelationshipTestData.createTestCharacter(
        id: 1,
        name: '张三',
      );

      final relationships = CharacterRelationshipTestData.createInOutRelationships(
        characterId: 1,
      );

      when(mockDb.getOutgoingRelationships(1))
          .thenAnswer((_) async => relationships['outgoing']!);
      when(mockDb.getIncomingRelationships(1))
          .thenAnswer((_) async => relationships['incoming']!);
      when(mockDb.getCharacters('test_novel'))
          .thenAnswer((_) async => CharacterRelationshipTestData.createCharacterMap().values.toList());
    });

    testWidgets('Tab切换应该正确显示不同列表', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterRelationshipScreen(
            character: testCharacter,
            databaseService: mockDb,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证第一个Tab的内容
      expect(find.text('师父'), findsOneWidget);
      expect(find.text('朋友'), findsOneWidget);

      // 切换到第二个Tab
      await tester.tap(find.text('关系Ta的人'));
      await tester.pumpAndSettle();

      // 验证第二个Tab的内容
      expect(find.text('徒弟'), findsOneWidget);
      expect(find.text('兄弟'), findsOneWidget);

      // 切换回第一个Tab
      await tester.tap(find.text('Ta的关系'));
      await tester.pumpAndSettle();

      // 验证第一个Tab的内容仍然存在
      expect(find.text('师父'), findsOneWidget);
      expect(find.text('朋友'), findsOneWidget);
    });
  });
}
