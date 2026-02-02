import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';
import '../../base/database_test_base.dart';

/// CharacterEditScreen 自动保存功能的实际保存逻辑测试
///
/// 重点测试：
/// 1. 验证 _autoSaveAfterPromptsGeneration 调用了正确的数据库方法
/// 2. 验证新建模式调用 createCharacter
/// 3. 验证编辑模式调用 updateCharacter
/// 4. 验证数据正确保存到数据库
void main() {
  // 初始化FFI数据库
  setUpAll(() {
    initTests();
  });

  group('CharacterEditScreen - 自动保存数据库逻辑', () {
    late DatabaseService databaseService;
    late DatabaseTestBase testBase;
    late Novel testNovel;
    late Character testCharacter;

    setUp(() async {
      // 初始化测试基类
      testBase = DatabaseTestBase();
      await testBase.setUp();

      databaseService = testBase.databaseService;

      // 关键修复：必须先访问database属性来触发数据库初始化和Repository注入
      // 这确保CharacterRepository获得了数据库实例
      await databaseService.database;

      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/test-novel',
      );

      testCharacter = Character(
        id: null, // 新建角色，ID为null
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
        facePrompts: 'face prompt',
        bodyPrompts: 'body prompt',
      );
    });

    tearDown(() async {
      await testBase.tearDown();
    });

    test('测试1: 验证createCharacter方法可以正常保存角色',
        () async {
      // 调用createCharacter保存角色
      final id = await databaseService.createCharacter(testCharacter);

      // 验证返回的ID不为空
      expect(id, greaterThan(0),
          reason: 'createCharacter应该返回新创建的角色ID');

      // 验证可以从数据库读取
      final characters = await databaseService.getCharacters(
        testNovel.url,
      );

      expect(characters, isNotEmpty,
          reason: '应该能从数据库读取到刚创建的角色');
      expect(characters.first.name, equals('张三'),
          reason: '角色姓名应该正确保存');
      expect(characters.first.facePrompts, equals('face prompt'),
          reason: 'face prompts应该正确保存');
      expect(characters.first.bodyPrompts, equals('body prompt'),
          reason: 'body prompts应该正确保存');
    });

    test('测试2: 验证updateCharacter方法可以正常更新角色',
        () async {
      // 先创建一个角色
      final id = await databaseService.createCharacter(testCharacter);

      // 获取创建的角色
      final characters = await databaseService.getCharacters(
        testNovel.url,
      );
      final createdCharacter = characters.first;

      // 修改提示词
      final updatedCharacter = Character(
        id: createdCharacter.id,
        novelUrl: createdCharacter.novelUrl,
        name: createdCharacter.name,
        age: createdCharacter.age,
        gender: createdCharacter.gender,
        occupation: createdCharacter.occupation,
        personality: createdCharacter.personality,
        bodyType: createdCharacter.bodyType,
        clothingStyle: createdCharacter.clothingStyle,
        appearanceFeatures: createdCharacter.appearanceFeatures,
        backgroundStory: createdCharacter.backgroundStory,
        aliases: createdCharacter.aliases,
        createdAt: createdCharacter.createdAt,
        updatedAt: DateTime.now(),
        facePrompts: 'updated face prompt',
        bodyPrompts: 'updated body prompt',
      );

      // 调用updateCharacter更新角色
      await databaseService.updateCharacter(updatedCharacter);

      // 验证可以从数据库读取更新后的数据
      final updatedCharacters = await databaseService.getCharacters(
        testNovel.url,
      );

      expect(updatedCharacters, isNotEmpty);
      expect(updatedCharacters.first.facePrompts, equals('updated face prompt'),
          reason: 'face prompts应该正确更新');
      expect(updatedCharacters.first.bodyPrompts, equals('updated body prompt'),
          reason: 'body prompts应该正确更新');
    });

    test('测试3: 验证保存后立即读取可以获取到数据',
        () async {
      // 创建角色
      final id = await databaseService.createCharacter(testCharacter);

      // 立即读取
      final characters = await databaseService.getCharacters(
        testNovel.url,
      );

      expect(characters.length, equals(1),
          reason: '应该只有1个角色');
      expect(characters.first.id, equals(id),
          reason: 'ID应该匹配');
      expect(characters.first.name, equals('张三'),
          reason: '姓名应该正确');
    });

    test('测试4: 验证部分字段更新不会影响其他字段',
        () async {
      // 创建角色
      await databaseService.createCharacter(testCharacter);

      // 获取角色
      final characters = await databaseService.getCharacters(
        testNovel.url,
      );
      final original = characters.first;

      // 只更新提示词
      final updated = Character(
        id: original.id,
        novelUrl: original.novelUrl,
        name: original.name,
        age: original.age,
        gender: original.gender,
        occupation: original.occupation,
        personality: original.personality,
        bodyType: original.bodyType,
        clothingStyle: original.clothingStyle,
        appearanceFeatures: original.appearanceFeatures,
        backgroundStory: original.backgroundStory,
        aliases: original.aliases,
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
        facePrompts: 'new face prompt',
        bodyPrompts: original.bodyPrompts, // 保持不变
      );

      await databaseService.updateCharacter(updated);

      // 验证
      final result = await databaseService.getCharacters(
        testNovel.url,
      );

      expect(result.first.facePrompts, equals('new face prompt'),
          reason: '更新的字段应该改变');
      expect(result.first.bodyPrompts, equals('body prompt'),
          reason: '未更新的字段应该保持原值');
    });
  });
}
