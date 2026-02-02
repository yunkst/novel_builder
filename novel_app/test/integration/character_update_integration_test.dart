import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_update.dart';
import 'package:novel_app/services/character_card_service.dart';
import 'package:novel_app/models/novel.dart';
import '../test_bootstrap.dart';

void main() {
  // 初始化数据库测试环境
  setUpAll(() {
    initTests();
  });

  group('角色更新流程集成测试', () {
    late CharacterCardService service;

    setUp(() {
      service = CharacterCardService();
    });

    test('完整流程测试: 模拟新增和更新角色场景', () async {
      // 准备测试数据
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel1',
      );

      final testChapterContent = '''
第一章: 新的开始

张三走进了房间,看到李四已经坐在那里等候。
"你来了。"李四说道。
张三点点头,找了个位置坐下。

窗外下着小雨,两人陷入了沉默。
''';

      // 模拟现有角色(张三已存在,李四是新增)
      final existingCharacters = [
        Character(
          id: 1,
          novelUrl: testNovel.url,
          name: '张三',
          age: 20,
          gender: '男',
          personality: '开朗',
        ),
      ];

      // 模拟AI返回的更新后角色
      final updatedCharacters = [
        Character(
          novelUrl: testNovel.url,
          name: '张三',
          age: 22, // 年龄从20变为22
          gender: '男',
          personality: '沉稳', // 性格从开朗变为沉稳
          occupation: '医生', // 新增职业字段
        ),
        Character(
          novelUrl: testNovel.url,
          name: '李四', // 新增角色
          age: 25,
          gender: '女',
          personality: '内向',
        ),
      ];

      // 创建CharacterUpdate列表(模拟服务层返回)
      final characterUpdates = [
        // 张三 - 更新角色
        CharacterUpdate(
          newCharacter: updatedCharacters[0],
          oldCharacter: existingCharacters[0],
        ),
        // 李四 - 新增角色
        CharacterUpdate(
          newCharacter: updatedCharacters[1],
          oldCharacter: null, // null表示新增
        ),
      ];

      // 验证统计数据
      final newCount = characterUpdates.where((u) => u.isNew).length;
      final updateCount = characterUpdates.where((u) => u.isUpdate).length;

      expect(newCount, 1, reason: '应该有1个新增角色(李四)');
      expect(updateCount, 1, reason: '应该有1个更新角色(张三)');

      // 验证张三的变更
      final zhangSanUpdate = characterUpdates[0];
      expect(zhangSanUpdate.isUpdate, true);
      expect(zhangSanUpdate.isNew, false);

      final zhangSanDiffs = zhangSanUpdate.getDifferences();
      expect(zhangSanDiffs.length, greaterThan(0), reason: '张三应该有字段变化');

      final zhangSanDiffLabels = zhangSanDiffs.map((d) => d.label).toSet();
      expect(zhangSanDiffLabels, contains('年龄'));
      expect(zhangSanDiffLabels, contains('性格'));
      expect(zhangSanDiffLabels, contains('职业'));

      // 验证李四的新增状态
      final liSiUpdate = characterUpdates[1];
      expect(liSiUpdate.isNew, true);
      expect(liSiUpdate.isUpdate, false);
      expect(liSiUpdate.getDifferences(), isEmpty, reason: '新增角色不应有差异列表');
    });

    test('应该正确处理无变化的角色', () {
      final char = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        gender: '男',
      );

      final update = CharacterUpdate(
        newCharacter: char,
        oldCharacter: char,
      );

      expect(update.isUpdate, true);
      expect(update.getDifferences(), isEmpty);
    });

    test('应该正确处理部分字段为null的情况', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        occupation: null,
        personality: null,
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        occupation: '医生',
        personality: '开朗',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(2));

      final diffLabels = diffs.map((d) => d.label).toSet();
      expect(diffLabels, containsAll(['职业', '性格']));
    });

    test('应该正确处理字段被删除的情况', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        occupation: '医生',
        personality: '开朗',
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        // occupation被删除
        personality: '开朗',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(1));
      expect(diffs[0].label, '职业');
      expect(diffs[0].isDeletedField, true);
      expect(diffs[0].oldValue, '医生');
      expect(diffs[0].newValue, null);
    });

    test('复杂场景: 混合新增、更新、无变化角色', () {
      // 场景: 3个角色 - 1个新增, 1个更新, 1个无变化
      final updates = [
        // 新增角色
        CharacterUpdate(
          newCharacter: Character(
            novelUrl: 'test_novel',
            name: '王五',
            age: 30,
          ),
          oldCharacter: null,
        ),
        // 更新角色
        CharacterUpdate(
          newCharacter: Character(
            id: 2,
            novelUrl: 'test_novel',
            name: '张三',
            age: 25,
          ),
          oldCharacter: Character(
            id: 2,
            novelUrl: 'test_novel',
            name: '张三',
            age: 20,
          ),
        ),
        // 无变化角色
        CharacterUpdate(
          newCharacter: Character(
            id: 3,
            novelUrl: 'test_novel',
            name: '李四',
            age: 22,
          ),
          oldCharacter: Character(
            id: 3,
            novelUrl: 'test_novel',
            name: '李四',
            age: 22,
          ),
        ),
      ];

      final newCount = updates.where((u) => u.isNew).length;
      final updateCount = updates.where((u) => u.isUpdate).length;
      final changedCount = updates.where((u) => u.getDifferences().isNotEmpty).length;

      expect(newCount, 1);
      expect(updateCount, 2); // 包括更新+无变化的角色
      expect(changedCount, 1); // 只有1个有实际变化
    });

    test('边界情况: 空角色列表', () {
      final updates = <CharacterUpdate>[];
      final newCount = updates.where((u) => u.isNew).length;
      final updateCount = updates.where((u) => u.isUpdate).length;

      expect(newCount, 0);
      expect(updateCount, 0);
    });

    test('边界情况: 所有字段都变化的更新', () {
      final oldChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 20,
        gender: '男',
        occupation: '学生',
        personality: '内向',
        bodyType: '瘦弱',
        clothingStyle: '朴素',
        appearanceFeatures: '黑发',
        backgroundStory: '孤儿',
      );

      final newChar = Character(
        id: 1,
        novelUrl: 'test_novel',
        name: '张三',
        age: 30,
        gender: '女',
        occupation: '医生',
        personality: '开朗',
        bodyType: '健壮',
        clothingStyle: '华丽',
        appearanceFeatures: '金发',
        backgroundStory: '贵族',
      );

      final update = CharacterUpdate(
        newCharacter: newChar,
        oldCharacter: oldChar,
      );

      final diffs = update.getDifferences();
      expect(diffs, hasLength(8)); // 所有字段都变化

      final diffLabels = diffs.map((d) => d.label).toSet();
      expect(
        diffLabels,
        containsAll(['年龄', '性别', '职业', '性格', '体型', '着装', '外貌', '背景']),
      );
    });
  });
}
