/// ToolExecutor 工具执行器单元测试 — 真实 SQLite
///
/// 使用内存 SQLite 数据库 + 真实 Repository 实现，
/// 验证 12 个工具端到端的执行逻辑（ID-based）：
/// - 正常路径：数据写入 → 工具读取 → 返回正确 JSON
/// - 边界条件：空数据、未缓存章节、角色不存在、大纲不存在
/// - 错误处理：未知工具、ID 不存在（含 suggested_tool）
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/novel_agent/tool_executor_test.dart
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqflite.dart';

import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/core/interfaces/i_database_connection.dart';
import 'package:novel_app/core/interfaces/repositories/i_chapter_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_character_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_novel_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_outline_repository.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/outline.dart';
import 'package:novel_app/services/novel_agent/tool_executor.dart';
import '../../../helpers/test_database_setup.dart' as test_db;

/// 注册一个测试用 Provider，让 Riverpod 框架提供真正的 Ref
final _toolExecutorProvider = Provider<ToolExecutor>((ref) {
  return ToolExecutor(ref);
});

void main() {
  late ProviderContainer container;
  late ToolExecutor executor;
  late Database db;
  late INovelRepository novelRepo;
  late IChapterRepository chapterRepo;
  late ICharacterRepository characterRepo;
  late IOutlineRepository outlineRepo;

  setUp(() async {
    db = await test_db.TestDatabaseSetup.createInMemoryDatabase();
    final dbConnection = DatabaseConnection.forTesting(db);
    container = ProviderContainer(
      overrides: [
        databaseConnectionProvider.overrideWithValue(dbConnection),
      ],
    );
    novelRepo = container.read(novelRepositoryProvider);
    chapterRepo = container.read(chapterRepositoryProvider);
    characterRepo = container.read(characterRepositoryProvider);
    outlineRepo = container.read(outlineRepositoryProvider);
    executor = container.read(_toolExecutorProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // ========================================================================
  // 辅助方法
  // ========================================================================

  /// 插入一条测试小说，返回 novelId
  Future<int> insertNovel({
    String title = '测试小说',
    String author = '测试作者',
    String url = 'https://example.com/novel1',
    String? description,
    String? backgroundSetting,
  }) async {
    final novel = Novel(
      title: title,
      author: author,
      url: url,
      description: description,
      backgroundSetting: backgroundSetting,
    );
    await novelRepo.addToBookshelf(novel);
    final novels = await novelRepo.getNovels();
    return novels.firstWhere((n) => n.url == url).id!;
  }

  /// 测试用默认小说 URL
  const defaultNovelUrl = 'https://example.com/novel1';

  /// 缓存一条章节（同时写入 chapter_cache 和 novel_chapters），返回 chapterId
  Future<int> insertChapter({
    String novelUrl = defaultNovelUrl,
    String chapterUrl = 'https://example.com/ch1',
    String title = '第一章',
    String content = '段落0\n\n段落1\n\n段落2',
    int chapterIndex = 0,
  }) async {
    await chapterRepo.cacheChapter(
      novelUrl,
      Chapter(
        title: title,
        url: chapterUrl,
        chapterIndex: chapterIndex,
        isCached: true,
      ),
      content,
    );
    await chapterRepo.cacheNovelChapters(novelUrl, [
      Chapter(
        title: title,
        url: chapterUrl,
        chapterIndex: chapterIndex,
        isCached: true,
      ),
    ]);
    final chapters = await chapterRepo.getCachedNovelChapters(novelUrl);
    return chapters.firstWhere((c) => c.url == chapterUrl).id!;
  }

  /// 插入一条角色
  Future<void> insertCharacter({
    String novelUrl = defaultNovelUrl,
    String name = '李云',
    String appearanceFeatures = '白衣剑客',
  }) async {
    await characterRepo.createCharacter(Character(
      novelUrl: novelUrl,
      name: name,
      appearanceFeatures: appearanceFeatures,
    ));
  }

  /// 插入一条大纲
  Future<void> insertOutline({
    String novelUrl = defaultNovelUrl,
    String title = '全书大纲',
    String content = '第一幕\n第二幕\n第三幕',
  }) async {
    await outlineRepo.saveOutline(Outline(
      novelUrl: novelUrl,
      title: title,
      content: content,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ));
  }

  // ========================================================================
  // list_novels
  // ========================================================================
  group('list_novels', () {
    test('空书架返回空列表', () async {
      final result = await executor.execute('list_novels', {});
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['count'], 0);
      expect((json['novels'] as List).isEmpty, true);
    });

    test('返回所有小说', () async {
      await insertNovel(title: '小说A', url: 'urlA');
      await insertNovel(title: '小说B', url: 'urlB', description: '简介');

      final result = await executor.execute('list_novels', {});
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['count'], 2);
      final novels = json['novels'] as List;
      expect(novels.any((n) => n['title'] == '小说A'), true);
      expect(novels.any((n) => n['title'] == '小说B'), true);
    });

    test('每本小说返回 id 字段', () async {
      await insertNovel(title: '小说X');
      final result = await executor.execute('list_novels', {});
      final json = jsonDecode(result) as Map<String, dynamic>;
      final novels = json['novels'] as List;
      expect(novels.first['id'], isA<int>());
      expect(novels.first['id'], greaterThan(0));
    });

    test('长描述截断到 200 字符', () async {
      await insertNovel(url: 'urlLong', description: 'x' * 300);
      final result = await executor.execute('list_novels', {});
      final json = jsonDecode(result) as Map<String, dynamic>;
      final desc = (json['novels'] as List).first['description'] as String?;
      expect(desc!.endsWith('...'), true);
      expect(desc.length, 203);
    });

    test('返回结果中不含 url 字段', () async {
      await insertNovel();
      final result = await executor.execute('list_novels', {});
      final json = jsonDecode(result) as Map<String, dynamic>;
      final novel = (json['novels'] as List).first;
      expect(novel.containsKey('url'), false,
          reason: 'AI 不应看到 url 字段');
    });
  });

  // ========================================================================
  // read_chapter_content
  // ========================================================================
  group('read_chapter_content', () {
    test('返回章节内容', () async {
      await insertNovel();
      final chId = await insertChapter(content: '这是章节内容');

      final result = await executor.execute(
        'read_chapter_content',
        {'chapterId': chId},
      );

      expect(result, '这是章节内容');
    });

    test('章节不存在 → 返回 chapter_not_found + suggested_tool', () async {
      final result = await executor.execute(
        'read_chapter_content',
        {'chapterId': 99999},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], 'chapter_not_found');
      expect(json['suggested_tool'], 'list_chapters');
      expect(json['message'].toString(), contains('99999'));
    });
  });

  // ========================================================================
  // list_chapters
  // ========================================================================
  group('list_chapters', () {
    test('返回章节列表', () async {
      final novelId = await insertNovel();
      await insertChapter(
          chapterUrl: 'ch1', title: '第一章', chapterIndex: 0);
      await insertChapter(
          chapterUrl: 'ch2', title: '第二章', chapterIndex: 1);

      final result = await executor.execute(
        'list_chapters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['count'], 2);
      final chapters = json['chapters'] as List;
      expect(chapters[0]['title'], '第一章');
      expect(chapters[1]['title'], '第二章');
    });

    test('返回结果包含 novel 上下文（{id, title}）', () async {
      final novelId = await insertNovel(title: '凡人修仙传');
      await insertChapter();

      final result = await executor.execute(
        'list_chapters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['novel'], isA<Map>());
      expect((json['novel'] as Map)['title'], '凡人修仙传');
      expect((json['novel'] as Map)['id'], novelId);
    });

    test('每个章节返回 id 字段', () async {
      final novelId = await insertNovel();
      await insertChapter(chapterUrl: 'ch1', title: '第一章');
      await insertChapter(chapterUrl: 'ch2', title: '第二章');

      final result = await executor.execute(
        'list_chapters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      final chapters = json['chapters'] as List;
      for (final ch in chapters) {
        expect(ch['id'], isA<int>());
      }
    });

    test('返回结果中不含 url 字段', () async {
      final novelId = await insertNovel();
      await insertChapter();
      final result = await executor.execute(
        'list_chapters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      final ch = (json['chapters'] as List).first;
      expect(ch.containsKey('url'), false);
    });

    test('小说不存在 → 返回 novel_not_found + suggested_tool', () async {
      final result = await executor.execute(
        'list_chapters',
        {'novelId': 99999},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], 'novel_not_found');
      expect(json['suggested_tool'], 'list_novels');
    });

    test('无章节返回空列表', () async {
      final novelId = await insertNovel();
      final result = await executor.execute(
        'list_chapters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['count'], 0);
      expect((json['chapters'] as List).isEmpty, true);
    });
  });

  // ========================================================================
  // search_in_chapters
  // ========================================================================
  group('search_in_chapters', () {
    test('搜索到关键词返回匹配', () async {
      final novelId = await insertNovel();
      await insertChapter(content: '剑客走在路上');

      final result = await executor.execute(
        'search_in_chapters',
        {'novelId': novelId, 'keyword': '剑客'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['count'], greaterThanOrEqualTo(1));
      final results = json['results'] as List;
      expect(results.first['matchedText'].toString(), contains('剑客'));
    });

    test('搜索结果含 chapterId 字段（无 url）', () async {
      final novelId = await insertNovel();
      await insertChapter(content: '剑客走在路上');

      final result = await executor.execute(
        'search_in_chapters',
        {'novelId': novelId, 'keyword': '剑客'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      final results = json['results'] as List;
      expect(results.first['chapterId'], isA<int>());
      expect(results.first.containsKey('chapterUrl'), false);
    });

    test('搜索结果包含 novel 上下文', () async {
      final novelId = await insertNovel(title: '凡人修仙传');
      await insertChapter(content: '剑客');

      final result = await executor.execute(
        'search_in_chapters',
        {'novelId': novelId, 'keyword': '剑客'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect((json['novel'] as Map)['title'], '凡人修仙传');
    });

    test('搜不到关键词返回空', () async {
      final novelId = await insertNovel();
      await insertChapter(content: '内容');

      final result = await executor.execute(
        'search_in_chapters',
        {'novelId': novelId, 'keyword': '不存在'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['count'], 0);
    });
  });

  // ========================================================================
  // update_chapter_content
  // ========================================================================
  group('update_chapter_content', () {
    test('更新章节内容后可读取', () async {
      await insertNovel();
      final chId = await insertChapter(content: '旧内容');

      final result = await executor.execute(
        'update_chapter_content',
        {'chapterId': chId, 'content': '新内容'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['success'], true);

      final chapter = await chapterRepo.getChapterById(chId);
      expect(chapter!.content, '新内容');
    });

    test('章节不存在 → chapter_not_found + suggested_tool', () async {
      final result = await executor.execute(
        'update_chapter_content',
        {'chapterId': 99999, 'content': '新内容'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], 'chapter_not_found');
      expect(json['suggested_tool'], 'list_chapters');
    });
  });

  // ========================================================================
  // create_custom_chapter
  // ========================================================================
  group('create_custom_chapter', () {
    test('创建自定义章节（不带 index）', () async {
      final novelId = await insertNovel();

      final result = await executor.execute(
        'create_custom_chapter',
        {'novelId': novelId, 'title': '新章节', 'content': '新内容'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['success'], true);
      expect(json['chapterId'], isA<int>());
      expect(json['chapterId'], greaterThan(0));

      // 验证数据库
      final chapters = await chapterRepo.getCachedNovelChapters(
        'https://example.com/novel1',
      );
      expect(chapters.any((c) => c.title == '新章节'), true);
    });

    test('创建自定义章节（带 index）', () async {
      final novelId = await insertNovel();

      final result = await executor.execute(
        'create_custom_chapter',
        {
          'novelId': novelId,
          'title': '插入章节',
          'content': '插入内容',
          'index': 5,
        },
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['success'], true);
    });

    test('小说不存在 → novel_not_found + suggested_tool', () async {
      final result = await executor.execute(
        'create_custom_chapter',
        {'novelId': 99999, 'title': 'X', 'content': 'Y'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], 'novel_not_found');
      expect(json['suggested_tool'], 'list_novels');
    });
  });

  // ========================================================================
  // list_characters
  // ========================================================================
  group('list_characters', () {
    test('返回角色列表', () async {
      final novelId = await insertNovel();
      await insertCharacter(name: '李云');

      final result = await executor.execute(
        'list_characters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['count'], 1);
      expect((json['characters'] as List)[0]['name'], '李云');
    });

    test('返回结果包含 novel 上下文', () async {
      final novelId = await insertNovel(title: '凡人修仙传');
      await insertCharacter();

      final result = await executor.execute(
        'list_characters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect((json['novel'] as Map)['title'], '凡人修仙传');
    });

    test('无角色返回空列表', () async {
      final novelId = await insertNovel();
      final result = await executor.execute(
        'list_characters',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['count'], 0);
    });
  });

  // ========================================================================
  // update_character
  // ========================================================================
  group('update_character', () {
    test('更新已有角色', () async {
      final novelId = await insertNovel();
      await insertCharacter(name: '李云');

      final result = await executor.execute(
        'update_character',
        {'novelId': novelId, 'name': '李云', 'description': '新描述'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['success'], true);

      final updated = await characterRepo.findCharacterByName(
        'https://example.com/novel1',
        '李云',
      );
      expect(updated!.appearanceFeatures, '新描述');
    });

    test('角色不存在 → character_not_found + suggested_tool', () async {
      final novelId = await insertNovel();
      final result = await executor.execute(
        'update_character',
        {'novelId': novelId, 'name': '不存在'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], 'character_not_found');
      expect(json['suggested_tool'], 'list_characters');
      expect(json['suggested_args'], {'novelId': novelId});
    });
  });

  // ========================================================================
  // create_character
  // ========================================================================
  group('create_character', () {
    test('创建新角色', () async {
      final novelId = await insertNovel();

      final result = await executor.execute(
        'create_character',
        {'novelId': novelId, 'name': '张三', 'description': '侠客'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['success'], true);
      expect(json['characterId'], isA<int>());

      final created = await characterRepo.findCharacterByName(
        'https://example.com/novel1',
        '张三',
      );
      expect(created, isNotNull);
      expect(created!.appearanceFeatures, '侠客');
    });

    test('角色已存在 → duplicate 错误', () async {
      final novelId = await insertNovel();
      await insertCharacter(name: '李云');

      final result = await executor.execute(
        'create_character',
        {'novelId': novelId, 'name': '李云'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], 'duplicate');
      expect(json['message'].toString(), contains('update_character'));
    });

    test('小说不存在 → novel_not_found + suggested_tool', () async {
      final result = await executor.execute(
        'create_character',
        {'novelId': 99999, 'name': 'X'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], 'novel_not_found');
      expect(json['suggested_tool'], 'list_novels');
    });
  });

  // ========================================================================
  // update_background_setting
  // ========================================================================
  group('update_background_setting', () {
    test('更新背景设定后可读取', () async {
      final novelId = await insertNovel();

      final result = await executor.execute(
        'update_background_setting',
        {'novelId': novelId, 'setting': '武侠世界'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['success'], true);

      final setting = await novelRepo.getBackgroundSetting(
        'https://example.com/novel1',
      );
      expect(setting, '武侠世界');
    });

    test('小说不存在 → novel_not_found', () async {
      final result = await executor.execute(
        'update_background_setting',
        {'novelId': 99999, 'setting': 'X'},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], 'novel_not_found');
    });
  });

  // ========================================================================
  // update_outline
  // ========================================================================
  group('update_outline', () {
    test('保存大纲后可读取', () async {
      final novelId = await insertNovel();

      final result = await executor.execute(
        'update_outline',
        {
          'novelId': novelId,
          'title': '全书大纲',
          'content': '第一幕\n第二幕',
        },
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['success'], true);

      final outline = await outlineRepo.getOutlineByNovelUrl(
        'https://example.com/novel1',
      );
      expect(outline, isNotNull);
      expect(outline!.title, '全书大纲');
      expect(outline.content, '第一幕\n第二幕');
    });
  });

  // ========================================================================
  // get_outline
  // ========================================================================
  group('get_outline', () {
    test('返回大纲（含 novel 上下文）', () async {
      final novelId = await insertNovel(title: '凡人修仙传');
      await insertOutline(title: '大纲', content: '内容');

      final result = await executor.execute(
        'get_outline',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['title'], '大纲');
      expect(json['content'], '内容');
      expect((json['novel'] as Map)['title'], '凡人修仙传');
    });

    test('大纲不存在 → not_found', () async {
      final novelId = await insertNovel();
      final result = await executor.execute(
        'get_outline',
        {'novelId': novelId},
      );
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], 'not_found');
    });
  });

  // ========================================================================
  // 端到端
  // ========================================================================
  group('端到端流程', () {
    test('list_novels → list_chapters → read_chapter_content 链路', () async {
      // 准备
      final novelUrl = 'https://example.com/chain-test';
      final novel = Novel(
        title: '链路测试',
        author: '作者',
        url: novelUrl,
      );
      await novelRepo.addToBookshelf(novel);
      final novelId = (await novelRepo.getNovels())
          .firstWhere((n) => n.url == novelUrl)
          .id!;

      final chapter = Chapter(
        title: '首章',
        url: '$novelUrl/ch1',
        chapterIndex: 0,
        isCached: true,
      );
      await chapterRepo.cacheChapter(novelUrl, chapter, '首章内容');
      await chapterRepo.cacheNovelChapters(novelUrl, [chapter]);
      final chapterId = (await chapterRepo.getCachedNovelChapters(novelUrl))
          .firstWhere((c) => c.url == '$novelUrl/ch1')
          .id!;

      // 1. list_novels
      final r1 = jsonDecode(
        await executor.execute('list_novels', {}),
      ) as Map<String, dynamic>;
      final listNovel = (r1['novels'] as List).firstWhere(
        (n) => n['title'] == '链路测试',
      );
      expect(listNovel['id'], novelId);

      // 2. list_chapters
      final r2 = jsonDecode(
        await executor.execute('list_chapters', {'novelId': novelId}),
      ) as Map<String, dynamic>;
      expect((r2['novel'] as Map)['title'], '链路测试');
      final chList = (r2['chapters'] as List);
      expect(chList.first['id'], chapterId);

      // 3. read_chapter_content
      final r3 = await executor.execute(
        'read_chapter_content',
        {'chapterId': chapterId},
      );
      expect(r3, '首章内容');
    });
  });

  // ========================================================================
  // 错误处理
  // ========================================================================
  group('错误处理', () {
    test('未知工具 → unknown_tool 错误', () async {
      final result = await executor.execute('unknown_tool', {});
      final json = jsonDecode(result) as Map<String, dynamic>;

      expect(json['error'], 'unknown_tool');
      expect(json['message'].toString(), contains('unknown_tool'));
    });
  });

  // ========================================================================
  // isDestructive
  // ========================================================================
  group('isDestructive', () {
    test('破坏性工具 (6个)', () {
      for (final name in [
        'update_chapter_content',
        'create_custom_chapter',
        'update_character',
        'create_character',
        'update_background_setting',
        'update_outline',
      ]) {
        expect(executor.isDestructive(name), true, reason: '$name');
      }
    });

    test('非破坏性工具 (6个)', () {
      for (final name in [
        'list_novels',
        'read_chapter_content',
        'list_chapters',
        'search_in_chapters',
        'list_characters',
        'get_outline',
      ]) {
        expect(executor.isDestructive(name), false, reason: '$name');
      }
    });
  });
}
