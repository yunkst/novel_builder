import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/screens/character_relationship_screen.dart';
import 'package:novel_app/services/database_service.dart';

@GenerateMocks([DatabaseService])
import 'test_timeout_debug.mocks.dart';

void main() {
  testWidgets('Debug timeout issue', (tester) async {
    final mockDb = MockDatabaseService();
    final testCharacter = Character(
      id: 1,
      novelUrl: 'test_novel',
      name: '测试',
    );

    // 设置mock
    when(mockDb.getOutgoingRelationships(1))
        .thenAnswer((_) async => []);
    when(mockDb.getIncomingRelationships(1))
        .thenAnswer((_) async => []);
    when(mockDb.getCharacters('test_novel'))
        .thenAnswer((_) async => []);

    debugPrint('开始pumpWidget...');
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterRelationshipScreen(
          character: testCharacter,
          databaseService: mockDb,
        ),
      ),
    );
    debugPrint('pumpWidget完成');

    debugPrint('开始pump...');
    await tester.pump();
    debugPrint('pump完成');

    debugPrint('开始pumpAndSettle...');
    await tester.pumpAndSettle();
    debugPrint('pumpAndSettle完成');

    expect(find.byType(CharacterRelationshipScreen), findsOneWidget);
  });
}
