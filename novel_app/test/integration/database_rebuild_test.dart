import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'dart:io';
import '../test_bootstrap.dart';
import '../base/database_test_base.dart';

void main() {
  // 初始化测试环境
  initDatabaseTests();

  group('数据库重建测试', () {
    late DatabaseTestBase testBase;
    late DatabaseService dbService;

    setUp(() async {
      testBase = DatabaseTestBase();
      await testBase.setUp();
      dbService = testBase.databaseService;
    });

    tearDown(() async {
      await testBase.tearDown();
    });

    test('应该能够重建数据库并包含完整的Schema', () async {
      print('🔍 步骤1: 初始化数据库服务');
      final db = await dbService.database;
      expect(db.isOpen, true);

      print('🔍 步骤3: 检查数据库版本');
      final result = await db.rawQuery('PRAGMA user_version');
      final version = result.first['user_version'] as int;
      print('   当前数据库版本: $version');
      expect(version, equals(21), reason: '数据库版本应该是21');

      print('🔍 步骤4: 检查 novel_chapters 表结构');
      final columns = await db.rawQuery('PRAGMA table_info(novel_chapters)');
      final columnNames = columns.map((row) => row['name'] as String).toList();

      print('   当前字段: $columnNames');

      // 验证关键字段
      expect(columnNames, contains('readAt'), reason: '应该包含 readAt 字段');
      expect(columnNames, contains('isUserInserted'), reason: '应该包含 isUserInserted 字段');
      expect(columnNames, contains('isAccompanied'), reason: '应该包含 isAccompanied 字段');

      print('✅ Schema 验证通过，所有关键字段都存在');
    });

    test('标记章节为已读应该成功', () async {
      print('🔍 步骤1: 创建测试小说');
      final novel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel/rebuild_${DateTime.now().millisecondsSinceEpoch}',
        coverUrl: '',
        description: '测试',
      );

      await dbService.addToBookshelf(novel);
      print('   小说已添加到书架');

      print('🔍 步骤2: 添加测试章节');
      final db = await dbService.database;
      await db.insert('novel_chapters', {
        'novelUrl': novel.url,
        'chapterUrl': '${novel.url}/chapter1',
        'title': '第一章',
        'chapterIndex': 0,
        'isUserInserted': 0,
        'insertedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'isAccompanied': 0,
      });
      print('   章节已添加');

      print('🔍 步骤3: 验证初始状态');
      final chapters = await dbService.getChapters(novel.url);
      expect(chapters.length, 1);
      expect(chapters.first.isRead, false, reason: '初始应该是未读');
      print('   初始状态: 未读 ✅');

      print('🔍 步骤4: 标记为已读');
      await dbService.markChapterAsRead(novel.url, chapters.first.url);
      print('   已调用 markChapterAsRead');

      print('🔍 步骤5: 验证已读状态');
      final updatedChapters = await dbService.getChapters(novel.url);
      expect(updatedChapters.length, 1);
      expect(updatedChapters.first.isRead, true, reason: '应该是已读');
      expect(updatedChapters.first.readAt, isNotNull, reason: 'readAt 应该有值');

      final readTime = DateTime.fromMillisecondsSinceEpoch(
        updatedChapters.first.readAt! * 1000,
      );
      print('   已读状态: 已读 ✅');
      print('   readAt: $readTime');

      print('✅ 已读标记功能完全正常！');

      // 清理测试数据
      await db.delete('novel_chapters');
      await db.delete('bookshelf');
    });
  });
}
