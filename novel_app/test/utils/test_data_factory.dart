import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';

/// TestDataFactory - 测试数据工厂
///
/// 扩展现有 MockData 类，提供更丰富的测试数据创建功能
/// 支持批量创建、关联数据和完整场景创建
///
/// 核心特性：
/// - 批量创建测试数据
/// - 支持关联数据（角色、关系等）
/// - 完整场景创建（小说+章节+角色）
/// - 自动索引管理
class TestDataFactory {
  /// ========== 小说数据 ==========

  /// 创建单个测试小说
  static Novel createNovel({
    String url = 'https://example.com/novel/1',
    String title = '测试小说',
    String author = '测试作者',
    String? coverUrl,
    String? description = '这是一个测试小说',
    String? backgroundSetting = '测试背景设定',
  }) {
    return Novel(
      url: url,
      title: title,
      author: author,
      coverUrl: coverUrl,
      description: description,
      backgroundSetting: backgroundSetting,
    );
  }

  /// 批量创建测试小说列表
  static List<Novel> createNovelList({
    int count = 3,
    String baseUrl = 'https://example.com/novel/',
  }) {
    return List.generate(
      count,
      (index) => createNovel(
        url: '$baseUrl$index',
        title: '测试小说${index + 1}',
        author: '测试作者${index + 1}',
        description: '这是第${index + 1}个测试小说的描述',
      ),
    );
  }

  /// 创建并添加小说到书架
  static Future<Novel> createAndAddNovel({
    required DatabaseService dbService,
    String url = 'https://example.com/novel/1',
    String title = '测试小说',
    String author = '测试作者',
  }) async {
    final novel = createNovel(
      url: url,
      title: title,
      author: author,
    );

    await dbService.addToBookshelf(novel);

    return novel;
  }

  /// ========== 章节数据 ==========

  /// 创建单个测试章节
  static Chapter createChapter({
    required String novelUrl,
    String url = 'https://example.com/chapter/1',
    String title = '第一章',
    int chapterIndex = 0,
    bool isUserInserted = false,
    String? content,
  }) {
    return Chapter(
      title: title,
      url: url,
      content: content ?? '这是测试章节内容',
      isCached: content != null,
      chapterIndex: chapterIndex,
      isUserInserted: isUserInserted,
    );
  }

  /// 批量创建测试章节列表
  static List<Chapter> createChapterList({
    required String novelUrl,
    int count = 10,
    String baseUrl = 'https://example.com/chapter/',
    bool isUserInserted = false,
  }) {
    return List.generate(
      count,
      (index) => createChapter(
        novelUrl: novelUrl,
        url: '$baseUrl$index',
        title: '第${_numberToChinese(index + 1)}章',
        chapterIndex: index,
        isUserInserted: isUserInserted,
      ),
    );
  }

  /// 创建用户插入的章节
  static Chapter createUserChapter({
    required String novelUrl,
    String title = '用户章节',
    String content = '这是用户创建的章节内容',
    int insertIndex = 0,
  }) {
    return createChapter(
      novelUrl: novelUrl,
      url: 'user://${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      content: content,
      chapterIndex: insertIndex,
      isUserInserted: true,
    );
  }

  /// 创建并缓存章节到数据库
  static Future<List<Chapter>> createAndCacheChapters({
    required DatabaseService dbService,
    required String novelUrl,
    int count = 10,
    String baseUrl = 'https://example.com/chapter/',
  }) async {
    final chapters = createChapterList(
      novelUrl: novelUrl,
      count: count,
      baseUrl: baseUrl,
    );

    // 先保存章节元数据
    for (final chapter in chapters) {
      await dbService.database.then((db) async {
        await db.insert('novel_chapters', {
          'novelUrl': novelUrl,
          'chapterUrl': chapter.url, // 使用 chapterUrl 而不是 url
          'title': chapter.title,
          'chapterIndex': chapter.chapterIndex,
          'isUserInserted': chapter.isUserInserted ? 1 : 0,
        });
      });
    }

    // 缓存章节内容
    for (final chapter in chapters) {
      await dbService.cacheChapter(
        novelUrl,
        chapter,
        '这是${chapter.title}的内容',
      );
    }

    return chapters;
  }

  /// ========== 角色数据 ==========

  /// 创建单个测试角色
  static Character createCharacter({
    required String novelUrl,
    String name = '测试角色',
    String? occupation,
    String? personality,
    String? backgroundStory,
    List<String>? aliases,
    int? age,
    String? gender,
  }) {
    return Character(
      id: null, // 不设置ID,让数据库自动生成
      novelUrl: novelUrl,
      name: name,
      occupation: occupation,
      personality: personality,
      backgroundStory: backgroundStory,
      aliases: aliases,
      age: age,
      gender: gender,
      createdAt: DateTime.now(),
    );
  }

