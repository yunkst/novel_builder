import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/models/ai_companion_response.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import '../test_bootstrap.dart';

/// AI伴读自动触发功能测试
///
/// 测试目标:
/// 1. 验证背景设定正确追加到数据库
/// 2. 验证角色信息正确更新
/// 3. 验证关系信息正确更新
/// 4. 验证章节标记为已伴读
void main() {
  // 初始化测试环境
  initDatabaseTests();

  late DatabaseService databaseService;

  setUp(() async {
    // 每个测试前初始化数据库服务
    databaseService = DatabaseService();
    await databaseService.database; // 触发数据库初始化
  });

  // 不在tearDown中关闭数据库，因为DatabaseService是单例
  // 跨测试共享数据库实例

  group('AI伴读 - 背景设定更新测试', () {
    test('测试1: 空背景设定时追加新内容', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel1';
      const testBackground = '这是一个修真世界，灵气复苏。';

      // 创建小说
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说',
          author: '测试作者',
          url: novelUrl,
          coverUrl: 'https://example.com/cover.jpg',
        ),
      );

      // Act
      final count = await databaseService.appendBackgroundSetting(
        novelUrl,
        testBackground,
      );

      // Assert
      expect(count, greaterThan(0), reason: '应该更新1条记录');

      // 验证背景设定已保存
      final novels = await databaseService.getBookshelf();
      final novel = novels.firstWhere((n) => n.url == novelUrl);
      expect(novel.backgroundSetting, equals(testBackground),
          reason: '背景设定应该被完整保存');
    });

    test('测试2: 已有背景设定时追加新内容', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel2';
      const existingBackground = '原有背景设定: 这是一个魔法世界。';
      const newBackground = '新增背景: 主角来到了东方大陆。';

      // 创建小说并设置初始背景
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说2',
          author: '测试作者',
          url: novelUrl,
          backgroundSetting: existingBackground,
        ),
      );

      // Act
      final count = await databaseService.appendBackgroundSetting(
        novelUrl,
        newBackground,
      );

      // Assert
      expect(count, greaterThan(0));

      // 验证背景设定已正确追加
      final novels = await databaseService.getBookshelf();
      final novel = novels.firstWhere((n) => n.url == novelUrl);

      final expectedBackground = '$existingBackground\n\n$newBackground';
      expect(novel.backgroundSetting, equals(expectedBackground),
          reason: '新背景应该追加到旧背景之后,用双换行分隔');
    });

    test('测试3: 尝试追加空背景设定', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel3';
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说3',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // Act
      final count = await databaseService.appendBackgroundSetting(
        novelUrl,
        '', // 空背景
      );

      // Assert
      expect(count, equals(0), reason: '空背景应该跳过更新,返回0');

      // 验证背景设定仍为null
      final novels = await databaseService.getBookshelf();
      final novel = novels.firstWhere((n) => n.url == novelUrl);
      expect(novel.backgroundSetting, isNull,
          reason: '空背景不应该被保存');
    });

    test('测试4: 尝试追加仅含空白的背景设定', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel4';
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说4',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // Act
      final count = await databaseService.appendBackgroundSetting(
        novelUrl,
        '   \n\n  ', // 仅空白
      );

      // Assert
      expect(count, equals(0), reason: '仅空白的背景应该跳过更新');
    });
  });

  group('AI伴读 - 角色信息更新测试', () {
    test('测试5: 批量更新或插入角色', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel5';
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说5',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 创建AI伴读返回的角色数据
      final aiRoles = [
        AICompanionRole(
          name: '张三',
          gender: '男',
          age: 25,
          occupation: '修士',
          personality: '勇敢坚毅',
        ),
        AICompanionRole(
          name: '李四',
          gender: '女',
          age: 23,
          occupation: '医师',
          personality: '温柔善良',
        ),
      ];

      // Act
      final updatedCount = await databaseService.batchUpdateOrInsertCharacters(
        novelUrl,
        aiRoles,
      );

      // Assert
      expect(updatedCount, equals(2),
          reason: '应该成功更新2个角色');

      // 验证角色已保存
      final characters = await databaseService.getCharacters(novelUrl);
      expect(characters.length, equals(2));

      // 验证角色信息
      final zhangSan = characters.firstWhere((c) => c.name == '张三');
      expect(zhangSan.gender, equals('男'));
      expect(zhangSan.age, equals(25));
      expect(zhangSan.occupation, equals('修士'));
      expect(zhangSan.personality, equals('勇敢坚毅'));

      final liSi = characters.firstWhere((c) => c.name == '李四');
      expect(liSi.gender, equals('女'));
      expect(liSi.age, equals(23));
    });

    test('测试6: 更新已存在的角色', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel6';
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说6',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 先插入一个角色
      await databaseService.updateOrInsertCharacter(
        Character(
          novelUrl: novelUrl,
          name: '王五',
          gender: '男',
          age: 30,
          occupation: '剑客',
        ),
      );

      // AI伴读返回该角色的更新信息
      final aiRoles = [
        AICompanionRole(
          name: '王五',
          gender: '男',
          age: 31, // 年龄更新
          occupation: '剑客',
          personality: '冷峻孤傲', // 新增性格
        ),
      ];

      // Act
      final updatedCount = await databaseService.batchUpdateOrInsertCharacters(
        novelUrl,
        aiRoles,
      );

      // Assert
      expect(updatedCount, equals(1));

      // 验证角色信息已更新
      final characters = await databaseService.getCharacters(novelUrl);
      final wangWu = characters.firstWhere((c) => c.name == '王五');

      expect(wangWu.age, equals(31),
          reason: '年龄应该从30更新到31');
      expect(wangWu.personality, equals('冷峻孤傲'),
          reason: '应该新增性格属性');
    });
  });

  group('AI伴读 - 关系信息更新测试', () {
    test('测试7: 批量更新或插入关系', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel7';
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说7',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 先创建角色
      final zhangSan = await databaseService.updateOrInsertCharacter(
        Character(novelUrl: novelUrl, name: '张三'),
      );
      final liSi = await databaseService.updateOrInsertCharacter(
        Character(novelUrl: novelUrl, name: '李四'),
      );

      // AI伴读返回的关系数据
      final aiRelations = [
        AICompanionRelation(
          source: '张三',
          target: '李四',
          type: '师父',
        ),
      ];

      // Act
      final updatedCount = await databaseService.batchUpdateOrInsertRelationships(
        novelUrl,
        aiRelations,
      );

      // Assert
      expect(updatedCount, equals(1));

      // 验证关系已保存
      final relationships = await databaseService.getRelationships(zhangSan.id!);
      expect(relationships.length, greaterThan(0));

      final relation = relationships.firstWhere(
        (r) => r.sourceCharacterId == zhangSan.id && r.targetCharacterId == liSi.id,
      );
      expect(relation.relationshipType, contains('师父'));
    });

    test('测试8: 更新已存在的关系描述', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel8';
      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说8',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 先创建角色和关系
      final zhangSan = await databaseService.updateOrInsertCharacter(
        Character(novelUrl: novelUrl, name: '张三'),
      );
      final liSi = await databaseService.updateOrInsertCharacter(
        Character(novelUrl: novelUrl, name: '李四'),
      );

      await databaseService.createRelationship(
        CharacterRelationship(
          sourceCharacterId: zhangSan.id!,
          targetCharacterId: liSi.id!,
          relationshipType: '师徒',
          description: '普通师徒关系',
        ),
      );

      // AI伴读返回的关系更新
      final aiRelations = [
        AICompanionRelation(
          source: '张三',
          target: '李四',
          type: '师徒',
        ),
      ];

      // Act
      final updatedCount = await databaseService.batchUpdateOrInsertRelationships(
        novelUrl,
        aiRelations,
      );

      // Assert
      expect(updatedCount, equals(1));
      // 验证关系已存在(不会被重复插入)
      final relationships = await databaseService.getRelationships(zhangSan.id!);
      final existingRelations = relationships.where(
        (r) => r.sourceCharacterId == zhangSan.id && r.targetCharacterId == liSi.id,
      );
      expect(existingRelations.length, equals(1),
          reason: '关系应该已存在,不会重复插入');
    });
  });

  group('AI伴读 - 章节伴读标记测试', () {
    test('测试9: 标记章节为已伴读', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel9';
      const chapterUrl = 'https://example.com/novel9/chapter1';

      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说9',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 先缓存章节
      final chapter = Chapter(
        title: '第一章',
        url: chapterUrl,
        chapterIndex: 1,
        content: '章节内容...',
      );
      await databaseService.cacheChapter(
        novelUrl,
        chapter,
        chapter.content ?? '',
      );

      // Act
      await databaseService.markChapterAsAccompanied(novelUrl, chapterUrl);

      // Assert
      final isAccompanied =
          await databaseService.isChapterAccompanied(novelUrl, chapterUrl);
      expect(isAccompanied, isTrue,
          reason: '章节应该被标记为已伴读');
    });

    test('测试10: 检查未伴读的章节', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel10';
      const chapterUrl = 'https://example.com/novel10/chapter1';

      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说10',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      final chapter = Chapter(
        title: '第一章',
        url: chapterUrl,
        chapterIndex: 1,
        content: '章节内容...',
      );
      await databaseService.cacheChapter(
        novelUrl,
        chapter,
        chapter.content ?? '',
      );

      // Act - 不标记为已伴读

      // Assert
      final isAccompanied =
          await databaseService.isChapterAccompanied(novelUrl, chapterUrl);
      expect(isAccompanied, isFalse,
          reason: '章节应该未标记为已伴读');
    });

    test('测试11: 重置章节伴读标记', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel11';
      const chapterUrl = 'https://example.com/novel11/chapter1';

      await databaseService.addToBookshelf(
        Novel(
          title: '测试小说11',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      final chapter = Chapter(
        title: '第一章',
        url: chapterUrl,
        chapterIndex: 1,
        content: '章节内容...',
      );
      await databaseService.cacheChapter(
        novelUrl,
        chapter,
        chapter.content ?? '',
      );

      // 标记为已伴读
      await databaseService.markChapterAsAccompanied(novelUrl, chapterUrl);

      // 验证已标记
      var isAccompanied =
          await databaseService.isChapterAccompanied(novelUrl, chapterUrl);
      expect(isAccompanied, isTrue);

      // Act - 重置标记
      await databaseService.resetChapterAccompaniedFlag(novelUrl, chapterUrl);

      // Assert
      isAccompanied =
          await databaseService.isChapterAccompanied(novelUrl, chapterUrl);
      expect(isAccompanied, isFalse,
          reason: '章节标记应该被重置');
    });
  });

  group('AI伴读 - 完整流程集成测试', () {
    test('测试12: 模拟完整AI伴读流程', () async {
      // Arrange
      const novelUrl = 'https://example.com/novel12';
      const chapterUrl = 'https://example.com/novel12/chapter1';

      await databaseService.addToBookshelf(
        Novel(
          title: '完整流程测试',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      final chapter = Chapter(
        title: '第一章',
        url: chapterUrl,
        chapterIndex: 1,
        content: '这是第一章的内容...',
      );
      await databaseService.cacheChapter(
        novelUrl,
        chapter,
        chapter.content ?? '',
      );

      // 模拟AI伴读返回的数据
      final response = AICompanionResponse(
        roles: [
          AICompanionRole(
            name: '主角',
            gender: '男',
            age: 20,
            occupation: '修真者',
          ),
        ],
        background: '这是一个灵气复苏的修真世界。',
        summery: '主角踏上修真之路。',
        relations: [
          AICompanionRelation(
            source: '主角',
            target: '师父',
            type: '徒弟',
          ),
        ],
      );

      // Act - 执行完整的AI伴读更新流程

      // 1. 追加背景设定
      await databaseService.appendBackgroundSetting(
        novelUrl,
        response.background,
      );

      // 2. 更新角色
      await databaseService.batchUpdateOrInsertCharacters(
        novelUrl,
        response.roles,
      );

      // 3. 更新关系
      await databaseService.updateOrInsertCharacter(
        Character(novelUrl: novelUrl, name: '师父'),
      );
      await databaseService.batchUpdateOrInsertRelationships(
        novelUrl,
        response.relations,
      );

      // 4. 标记章节为已伴读
      await databaseService.markChapterAsAccompanied(novelUrl, chapterUrl);

      // Assert - 验证所有数据都已正确保存
      // 1. 验证背景设定
      final novels = await databaseService.getBookshelf();
      final novel = novels.firstWhere((n) => n.url == novelUrl);
      expect(novel.backgroundSetting, equals(response.background),
          reason: '背景设定应该被保存');

      // 2. 验证角色
      final characters = await databaseService.getCharacters(novelUrl);
      expect(characters.length, equals(2), reason: '应该有2个角色');
      final protagonist = characters.firstWhere((c) => c.name == '主角');
      expect(protagonist.occupation, equals('修真者'));

      // 3. 验证关系
      final shifu = characters.firstWhere((c) => c.name == '师父');
      final relationships = await databaseService.getRelationships(protagonist.id!);
      expect(relationships.length, greaterThan(0));
      final relation = relationships.firstWhere(
        (r) => r.targetCharacterId == shifu.id,
      );
      expect(relation.relationshipType, contains('徒弟'));

      // 4. 验证伴读标记
      final isAccompanied =
          await databaseService.isChapterAccompanied(novelUrl, chapterUrl);
      expect(isAccompanied, isTrue,
          reason: '章节应该被标记为已伴读');

      print('✅ 完整AI伴读流程测试通过!');
      print('   - 背景设定已保存');
      print('   - 角色信息已更新');
      print('   - 关系信息已更新');
      print('   - 章节已标记为伴读');
    });
  });
}
