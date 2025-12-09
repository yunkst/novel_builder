import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/character.dart';

void main() {
  // 初始化FFI数据库工厂
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('角色选择功能集成测试', () {
    late DatabaseService databaseService;
    late String testNovelUrl;

    setUpAll(() async {
      databaseService = DatabaseService();
      testNovelUrl = 'https://example.com/integration-test-novel';
      await databaseService.database;
    });

    setUp(() async {
      await _cleanupTestData();
    });

    tearDown(() async {
      await _cleanupTestData();
    });

    test('测试角色选择在章节生成中的完整流程', () async {
      // 1. 创建测试角色
      final protagonist = Character(
        name: '主角张明',
        age: 25,
        gender: '男',
        occupation: '大学生',
        personality: '开朗，善良，有正义感',
        bodyType: '中等身材',
        clothingStyle: '休闲装',
        appearanceFeatures: '黑色短发，眼神明亮',
        backgroundStory: '计算机系大三学生，喜欢编程和帮助别人',
        novelUrl: testNovelUrl,
      );

      final supportingCharacter = Character(
        name: '女配角李雪',
        age: 23,
        gender: '女',
        occupation: '研究生',
        personality: '文静，聪明，理性',
        bodyType: '苗条',
        clothingStyle: '学院风',
        appearanceFeatures: '长发戴眼镜，气质文雅',
        backgroundStory: '化学系研究生，主角的同学',
        novelUrl: testNovelUrl,
      );

      // 2. 插入角色到数据库
      final protagonistId = await databaseService.createCharacter(protagonist);
      final supportingCharacterId = await databaseService.createCharacter(supportingCharacter);

      expect(protagonistId, greaterThan(0));
      expect(supportingCharacterId, greaterThan(0));

      // 3. 模拟用户选择角色（模拟CharacterSelector的行为）
      final selectedCharacterIds = [protagonistId, supportingCharacterId];

      // 4. 模拟章节生成流程中的角色信息获取和格式化
      final selectedCharacters = await databaseService.getCharactersByIds(selectedCharacterIds);
      expect(selectedCharacters.length, equals(2));

      // 5. 测试角色信息格式化
      final rolesInfo = Character.formatForAI(selectedCharacters);

      // 6. 验证格式化结果包含预期内容
      expect(rolesInfo, contains('【出场人物】'));
      expect(rolesInfo, contains('1. 主角张明'));
      expect(rolesInfo, contains('2. 女配角李雪'));
      expect(rolesInfo, contains('基本信息：男，25岁，大学生'));
      expect(rolesInfo, contains('基本信息：女，23岁，研究生'));
      expect(rolesInfo, contains('性格特点：开朗，善良，有正义感'));
      expect(rolesInfo, contains('性格特点：文静，聪明，理性'));
      expect(rolesInfo, contains('外貌特征：黑色短发，眼神明亮'));
      expect(rolesInfo, contains('外貌特征：长发戴眼镜，气质文雅'));
      expect(rolesInfo, contains('背景经历：计算机系大三学生，喜欢编程和帮助别人'));
      expect(rolesInfo, contains('背景经历：化学系研究生，主角的同学'));

      // 7. 验证格式化文本的结构完整性
      final lines = rolesInfo.split('\n');
      expect(lines.any((line) => line.contains('【出场人物】')), isTrue);
      expect(lines.where((line) => line.contains('基本信息：')).length, equals(2));
      expect(lines.where((line) => line.contains('性格特点：')).length, equals(2));
      expect(lines.where((line) => line.contains('外貌特征：')).length, equals(2));
      expect(lines.where((line) => line.contains('身材体型：')).length, equals(2));
      expect(lines.where((line) => line.contains('穿衣风格：')).length, equals(2));
      expect(lines.where((line) => line.contains('背景经历：')).length, equals(2));
    });

    test('测试无角色选择的默认行为', () async {
      // 1. 模拟用户未选择任何角色
      final selectedCharacterIds = <int>[];

      // 2. 模拟章节生成流程
      final selectedCharacters = await databaseService.getCharactersByIds(selectedCharacterIds);
      expect(selectedCharacters.isEmpty, isTrue);

      // 3. 测试空角色列表的格式化
      final rolesInfo = Character.formatForAI(selectedCharacters);
      expect(rolesInfo, equals('无特定角色出场'));
    });

    test('测试部分角色选择的场景', () async {
      // 1. 创建多个角色
      final characters = [
        Character(name: '角色A', age: 30, gender: '男', novelUrl: testNovelUrl),
        Character(name: '角色B', age: 25, gender: '女', novelUrl: testNovelUrl),
        Character(name: '角色C', age: 35, gender: '男', novelUrl: testNovelUrl),
      ];

      // 2. 插入角色
      final ids = <int>[];
      for (final character in characters) {
        final id = await databaseService.createCharacter(character);
        ids.add(id);
      }

      // 3. 模拟用户只选择部分角色（选择角色A和角色C）
      final selectedCharacterIds = [ids[0], ids[2]];
      final selectedCharacters = await databaseService.getCharactersByIds(selectedCharacterIds);

      expect(selectedCharacters.length, equals(2));

      final selectedNames = selectedCharacters.map((c) => c.name).toSet();
      expect(selectedNames, contains('角色A'));
      expect(selectedNames, contains('角色C'));
      expect(selectedNames, isNot(contains('角色B')));

      // 4. 测试格式化结果只包含选中的角色
      final rolesInfo = Character.formatForAI(selectedCharacters);
      expect(rolesInfo, contains('角色A'));
      expect(rolesInfo, contains('角色C'));
      expect(rolesInfo, isNot(contains('角色B')));
    });

    test('测试角色选择状态的持久化', () async {
      // 1. 创建角色
      final character = Character(
        name: '持久化测试角色',
        age: 28,
        gender: '女',
        occupation: '教师',
        novelUrl: testNovelUrl,
      );

      final characterId = await databaseService.createCharacter(character);

      // 2. 模拟角色选择状态（在实际应用中，这会由CharacterSelector管理）
      var selectedIds = [characterId];

      // 3. 验证可以基于选择的ID获取角色信息
      final retrievedCharacters = await databaseService.getCharactersByIds(selectedIds);
      expect(retrievedCharacters.length, equals(1));
      expect(retrievedCharacters.first.name, equals('持久化测试角色'));

      // 4. 模拟选择状态变化（用户取消选择）
      selectedIds = [];
      final emptySelection = await databaseService.getCharactersByIds(selectedIds);
      expect(emptySelection.isEmpty, isTrue);
    });
  });
}

/// 清理测试数据
Future<void> _cleanupTestData() async {
  final db = await DatabaseService().database;
  await db.delete(
    'characters',
    where: 'novelUrl LIKE ?',
    whereArgs: ['%integration-test-novel%'],
  );
}