  /// 批量创建测试角色列表
  static List<Character> createCharacterList({
    required String novelUrl,
    int count = 5,
  }) {
    final names = ['张三', '李四', '王五', '赵六', '钱七', '孙八', '周九', '吴十'];

    return List.generate(
      count,
      (index) => createCharacter(
        novelUrl: novelUrl,
        name: names[index % names.length],
        occupation: '职业${index + 1}',
        personality: '性格${index + 1}',
      ),
    );
  }

  /// 创建并保存角色到数据库
  static Future<Character> createAndSaveCharacter({
    required DatabaseService dbService,
    required String novelUrl,
    String name = '测试角色',
  }) async {
    final character = createCharacter(
      novelUrl: novelUrl,
      name: name,
    );

    final db = await dbService.database;
    final id = await db.insert('characters', character.toMap());

    return Character(
      id: id,
      novelUrl: character.novelUrl,
      name: character.name,
      occupation: character.occupation,
      personality: character.personality,
      backgroundStory: character.backgroundStory,
      aliases: character.aliases,
      age: character.age,
      gender: character.gender,
      createdAt: character.createdAt,
    );
  }

  /// ========== 关系数据 ==========

  /// 创建角色关系
  static CharacterRelationship createRelationship({
    required int sourceId,
    required int targetId,
    required String relationshipType,
    String? description,
  }) {
    return CharacterRelationship(
      sourceCharacterId: sourceId,
      targetCharacterId: targetId,
      relationshipType: relationshipType,
      description: description ?? '$relationshipType关系',
    );
  }

  /// ========== 场景插图数据 ==========

  /// 创建场景插图（简化版，不使用SceneIllustration类）
  static Map<String, dynamic> createSceneIllustration({
    required String novelUrl,
    required String chapterId,
    String? taskId,
    String? content,
    String? roles,
    List<String>? images,
    String? prompts,
  }) {
    return {
      'novel_url': novelUrl,
      'chapter_id': chapterId,
      'task_id': taskId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'content': content ?? '测试内容',
      'roles': roles ?? '测试角色',
      'image_count': images?.length ?? 0,
      'status': 'completed',
      'images': images?.join(',') ?? '',
      'prompts': prompts,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// ========== 完整场景创建 ==========

  /// 创建完整的测试场景
  ///
  /// 包含：
  /// - 小说
  /// - 章节（带缓存内容）
  /// - 角色（带关系）
  ///
  /// 返回包含所有创建数据的 Map
  static Future<Map<String, dynamic>> createCompleteScenario({
    required DatabaseService dbService,
    int chapterCount = 10,
    int characterCount = 3,
    String? novelUrl,
  }) async {
    final url = novelUrl ??
        'https://example.com/novel/${DateTime.now().millisecondsSinceEpoch}';

    // 1. 创建并添加小说
    final novel = await createAndAddNovel(
      dbService: dbService,
      url: url,
      title: '完整场景测试小说',
      author: '测试作者',
    );

    // 2. 创建并缓存章节
    final chapters = await createAndCacheChapters(
      dbService: dbService,
      novelUrl: url,
      count: chapterCount,
    );

    // 3. 创建角色（简化版，直接插入数据库）
    final characters = <Character>[];
    final db = await dbService.database;

    for (var i = 0; i < characterCount; i++) {
      final characterMap = {
        'novelUrl': url,
        'name': '角色${i + 1}',
        'occupation': '职业${i + 1}',
        'personality': '性格${i + 1}',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      final id = await db.insert('characters', characterMap);

      final character = Character(
        id: id,
        novelUrl: url,
        name: '角色${i + 1}',
        occupation: '职业${i + 1}',
        personality: '性格${i + 1}',
        createdAt: DateTime.now(),
      );

      characters.add(character);
    }

    // 4. 创建角色关系（如果有多于1个角色）
    final relationships = <CharacterRelationship>[];
    if (characters.length > 1) {
      for (var i = 0; i < characters.length - 1; i++) {
        final relationship = createRelationship(
          sourceId: characters[i].id!,
          targetId: characters[i + 1].id!,
          relationshipType: ['朋友', '师徒', '敌人', '亲人'][i % 4],
        );

        final relationshipId =
            await db.insert('character_relationships', relationship.toMap());

        relationships.add(relationship);
      }
    }

    return {
      'novel': novel,
      'chapters': chapters,
      'characters': characters,
      'relationships': relationships,
      'novelUrl': url,
    };
  }

  /// ========== 辅助方法 ==========

  /// 数字转中文（用于章节标题）
  static String _numberToChinese(int num) {
    const chinese = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];

    if (num <= 10) {
      return chinese[num];
    } else if (num < 20) {
      return '十${chinese[num % 10]}';
    } else {
      final tens = num ~/ 10;
      final units = num % 10;
      return '${chinese[tens]}十${units > 0 ? chinese[units] : ''}';
    }
  }

  /// 生成唯一的测试URL
  static String generateUniqueUrl(String prefix) {
    return '$prefix/${DateTime.now().millisecondsSinceEpoch}';
  }
}
