import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_update.dart';

void main() {
  group('CharacterUpdate', () {
    test('应该正确识别新增角色', () {
      final newChar = Character(
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
      );

      final update = CharacterUpdate(newCharacter: newChar);

      expect(update.isNew, true);
      expect(update.isUpdate, false);
      expect(update.getDifferences(), isEmpty);
    });

    test('应该正确识别更新角色', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 22,
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      expect(update.isNew, false);
      expect(update.isUpdate, true);
    });

    test('应该正确检测年龄字段变化', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 22,
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(1));
      expect(diffs[0].label, '年龄');
      expect(diffs[0].oldValue, '20岁');
      expect(diffs[0].newValue, '22岁');
    });

    test('应该正确检测多个字段变化', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        gender: '男',
        personality: '开朗',
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 22,
        gender: '女',
        personality: '沉稳',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(3));

      final diffLabels = diffs.map((d) => d.label).toSet();
      expect(diffLabels, containsAll(['年龄', '性别', '性格']));
    });

    test('应该正确处理null值变化(新增字段)', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        occupation: null,
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        occupation: '医生',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(1));
      expect(diffs[0].isNewField, true);
      expect(diffs[0].oldValue, null);
      expect(diffs[0].newValue, '医生');
    });

    test('应该正确处理字段删除(新值为null)', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        occupation: '医生',
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        occupation: null,
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(1));
      expect(diffs[0].isDeletedField, true);
      expect(diffs[0].oldValue, '医生');
      expect(diffs[0].newValue, null);
    });

    test('无变化时应返回空差异列表', () {
      final char = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
      );

      final update = CharacterUpdate(
        newCharacter: char,
        oldCharacter: char,
      );

      final diffs = update.getDifferences();
      expect(diffs, isEmpty);
    });

    test('应该正确对比所有字段类型', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 18,
        gender: '男',
        occupation: '学生',
        personality: '内向',
        bodyType: '瘦弱',
        clothingStyle: '朴素',
        appearanceFeatures: '黑发黑眼',
        backgroundStory: '孤儿',
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        gender: '女',
        occupation: '医生',
        personality: '开朗',
        bodyType: '健壮',
        clothingStyle: '华丽',
        appearanceFeatures: '金发蓝眼',
        backgroundStory: '贵族',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(8));

      final diffLabels = diffs.map((d) => d.label).toSet();
      expect(diffLabels, containsAll(['年龄', '性别', '职业', '性格', '体型', '着装', '外貌', '背景']));
    });
  });

  group('FieldDiff', () {
    test('hasChanged应该在值不同时返回true', () {
      const diff = FieldDiff(
        label: '年龄',
        oldValue: '20岁',
        newValue: '22岁',
      );

      expect(diff.hasChanged, true);
    });

    test('hasChanged应该在值相同时返回false', () {
      const diff = FieldDiff(
        label: '年龄',
        oldValue: '20岁',
        newValue: '20岁',
      );

      expect(diff.hasChanged, false);
    });

    test('isNewField应该在旧值为null时返回true', () {
      const diff = FieldDiff(
        label: '职业',
        oldValue: null,
        newValue: '医生',
      );

      expect(diff.isNewField, true);
      expect(diff.isDeletedField, false);
    });

    test('isDeletedField应该在新值为null时返回true', () {
      const diff = FieldDiff(
        label: '职业',
        oldValue: '医生',
        newValue: null,
      );

      expect(diff.isDeletedField, true);
      expect(diff.isNewField, false);
    });

    test('应该正确处理两端都为null的情况', () {
      const diff = FieldDiff(
        label: '职业',
        oldValue: null,
        newValue: null,
      );

      expect(diff.hasChanged, false);
      expect(diff.isNewField, false);
      expect(diff.isDeletedField, false);
    });

    test('应该正确处理只有一端为null的情况', () {
      const diff1 = FieldDiff(
        label: '职业',
        oldValue: '医生',
        newValue: null,
      );
      expect(diff1.hasChanged, true);
      expect(diff1.isDeletedField, true);

      const diff2 = FieldDiff(
        label: '职业',
        oldValue: null,
        newValue: '医生',
      );
      expect(diff2.hasChanged, true);
      expect(diff2.isNewField, true);
    });
  });
}
