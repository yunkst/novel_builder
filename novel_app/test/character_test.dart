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

  group('人物管理功能测试', () {
    late DatabaseService databaseService;
    late String testNovelUrl;

    setUpAll(() async {
      databaseService = DatabaseService();
      testNovelUrl = 'https://example.com/test-novel';

      // 确保数据库初始化
      await databaseService.database;
    });

    setUp(() async {
      // 每次测试前清理测试数据
      await _cleanupTestCharacters();
    });

    tearDown(() async {
      // 每次测试后清理测试数据
      await _cleanupTestCharacters();
    });

    test('测试创建新角色 - 完整信息', () async {
      final character = Character(
        name: '张三',
        age: 25,
        gender: '男',
        occupation: '程序员',
        personality: '内向，技术宅',
        bodyType: '中等身材',
        clothingStyle: '休闲装',
        appearanceFeatures: '戴眼镜，短发',
        backgroundStory: '计算机专业毕业，工作三年',
        novelUrl: testNovelUrl,
      );

      // 插入角色
      final id = await databaseService.createCharacter(character);
      expect(id, greaterThan(0));

      // 验证角色是否成功保存
      final retrievedCharacter = await databaseService.getCharacter(id);
      expect(retrievedCharacter, isNotNull);
      expect(retrievedCharacter!.name, equals('张三'));
      expect(retrievedCharacter.age, equals(25));
      expect(retrievedCharacter.gender, equals('男'));
      expect(retrievedCharacter.occupation, equals('程序员'));
      expect(retrievedCharacter.personality, equals('内向，技术宅'));
      expect(retrievedCharacter.bodyType, equals('中等身材'));
      expect(retrievedCharacter.clothingStyle, equals('休闲装'));
      expect(retrievedCharacter.appearanceFeatures, equals('戴眼镜，短发'));
      expect(retrievedCharacter.backgroundStory, equals('计算机专业毕业，工作三年'));
    });

    test('测试创建新角色 - 最少信息', () async {
      final character = Character(
        name: '李四',
        novelUrl: testNovelUrl,
      );

      // 插入角色
      final id = await databaseService.createCharacter(character);
      expect(id, greaterThan(0));

      // 验证角色是否成功保存
      final retrievedCharacter = await databaseService.getCharacter(id);
      expect(retrievedCharacter, isNotNull);
      expect(retrievedCharacter!.name, equals('李四'));
      expect(retrievedCharacter.novelUrl, equals(testNovelUrl));
    });

    test('测试获取小说的所有角色', () async {
      // 创建多个角色
      final characters = [
        Character(name: '角色A', novelUrl: testNovelUrl),
        Character(name: '角色B', novelUrl: testNovelUrl),
        Character(name: '角色C', novelUrl: testNovelUrl),
      ];

      for (final character in characters) {
        await databaseService.createCharacter(character);
      }

      // 创建另一个小说的角色（不应该出现在结果中）
      await databaseService.createCharacter(
        Character(name: '其他小说角色', novelUrl: 'https://other-novel.com'),
      );

      // 获取测试小说的所有角色
      final retrievedCharacters = await databaseService.getCharacters(testNovelUrl);
      expect(retrievedCharacters.length, equals(3));

      final names = retrievedCharacters.map((c) => c.name).toSet();
      expect(names, contains('角色A'));
      expect(names, contains('角色B'));
      expect(names, contains('角色C'));
      expect(names, isNot(contains('其他小说角色')));
    });

    test('测试更新角色信息', () async {
      // 创建初始角色
      final character = Character(
        name: '王五',
        age: 30,
        novelUrl: testNovelUrl,
      );

      final id = await databaseService.createCharacter(character);

      // 更新角色信息
      final updatedCharacter = Character(
        id: id,
        name: '王五',
        age: 31,
        gender: '女',
        occupation: '设计师',
        personality: '开朗活泼',
        bodyType: '苗条',
        clothingStyle: '时尚',
        appearanceFeatures: '长发',
        backgroundStory: '艺术设计专业',
        novelUrl: testNovelUrl,
      );

      final affectedRows = await databaseService.updateCharacter(updatedCharacter);
      expect(affectedRows, greaterThan(0));

      // 验证更新
      final retrievedCharacter = await databaseService.getCharacter(id);
      expect(retrievedCharacter, isNotNull);
      expect(retrievedCharacter!.age, equals(31));
      expect(retrievedCharacter.gender, equals('女'));
      expect(retrievedCharacter.occupation, equals('设计师'));
    });

    test('测试删除角色', () async {
      // 创建角色
      final character = Character(
        name: '赵六',
        novelUrl: testNovelUrl,
      );

      final id = await databaseService.createCharacter(character);

      // 验证角色存在
      var retrievedCharacter = await databaseService.getCharacter(id);
      expect(retrievedCharacter, isNotNull);

      // 删除角色
      final affectedRows = await databaseService.deleteCharacter(id);
      expect(affectedRows, greaterThan(0));

      // 验证角色已被删除
      retrievedCharacter = await databaseService.getCharacter(id);
      expect(retrievedCharacter, isNull);
    });

    test('测试角色信息格式化 - AI友好格式', () async {
      final characters = [
        Character(
          name: '主角',
          gender: '男',
          age: 25,
          occupation: '冒险者',
          personality: '勇敢，正义感强',
          appearanceFeatures: '黑色短发，身材高大',
          bodyType: '健壮',
          clothingStyle: '轻便铠甲',
          backgroundStory: '来自边远村庄的年轻冒险者',
          novelUrl: testNovelUrl,
        ),
        Character(
          name: '女主角',
          gender: '女',
          age: 23,
          occupation: '法师',
          personality: '聪明，冷静',
          appearanceFeatures: '银色长发，蓝色眼眸',
          bodyType: '苗条',
          clothingStyle: '法师长袍',
          backgroundStory: '魔法学院毕业的高材生',
          novelUrl: testNovelUrl,
        ),
      ];

      // 测试角色信息格式化
      final formattedText = Character.formatForAI(characters);

      expect(formattedText, contains('【出场人物】'));
      expect(formattedText, contains('1. 主角'));
      expect(formattedText, contains('2. 女主角'));
      expect(formattedText, contains('基本信息：男，25岁，冒险者'));
      expect(formattedText, contains('性格特点：勇敢，正义感强'));
      expect(formattedText, contains('外貌特征：黑色短发，身材高大'));
      expect(formattedText, contains('身材体型：健壮'));
      expect(formattedText, contains('穿衣风格：轻便铠甲'));
      expect(formattedText, contains('背景经历：来自边远村庄的年轻冒险者'));
    });

    test('测试空角色列表格式化', () async {
      final formattedText = Character.formatForAI([]);
      expect(formattedText, equals('无特定角色出场'));
    });

    test('测试通过ID列表批量获取角色', () async {
      // 创建多个角色
      final character1 = Character(name: '角色1', novelUrl: testNovelUrl);
      final character2 = Character(name: '角色2', novelUrl: testNovelUrl);
      final character3 = Character(name: '角色3', novelUrl: testNovelUrl);

      final id1 = await databaseService.createCharacter(character1);
      await databaseService.createCharacter(character2);
      final id3 = await databaseService.createCharacter(character3);

      // 批量获取角色
      final retrievedCharacters = await databaseService.getCharactersByIds([id1, id3]);
      expect(retrievedCharacters.length, equals(2));

      final names = retrievedCharacters.map((c) => c.name).toSet();
      expect(names, contains('角色1'));
      expect(names, contains('角色3'));
      expect(names, isNot(contains('角色2')));
    });
  });
}

/// 清理测试数据
Future<void> _cleanupTestCharacters() async {
  final db = await DatabaseService().database;
  await db.delete(
    'characters',
    where: 'novelUrl LIKE ?',
    whereArgs: ['%test-novel%'],
  );
}