import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/character_card_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_update.dart';
import '../../test_bootstrap.dart';

/// CharacterCardService 单元测试
///
/// 测试角色卡片服务的核心功能
void main() {
  // 初始化测试环境
  initTests();

  group('CharacterCardService - 基本功能测试', () {
    late CharacterCardService cardService;

    setUp(() {
      cardService = CharacterCardService();
    });

    test('服务应该成功初始化', () {
      expect(cardService, isNotNull);
    });

    test('updateCharacterCards 空章节内容应该抛出异常', () async {
      final novel = Novel(
        url: 'https://test.com/novel/1',
        title: '测试小说',
        author: '测试作者',
      );

      expect(
        () => cardService.updateCharacterCards(
          novel: novel,
          chapterContent: '',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('CharacterUpdate - 角色对比测试', () {
    test('isNew 新角色应该返回true', () {
      final newChar = MockCharacter(
        novelUrl: 'test',
        name: '新角色',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: null,
      );

      expect(update.isNew, isTrue);
      expect(update.isUpdate, isFalse);
    });

    test('isUpdate 更新角色应该返回true', () {
      final oldChar = MockCharacter(
        id: 1,
        novelUrl: 'test',
        name: '角色',
        age: 20,
      );

      final newChar = MockCharacter(
        id: 1,
        novelUrl: 'test',
        name: '角色',
        age: 25,
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      expect(update.isNew, isFalse);
      expect(update.isUpdate, isTrue);
    });

    test('getDifferences 应该检测年龄变化', () {
      final oldChar = MockCharacter(
        id: 1,
        novelUrl: 'test',
        name: '角色',
        age: 20,
      );

      final newChar = MockCharacter(
        id: 1,
        novelUrl: 'test',
        name: '角色',
        age: 25,
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();

      expect(diffs.length, greaterThan(0));
      expect(diffs.any((d) => d.label == '年龄'), isTrue);
    });

    test('getDifferences 无变化应该返回空列表', () {
      final char = MockCharacter(
        id: 1,
        novelUrl: 'test',
        name: '角色',
        age: 25,
      );

      final update = CharacterUpdate(
        newCharacter: char,
        oldCharacter: char,
      );

      final diffs = update.getDifferences();

      expect(diffs, isEmpty);
    });

    test('getDifferences 多字段变化应该返回多个差异', () {
      final oldChar = MockCharacter(
        id: 1,
        novelUrl: 'test',
        name: '角色',
        age: 20,
        gender: '男',
      );

      final newChar = MockCharacter(
        id: 1,
        novelUrl: 'test',
        name: '角色',
        age: 30,
        gender: '女',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();

      expect(diffs.length, greaterThan(0));
    });
  });

  group('FieldDiff - 字段差异测试', () {
    test('hasChanged 新旧值不同应该返回true', () {
      const diff = FieldDiff(
        label: '年龄',
        oldValue: '20岁',
        newValue: '25岁',
      );

      expect(diff.hasChanged, isTrue);
    });

    test('hasChanged 新旧值相同应该返回false', () {
      const diff = FieldDiff(
        label: '年龄',
        oldValue: '25岁',
        newValue: '25岁',
      );

      expect(diff.hasChanged, isFalse);
    });

    test('isNewField 旧值为空应该返回true', () {
      const diff = FieldDiff(
        label: '职业',
        oldValue: null,
        newValue: '医生',
      );

      expect(diff.isNewField, isTrue);
    });

    test('isDeletedField 新值为空应该返回true', () {
      const diff = FieldDiff(
        label: '职业',
        oldValue: '医生',
        newValue: null,
      );

      expect(diff.isDeletedField, isTrue);
    });
  });

  group('CharacterCardService - Character工具方法测试', () {
    test('formatForAI 空列表应该返回默认文本', () {
      final formatted = Character.formatForAI([]);

      expect(formatted, equals('无特定角色出场'));
    });

    test('formatForAI 应该格式化角色信息', () {
      final characters = [
        MockCharacter(
          novelUrl: 'test',
          name: '张三',
          gender: '男',
          age: 25,
          occupation: '医生',
          personality: '开朗',
          appearanceFeatures: '英俊',
        ),
      ];

      final formatted = Character.formatForAI(characters);

      expect(formatted, contains('张三'));
      expect(formatted, contains('男'));
      expect(formatted, contains('25'));
      expect(formatted, contains('医生'));
    });

    test('toJsonArray 空列表应该返回空数组', () {
      final json = Character.toJsonArray([]);

      expect(json, equals('[]'));
    });

    test('toJsonArray 应该正确序列化', () {
      final characters = [
        MockCharacter(
          novelUrl: 'test',
          name: '张三',
          gender: '男',
          age: 25,
        ),
      ];

      final json = Character.toJsonArray(characters);

      expect(json, contains('张三'));
      expect(json, contains('男'));
      expect(json, contains('25'));
    });

    test('toRoleInfoList 空列表应该返回空列表', () {
      final roleInfoList = Character.toRoleInfoList([]);

      expect(roleInfoList, isEmpty);
    });
  });
}

// Mock类用于测试
class MockCharacter extends Character {
  MockCharacter({
    int? id,
    required String novelUrl,
    required String name,
    int? age,
    String? gender,
    String? occupation,
    String? personality,
    String? appearanceFeatures,
  }) : super(
          id: id,
          novelUrl: novelUrl,
          name: name,
          age: age,
          gender: gender,
          occupation: occupation,
          personality: personality,
          appearanceFeatures: appearanceFeatures,
        );
}
