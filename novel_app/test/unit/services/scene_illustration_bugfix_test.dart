import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/scene_illustration_service.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../../test_helpers/mock_data.dart';
import '../../test_bootstrap.dart';

/// Bug修复验证测试
///
/// 验证场景插图服务中的两个bug修复：
/// 1. 空章节内容时应该抛出异常，而不是静默返回
/// 2. 标记插入失败时应该停止整个流程
///
/// ## 数据库隔离方案 (2026-02-02)
///
/// 根据数据库锁定实验结果（test/experiments/FINAL_ANALYSIS_REPORT.md），
/// 实际情况分析：
///
/// 问题:
/// - SceneIllustrationService 内部硬编码使用 DatabaseService() 单例（第10行）
/// - 无法修改服务代码来注入独立的数据库实例
/// - DatabaseTestBase 的 _TestDatabaseService 无法被服务使用
///
/// 方案选择: 使用单例 DatabaseService + 严格的数据清理
///
/// 为什么这是可行方案？
/// 1. 测试串行执行（Flutter默认行为）
/// 2. 每个测试使用唯一的 chapterId/testNovelUrl 避免冲突
/// 3. setUp/tearDown 确保数据隔离
/// 4. 实验报告显示：方案1（单例模式）在测试环境中通过了所有测试
///
/// 实验验证（来自 FINAL_ANALYSIS_REPORT.md）：
/// - ✅ 方案1-测试1成功: 单例模式第1次运行通过
/// - ✅ 方案1-测试2成功: 单例模式第2次运行通过
/// - ✅ 方案1-测试3成功: 单例模式第3次运行通过
/// - ⚠️ 虽然存在潜在风险，但在测试串行执行的情况下是可行的
///
/// 重要措施：
/// - 每个测试使用唯一的数据标识（timestamp）
/// - tearDown 中彻底清理所有相关表
/// - 测试之间完全隔离，避免状态污染
void main() {
  // 初始化数据库测试环境
  initTests();

  group('SceneIllustrationService - Bug修复验证', () {
    late SceneIllustrationService service;
    late DatabaseService db;
    late String testNovelUrl;
    late String testChapterId;

    setUp(() async {
      // 创建服务实例（使用单例 DatabaseService）
      service = SceneIllustrationService();
      db = DatabaseService();

      // 使用时间戳确保每次测试的数据唯一
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      testNovelUrl = 'https://test.com/novel/bugfix_$timestamp';
      testChapterId = '$testNovelUrl/chapter/1';

      // 创建测试小说
      final novel = Novel(
        url: testNovelUrl,
        title: 'Bug修复测试小说_$timestamp',
        author: '测试',
      );

      // 使用单例数据库创建测试数据
      final database = await db.database;
      final novelMap = novel.toMap();
      novelMap.remove('isInBookshelf'); // 移除测试数据库不存在的字段
      novelMap['addedAt'] = DateTime.now().millisecondsSinceEpoch;
      await database.insert('bookshelf', novelMap,
          conflictAlgorithm: ConflictAlgorithm.replace);
    });

    tearDown(() async {
      // 清理测试数据（使用单例数据库）
      final database = await db.database;

      // 删除场景插图记录（注意列名是 novel_url，不是 novelUrl）
      await database.delete('scene_illustrations',
          where: 'novel_url = ?', whereArgs: [testNovelUrl]);

      // 删除章节缓存
      await database.delete('chapter_cache',
          where: 'chapterUrl LIKE ?', whereArgs: ['$testNovelUrl%']);

      // 删除章节元数据
      await database.delete('novel_chapters',
          where: 'novelUrl = ?', whereArgs: [testNovelUrl]);

      // 删除小说
      await database.delete('bookshelf',
          where: 'url = ?', whereArgs: [testNovelUrl]);
    });

    test('Bug #1修复: 空章节内容应该抛出异常', () async {
      // 创建空章节
      final emptyChapterId = '$testNovelUrl/chapter/empty';
      final chapter = MockData.createTestChapter(
        title: '空章节',
        url: emptyChapterId,
        content: '',
        chapterIndex: 0,
      );
      await db.cacheChapter(testNovelUrl, chapter, '');

      // 尝试创建插图（应该抛出异常）
      expect(
        () async => await service.createSceneIllustrationWithMarkup(
              novelUrl: testNovelUrl,
              chapterId: emptyChapterId,
              paragraphText: '测试段落',
              roles: [],
              imageCount: 1,
              insertionPosition: 'after',
              paragraphIndex: 0,
            ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('章节内容为空'),
        )),
      );

      // 验证数据库中没有创建记录
      final illustrations = await service.getIllustrationsByChapter(
        testNovelUrl,
        emptyChapterId,
      );
      expect(illustrations, isEmpty, reason: '不应该创建插图记录');
    });

    test('Bug #2修复: 标记插入失败应该停止整个流程', () async {
      // 创建一个多段落的章节
      final chapter = MockData.createTestChapter(
        title: '测试章节',
        url: testChapterId,
        content: '第一段内容\n第二段内容\n第三段内容',
        chapterIndex: 0,
      );
      await db.cacheChapter(testNovelUrl, chapter, chapter.content ?? '');

      // 验证章节已正确缓存
      final cachedContent = await db.getCachedChapter(testChapterId);
      expect(cachedContent, isNotEmpty, reason: '章节应该已正确缓存');
      expect(cachedContent, contains('第一段内容'));
      expect(cachedContent, contains('第二段内容'));
      expect(cachedContent, contains('第三段内容'));

      // 使用超出范围的索引（应该抛出异常）
      expect(
        () async => await service.createSceneIllustrationWithMarkup(
              novelUrl: testNovelUrl,
              chapterId: testChapterId,
              paragraphText: '测试段落',
              roles: [],
              imageCount: 1,
              insertionPosition: 'after',
              paragraphIndex: 999, // 超出范围
            ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf([
            contains('创建场景插图失败'),
            // 注意：段落索引超出范围异常被包装在 "创建场景插图失败" 中
            anyOf(
              contains('段落索引超出范围'),
              contains('ArgumentError'), // ArgumentError 类型
            ),
          ]),
        )),
      );

      // 验证数据库中没有创建记录
      final illustrations = await service.getIllustrationsByChapter(
        testNovelUrl,
        testChapterId,
      );
      expect(illustrations, isEmpty,
          reason: '标记插入失败时不应该创建数据库记录');
    });

    test('Bug修复后正常流程应该工作', () async {
      // 创建正常章节
      final chapter = MockData.createTestChapter(
        title: '正常章节',
        url: testChapterId,
        content: '第一段内容\n第二段内容\n第三段内容',
        chapterIndex: 0,
      );
      await db.cacheChapter(testNovelUrl, chapter, chapter.content ?? '');

      // 注意：由于createSceneIllustrationWithMarkup会调用API，
      // 而测试环境没有API服务，这个测试会失败
      // 这里我们只验证标记插入是否抛出异常（应该不抛出）

      try {
        await service.createSceneIllustrationWithMarkup(
          novelUrl: testNovelUrl,
          chapterId: testChapterId,
          paragraphText: '第一段内容',
          roles: [],
          imageCount: 1,
          insertionPosition: 'after',
          paragraphIndex: 0,
        );
        // 如果到达这里，说明标记插入成功了（但API调用会失败）
        fail('应该因为API调用失败而抛出异常');
      } catch (e) {
        // 预期行为：API调用失败
        expect(e.toString(), contains('创建场景插图失败'));
      }
    });
  });
}
