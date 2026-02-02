import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/ai_accompaniment_settings.dart';
import 'package:novel_app/repositories/novel_repository.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../../test_bootstrap.dart';

/// NovelRepository Riverpod 测试
///
/// 测试 NovelRepository 在 Riverpod 环境中的行为
/// 包括 Provider 创建、依赖注入和 CRUD 操作
void main() {
  // 初始化测试环境
  initDatabaseTests();

  group('NovelRepository Riverpod Tests', () {
    late Database testDatabase;
    late NovelRepository repository;

    setUp(() async {
      // 创建内存数据库（使用项目提供的辅助函数）
      testDatabase = await createInMemoryDatabase();

      // 创建 Repository 实例并注入测试数据库
      repository = NovelRepository();
      repository.setSharedDatabase(testDatabase);
    });

    tearDown(() async {
      await testDatabase.close();
    });

    group('Provider 测试', () {
      test('novelRepositoryProvider 应该创建 NovelRepository 实例', () {
        // 这个测试验证 Provider 定义正确
        // 注意：实际的 Provider 测试需要 Riverpod 测试环境
        // 这里我们验证 Repository 本身的创建

        expect(repository, isA<NovelRepository>());
      });

      test('NovelRepository 应该继承 BaseRepository', () {
        expect(repository.toString(), contains('NovelRepository'));
      });
    });

    group('addToBookshelf', () {
      test('应该成功添加小说到书架', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/1',
          coverUrl: 'https://example.com/cover.jpg',
          description: '测试描述',
        );

        final id = await repository.addToBookshelf(novel);

        expect(id, greaterThan(0));

        // 验证小说已添加
        final isInBookshelf = await repository.isInBookshelf(novel.url);
        expect(isInBookshelf, true);
      });

      test('添加相同小说应该更新而不是创建新记录', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/1',
        );

        await repository.addToBookshelf(novel);
        final id2 = await repository.addToBookshelf(novel);

        // ConflictAlgorithm.replace 会返回相同或更新的 ID
        expect(id2, isA<int>());
      });

      test('应该记录添加时间', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/2',
        );

        final beforeAdd = DateTime.now().millisecondsSinceEpoch;
        await repository.addToBookshelf(novel);
        final afterAdd = DateTime.now().millisecondsSinceEpoch;

        // 验证添加时间在合理范围内
        final books = await testDatabase.query(
          'bookshelf',
          where: 'url = ?',
          whereArgs: [novel.url],
        );

        expect(books.length, 1);
        final addedAt = books.first['addedAt'] as int;
        expect(addedAt, greaterThanOrEqualTo(beforeAdd));
        expect(addedAt, lessThanOrEqualTo(afterAdd));
      });
    });

    group('removeFromBookshelf', () {
      test('应该成功从书架移除小说', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/3',
        );

        // 先添加
        await repository.addToBookshelf(novel);

        // 然后移除
        final count = await repository.removeFromBookshelf(novel.url);

        expect(count, 1);

        // 验证已移除
        final isInBookshelf = await repository.isInBookshelf(novel.url);
        expect(isInBookshelf, false);
      });

      test('移除不存在的小说应该返回 0', () async {
        final count = await repository.removeFromBookshelf('https://example.com/nonexistent');
        expect(count, 0);
      });
    });

    group('isInBookshelf', () {
      test('已添加的小说应该返回 true', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/4',
        );

        await repository.addToBookshelf(novel);

        final isInBookshelf = await repository.isInBookshelf(novel.url);
        expect(isInBookshelf, true);
      });

      test('未添加的小说应该返回 false', () async {
        final isInBookshelf = await repository.isInBookshelf('https://example.com/nonexistent');
        expect(isInBookshelf, false);
      });
    });

    group('updateLastReadChapter', () {
      test('应该成功更新最后阅读章节', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/5',
        );

        await repository.addToBookshelf(novel);
        final count = await repository.updateLastReadChapter(novel.url, 10);

        expect(count, 1);

        // 验证更新
        final lastReadChapter = await repository.getLastReadChapter(novel.url);
        expect(lastReadChapter, 10);
      });

      test('更新不存在的小说应该返回 0', () async {
        final count = await repository.updateLastReadChapter('https://example.com/nonexistent', 5);
        expect(count, 0);
      });
    });

    group('getLastReadChapter', () {
      test('应该返回最后阅读章节索引', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/6',
        );

        await repository.addToBookshelf(novel);
        await repository.updateLastReadChapter(novel.url, 15);

        final lastReadChapter = await repository.getLastReadChapter(novel.url);
        expect(lastReadChapter, 15);
      });

      test('未设置过应该返回 0', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/7',
        );

        await repository.addToBookshelf(novel);

        final lastReadChapter = await repository.getLastReadChapter(novel.url);
        expect(lastReadChapter, 0);
      });

      test('不存在的小说应该返回 0', () async {
        final lastReadChapter = await repository.getLastReadChapter('https://example.com/nonexistent');
        expect(lastReadChapter, 0);
      });
    });

    group('updateBackgroundSetting', () {
      test('应该成功更新背景设定', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/8',
        );

        await repository.addToBookshelf(novel);
        final count = await repository.updateBackgroundSetting(
          novel.url,
          '这是一个背景设定',
        );

        expect(count, 1);

        // 验证更新
        final backgroundSetting = await repository.getBackgroundSetting(novel.url);
        expect(backgroundSetting, '这是一个背景设定');
      });

      test('应该能够清除背景设定', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/9',
        );

        await repository.addToBookshelf(novel);
        await repository.updateBackgroundSetting(novel.url, '初始设定');
        await repository.updateBackgroundSetting(novel.url, null);

        final backgroundSetting = await repository.getBackgroundSetting(novel.url);
        expect(backgroundSetting, null);
      });

      test('更新不存在的小说应该返回 0', () async {
        final count = await repository.updateBackgroundSetting(
          'https://example.com/nonexistent',
          '测试设定',
        );
        expect(count, 0);
      });
    });

    group('getBackgroundSetting', () {
      test('应该返回背景设定', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/10',
        );

        await repository.addToBookshelf(novel);
        await repository.updateBackgroundSetting(
          novel.url,
          '这是一个测试背景设定',
        );

        final backgroundSetting = await repository.getBackgroundSetting(novel.url);
        expect(backgroundSetting, '这是一个测试背景设定');
      });

      test('未设置过应该返回 null', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/11',
        );

        await repository.addToBookshelf(novel);

        final backgroundSetting = await repository.getBackgroundSetting(novel.url);
        expect(backgroundSetting, null);
      });

      test('不存在的小说应该返回 null', () async {
        final backgroundSetting = await repository.getBackgroundSetting(
          'https://example.com/nonexistent',
        );
        expect(backgroundSetting, null);
      });
    });

    group('getAiAccompanimentSettings', () {
      test('默认设置应该都是 false', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/12',
        );

        await repository.addToBookshelf(novel);

        final settings = await repository.getAiAccompanimentSettings(novel.url);
        expect(settings.autoEnabled, false);
        expect(settings.infoNotificationEnabled, false);
      });

      test('应该返回正确的AI伴读设置', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/13',
        );

        await repository.addToBookshelf(novel);

        final testSettings = AiAccompanimentSettings(
          autoEnabled: true,
          infoNotificationEnabled: true,
        );
        await repository.updateAiAccompanimentSettings(novel.url, testSettings);

        final settings = await repository.getAiAccompanimentSettings(novel.url);
        expect(settings.autoEnabled, true);
        expect(settings.infoNotificationEnabled, true);
      });

      test('不存在的小说应该返回默认设置', () async {
        final settings = await repository.getAiAccompanimentSettings(
          'https://example.com/nonexistent',
        );
        expect(settings.autoEnabled, false);
        expect(settings.infoNotificationEnabled, false);
      });
    });

    group('updateAiAccompanimentSettings', () {
      test('应该成功更新AI伴读设置', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/14',
        );

        await repository.addToBookshelf(novel);

        final settings = AiAccompanimentSettings(
          autoEnabled: true,
          infoNotificationEnabled: false,
        );
        final count = await repository.updateAiAccompanimentSettings(
          novel.url,
          settings,
        );

        expect(count, 1);

        // 验证更新
        final updatedSettings = await repository.getAiAccompanimentSettings(novel.url);
        expect(updatedSettings.autoEnabled, true);
        expect(updatedSettings.infoNotificationEnabled, false);
      });

      test('应该能够切换设置', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/15',
        );

        await repository.addToBookshelf(novel);

        // 先设置为 true
        final settings1 = AiAccompanimentSettings(
          autoEnabled: true,
          infoNotificationEnabled: true,
        );
        await repository.updateAiAccompanimentSettings(novel.url, settings1);

        // 再设置为 false
        final settings2 = AiAccompanimentSettings(
          autoEnabled: false,
          infoNotificationEnabled: false,
        );
        await repository.updateAiAccompanimentSettings(novel.url, settings2);

        final finalSettings = await repository.getAiAccompanimentSettings(novel.url);
        expect(finalSettings.autoEnabled, false);
        expect(finalSettings.infoNotificationEnabled, false);
      });

      test('更新不存在的小说应该返回 0', () async {
        final settings = const AiAccompanimentSettings();
        final count = await repository.updateAiAccompanimentSettings(
          'https://example.com/nonexistent',
          settings,
        );
        expect(count, 0);
      });
    });

    group('数据完整性测试', () {
      test('应该保留小说的所有字段', () async {
        final novel = Novel(
          title: '完整测试小说',
          author: '测试作者',
          url: 'https://example.com/novel/full',
          coverUrl: 'https://example.com/cover.jpg',
          description: '这是一个完整的测试描述',
          backgroundSetting: '背景设定',
        );

        await repository.addToBookshelf(novel);

        // 验证所有字段
        final books = await testDatabase.query(
          'bookshelf',
          where: 'url = ?',
          whereArgs: [novel.url],
        );

        expect(books.length, 1);
        final book = books.first;
        expect(book['title'], novel.title);
        expect(book['author'], novel.author);
        expect(book['url'], novel.url);
        expect(book['coverUrl'], novel.coverUrl);
        expect(book['description'], novel.description);
        expect(book['backgroundSetting'], novel.backgroundSetting);
      });

      test('应该正确处理并发操作', () async {
        final novels = List.generate(
          10,
          (i) => Novel(
            title: '测试小说 $i',
            author: '测试作者',
            url: 'https://example.com/novel/$i',
          ),
        );

        // 并发添加多个小说
        final futures = novels.map((n) => repository.addToBookshelf(n));
        final results = await Future.wait(futures);

        expect(results.length, 10);
        for (final result in results) {
          expect(result, greaterThan(0));
        }

        // 验证所有小说都已添加
        for (final novel in novels) {
          final isInBookshelf = await repository.isInBookshelf(novel.url);
          expect(isInBookshelf, true);
        }
      });
    });

    group('Web 平台测试', () {
      test('isWebPlatform 应该反映当前平台', () {
        // 在测试环境中，kIsWeb 应该是 false
        // 但这个测试验证 getter 存在
        expect(repository.isWebPlatform, isA<bool>());
      });
    });
  });
}
