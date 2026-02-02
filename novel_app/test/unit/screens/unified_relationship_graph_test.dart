import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/screens/unified_relationship_graph_screen.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import '../../test_bootstrap.dart';

void main() {
  // 初始化数据库测试环境
  setUpAll(() {
    initTests();
  });

  group('UnifiedRelationshipGraphScreen (Riverpod)', () {
    testWidgets('单角色模式应该正确渲染', (WidgetTester tester) async {
      // 创建测试角色
      final character = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '测试角色',
        gender: '男',
      );

      // 构建widget(需要MaterialApp和ProviderScope包装)
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UnifiedRelationshipGraphScreen(
              novelUrl: 'test_novel',
              focusCharacter: character,
            ),
          ),
        ),
      );

      // 等待第一帧渲染
      await tester.pump();

      // 验证标题包含角色名
      expect(find.text('测试角色 - 关系图'), findsOneWidget);
    });

    testWidgets('全局模式应该正确渲染', (WidgetTester tester) async {
      // 构建widget(不传focusCharacter,需要MaterialApp和ProviderScope包装)
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UnifiedRelationshipGraphScreen(
              novelUrl: 'test_novel',
            ),
          ),
        ),
      );

      // 等待第一帧渲染
      await tester.pump();

      // 验证标题
      expect(find.text('全人物关系图'), findsOneWidget);
    });

    test('Character模型应该正确创建', () {
      final character = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '测试角色',
        gender: '男',
        age: 25,
      );

      expect(character.id, 1);
      expect(character.name, '测试角色');
      expect(character.gender, '男');
      expect(character.age, 25);
    });
  });
}
