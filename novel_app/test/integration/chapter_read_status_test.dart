import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/controllers/chapter_list/bookshelf_manager.dart';
import '../test_bootstrap.dart';

void main() {
  // 初始化测试环境
  initDatabaseTests();
  group('章节已读标记集成测试', () {
    late DatabaseService databaseService;
    late BookshelfManager bookshelfManager;
    late String testNovelUrl;

    setUp(() async {
      databaseService = DatabaseService();
      bookshelfManager = BookshelfManager(
        databaseService: databaseService,
      );

      // 创建测试小说
      final novel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel/read_test_${DateTime.now().millisecondsSinceEpoch}',
        coverUrl: '',
        description: '测试描述',
      );

      // 添加到书架
      await bookshelfManager.addToBookshelf(novel);
      testNovelUrl = novel.url;

      // 添加测试章节
      final chapters = [
        Chapter(
          title: '第一章 未读章节',
          url: '$testNovelUrl/chapter1',
          content: '第一章内容',
          chapterIndex: 0,
        ),
        Chapter(
          title: '第二章 待阅读章节',
          url: '$testNovelUrl/chapter2',
          content: '第二章内容',
          chapterIndex: 1,
        ),
        Chapter(
          title: '第三章 已读章节',
          url: '$testNovelUrl/chapter3',
          content: '第三章内容',
          chapterIndex: 2,
        ),
      ];

      // 保存章节到数据库
      final db = await databaseService.database;
      for (final chapter in chapters) {
        try {
          await db.insert(
            'novel_chapters',
            {
              'novelUrl': testNovelUrl,
              'chapterUrl': chapter.url,
              'title': chapter.title,
              'chapterIndex': chapter.chapterIndex,
              'isUserInserted': chapter.isUserInserted ? 1 : 0,
              'isAccompanied': chapter.isAccompanied ? 1 : 0,
            },
          );
        } catch (e) {
          // 忽略重复插入错误
        }
      }
    });

    tearDown(() async {
      // 清理测试数据
      try {
        final db = await databaseService.database;
        await db.delete(
          'novel_chapters',
          where: 'novelUrl = ?',
          whereArgs: [testNovelUrl],
        );
        await db.delete(
          'bookshelf',
          where: 'novelUrl = ?',
          whereArgs: [testNovelUrl],
        );
      } catch (e) {
        // 忽略清理错误
      }
    });

    test('章节初始状态应该为未读', () async {
      // 获取章节列表
      final chapters = await databaseService.getChapters(testNovelUrl);

      expect(chapters.length, 3, reason: '应该有3个测试章节');

      for (final chapter in chapters) {
        expect(
          chapter.isRead,
          false,
          reason: '${chapter.title} 初始应该是未读状态',
        );
        expect(
          chapter.readAt,
          isNull,
          reason: '${chapter.title} 的 readAt 初始应该为 null',
        );
      }

      print('✅ 所有 ${chapters.length} 个章节初始状态都是未读');
    });

    test('标记章节为已读后应该正确更新状态', () async {
      // 获取章节列表
      final chapters = await databaseService.getChapters(testNovelUrl);
      final firstChapter = chapters.first;

      print('📖 标记章节为已读: ${firstChapter.title}');

      // 验证初始状态
      expect(firstChapter.isRead, false);
      expect(firstChapter.readAt, isNull);

      // 标记为已读
      await databaseService.markChapterAsRead(testNovelUrl, firstChapter.url);

      // 重新获取章节
      final updatedChapters = await databaseService.getChapters(testNovelUrl);
      final updatedChapter = updatedChapters.firstWhere(
        (c) => c.url == firstChapter.url,
      );

      // 验证已读状态
      expect(
        updatedChapter.isRead,
        true,
        reason: '章节应该被标记为已读',
      );
      expect(
        updatedChapter.readAt,
        isNotNull,
        reason: 'readAt 应该有值',
      );
      expect(
        updatedChapter.readAt!,
        greaterThan(0),
        reason: 'readAt 应该是有效的时间戳',
      );

      final readTime = DateTime.fromMillisecondsSinceEpoch(
        updatedChapter.readAt! * 1000,
      );
      print('✅ 章节 "${updatedChapter.title}" 成功标记为已读');
      print('   readAt: $readTime');
    });

    test('标记多个章节为已读应该各自独立', () async {
      // 获取章节列表
      final chapters = await databaseService.getChapters(testNovelUrl);

      print('📖 标记多个章节为已读...');

      // 标记前两个章节为已读
      await databaseService.markChapterAsRead(testNovelUrl, chapters[0].url);
      await databaseService.markChapterAsRead(testNovelUrl, chapters[1].url);

      // 重新获取章节
      final updatedChapters = await databaseService.getChapters(testNovelUrl);

      // 验证：前两个已读，第三个未读
      expect(
        updatedChapters[0].isRead,
        true,
        reason: '第一章应该已读',
      );
      expect(
        updatedChapters[1].isRead,
        true,
        reason: '第二章应该已读',
      );
      expect(
        updatedChapters[2].isRead,
        false,
        reason: '第三章应该未读',
      );

      print('✅ 多个章节的已读状态独立工作正常');
      print('   已读: ${updatedChapters[0].title}, ${updatedChapters[1].title}');
      print('   未读: ${updatedChapters[2].title}');
    });

    test('重复标记已读章节应该更新时间戳', () async {
      // 获取章节列表
      final chapters = await databaseService.getChapters(testNovelUrl);
      final firstChapter = chapters.first;

      print('📖 测试重复标记已读...');

      // 第一次标记
      await databaseService.markChapterAsRead(testNovelUrl, firstChapter.url);
      final firstRead = await databaseService.getChapters(testNovelUrl);
      final firstReadTime = firstRead.first.readAt;

      print('   第一次标记时间: ${DateTime.fromMillisecondsSinceEpoch(firstReadTime! * 1000)}');

      // 等待一小段时间（确保时间戳不同）
      await Future.delayed(const Duration(milliseconds: 100));

      // 第二次标记（重复操作）
      await databaseService.markChapterAsRead(testNovelUrl, firstChapter.url);
      final secondRead = await databaseService.getChapters(testNovelUrl);
      final secondReadTime = secondRead.first.readAt;

      print('   第二次标记时间: ${DateTime.fromMillisecondsSinceEpoch(secondReadTime! * 1000)}');

      // 验证：仍然已读，但时间戳已更新
      expect(secondRead.first.isRead, true);
      expect(secondReadTime, isNotNull);
      expect(
        secondReadTime!,
        greaterThan(firstReadTime!),
        reason: '重复标记应该更新 readAt 时间戳',
      );

      print('✅ 重复标记已读章节正常工作，时间戳已更新');
    });

    test('获取章节列表时应正确返回已读状态', () async {
      // 获取章节列表
      final chapters = await databaseService.getChapters(testNovelUrl);

      print('📖 标记中间章节为已读...');

      // 标记中间章节为已读
      await databaseService.markChapterAsRead(testNovelUrl, chapters[1].url);

      // 重新获取章节列表
      final updatedChapters = await databaseService.getChapters(testNovelUrl);

      // 验证每个章节的状态
      expect(
        updatedChapters[0].isRead,
        false,
        reason: '第一章应该未读',
      );
      expect(
        updatedChapters[1].isRead,
        true,
        reason: '第二章应该已读',
      );
      expect(
        updatedChapters[2].isRead,
        false,
        reason: '第三章应该未读',
      );

      // 验证 Chapter 模型的 isRead getter
      for (final chapter in updatedChapters) {
        final expectedIsRead = chapter.readAt != null;
        expect(
          chapter.isRead,
          expectedIsRead,
          reason: 'Chapter.isRead getter 应该正确反映 readAt 状态',
        );
      }

      print('✅ 章节列表正确返回已读状态');
      for (final chapter in updatedChapters) {
        final status = chapter.isRead ? '已读' : '未读';
        print(
          '   ${chapter.title}: $status ${chapter.readAt != null ? '(readAt=${chapter.readAt})' : ''}',
        );
      }
    });

    test('已读章节在ChapterTitle中应该正确显示', () async {
      // 获取章节列表
      final chapters = await databaseService.getChapters(testNovelUrl);

      // 标记第一个章节为已读
      await databaseService.markChapterAsRead(testNovelUrl, chapters[0].url);

      // 重新获取章节
      final updatedChapters = await databaseService.getChapters(testNovelUrl);

      // 验证：已读章节的 isRead 属性应该为 true
      final readChapter = updatedChapters[0];
      expect(
        readChapter.isRead,
        true,
        reason: '已读章节的 isRead 属性应该为 true',
      );

      // 验证：在 ChapterTitle 组件中使用时会显示为灰色
      // （这里只验证数据，UI渲染在 widget 测试中验证）
      print('✅ 已读章节数据验证通过');
      print('   ${readChapter.title}: isRead=${readChapter.isRead}, readAt=${readChapter.readAt}');
      print('   提示: 在 ChapterTitle 组件中，isRead=true 会显示为灰色');
    });

    test('getCachedNovelChapters应该正确返回readAt字段', () async {
      // 准备测试数据
      final chapters = await databaseService.getChapters(testNovelUrl);
      expect(chapters.length, greaterThan(0), reason: '应该有测试章节');

      // 标记第一个章节为已读
      final chapterToMark = chapters[0];
      await databaseService.markChapterAsRead(testNovelUrl, chapterToMark.url);

      // 使用 getCachedNovelChapters 获取章节列表
      final cachedChapters = await databaseService.getCachedNovelChapters(testNovelUrl);

      // 验证：readAt 字段应该被正确读取
      expect(cachedChapters.length, greaterThan(0), reason: '应该返回章节列表');
      expect(cachedChapters[0].readAt, isNotNull,
        reason: 'readAt字段应该被正确读取，不应该为null');
      expect(cachedChapters[0].readAt, greaterThan(0),
        reason: 'readAt应该是有效的时间戳');

      // 验证：isRead 计算属性应该正确工作
      expect(cachedChapters[0].isRead, true,
        reason: 'isRead应该基于readAt正确计算为true');

      debugPrint('✅ getCachedNovelChapters readAt验证通过');
      debugPrint('   章节: ${cachedChapters[0].title}');
      debugPrint('   readAt: ${DateTime.fromMillisecondsSinceEpoch(cachedChapters[0].readAt!)}');
      debugPrint('   isRead: ${cachedChapters[0].isRead}');
    });

    test('getCachedNovelChapters和getChapters应该返回一致的readAt', () async {
      // 准备测试数据：标记多个章节为已读
      final chapters = await databaseService.getChapters(testNovelUrl);
      await databaseService.markChapterAsRead(testNovelUrl, chapters[0].url);
      await databaseService.markChapterAsRead(testNovelUrl, chapters[1].url);

      // 使用两种方法获取章节列表
      final chaptersFromGet = await databaseService.getChapters(testNovelUrl);
      final chaptersFromCached = await databaseService.getCachedNovelChapters(testNovelUrl);

      // 验证：两个方法返回的章节数量应该一致
      expect(chaptersFromGet.length, chaptersFromCached.length,
        reason: '两个方法应该返回相同数量的章节');

      // 验证：每个章节的 readAt 值应该一致
      for (var i = 0; i < chaptersFromGet.length; i++) {
        expect(chaptersFromGet[i].readAt, chaptersFromCached[i].readAt,
          reason: '第${i+1}个章节的readAt在两个方法中应该一致: ${chaptersFromGet[i].title}');
        expect(chaptersFromGet[i].isRead, chaptersFromCached[i].isRead,
          reason: '第${i+1}个章节的isRead在两个方法中应该一致: ${chaptersFromGet[i].title}');
      }

      debugPrint('✅ 两个方法的数据一致性验证通过');
      debugPrint('   getChapters: ${chaptersFromGet.length}个章节');
      debugPrint('   getCachedNovelChapters: ${chaptersFromCached.length}个章节');
      debugPrint('   readAt字段: 全部一致');
    });

    test('getCachedNovelChapters应该包含content字段', () async {
      // 验证 getCachedNovelChapters 的特殊功能：包含内容
      final chapters = await databaseService.getCachedNovelChapters(testNovelUrl);

      expect(chapters.length, greaterThan(0), reason: '应该返回章节列表');

      // 验证内容字段存在（但可能为空字符串）
      expect(chapters[0].content, isNotNull,
        reason: 'getCachedNovelChapters应该包含content字段');

      debugPrint('✅ getCachedNovelChapters content字段验证通过');
      debugPrint('   章节: ${chapters[0].title}');
      debugPrint('   内容长度: ${chapters[0].content!.length}字符');
    });
  });
}
