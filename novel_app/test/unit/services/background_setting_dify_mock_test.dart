import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/repositories/chapter_repository.dart';
import 'package:novel_app/repositories/character_repository.dart';
import 'package:novel_app/services/chapter_service.dart';
import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/core/interfaces/repositories/i_novel_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_chapter_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_character_repository.dart';

import '../../helpers/test_database_setup.dart';

/// ChapterService - buildChapterGenerationInputs 背景设定传递测试（Mock版本）
///
/// 测试 ChapterService.buildChapterGenerationInputs 方法是否正确传递背景设定给 Dify
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'ai_writer_prompt': ''});
  TestDatabaseSetup.init();

  late INovelRepository novelRepository;
  late IChapterRepository chapterRepository;
  late ICharacterRepository characterRepository;
  late ChapterService chapterService;

  setUpAll(() async {
    TestDatabaseSetup.init();
  });

  setUp(() async {
    final db = await TestDatabaseSetup.createInMemoryDatabase();
    final connection = DatabaseConnection.forTesting(db);

    novelRepository = NovelRepository(dbConnection: connection);
    chapterRepository = ChapterRepository(dbConnection: connection);
    characterRepository = CharacterRepository(dbConnection: connection);

    chapterService = ChapterService(
      chapterRepository: chapterRepository,
      characterRepository: characterRepository,
    );
  });

  group('buildChapterGenerationInputs - 背景设定传递测试（Mock环境）', () {
    test('background_setting 为 null 时 - 应该传递空字符串', () async {
      final novelWithNullBackground = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/test',
        backgroundSetting: null,
      );

      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithNullBackground,
        chapters: [],
        afterIndex: -1,
        userInput: '请生成内容',
        characterIds: [],
      );

      expect(inputs['background_setting'], '');
    });

    test('afterIndex 为负数 - 应该正常工作', () async {
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/test',
        backgroundSetting: '测试背景设定',
      );

      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: [],
        afterIndex: -1,
        userInput: '请生成第一章内容',
        characterIds: [],
      );

      expect(inputs, containsPair('background_setting', '测试背景设定'));
    });

    test('超长背景设定 - 应该正确传递', () async {
      final longBackgroundSetting = '背景设定' * 10000;
      final novelWithLongBackground = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/test',
        backgroundSetting: longBackgroundSetting,
      );

      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithLongBackground,
        chapters: [],
        afterIndex: -1,
        userInput: '请生成内容',
        characterIds: [],
      );

      expect(inputs['background_setting'], longBackgroundSetting);
      expect(inputs['background_setting']!.length, 40000);
    });
  });
}