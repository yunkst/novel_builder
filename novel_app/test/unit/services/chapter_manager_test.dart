import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/chapter_manager.dart';
import 'package:novel_app/models/chapter_content_result.dart';

/// ChapterManager 单元测试
///
/// 测试核心功能：
/// - getChapterContentWithSource: 正常获取、强制刷新、去重保留 fromCache
/// - getChapterContent: 向后兼容的 String 返回
/// - pending 清理、统计信息
void main() {
  ChapterManager.setTestMode(true);

  group('ChapterManager - getChapterContentWithSource 测试', () {
    late ChapterManager manager;

    setUp(() {
      manager = ChapterManager();
      manager.reset();
    });

    tearDown(() {
      manager.reset();
    });

    test('应该正确返回 ChapterContentResult（fromCache=true）', () async {
      final result = await manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        fetchFunction: () async => ChapterContentResult(
          content: '章节内容',
          fromCache: true,
        ),
      );

      expect(result.content, '章节内容');
      expect(result.fromCache, true);
    });

    test('应该正确返回爬虫抓取结果（fromCache=false）', () async {
      final result = await manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        fetchFunction: () async => ChapterContentResult(
          content: '爬虫内容',
          fromCache: false,
        ),
      );

      expect(result.content, '爬虫内容');
      expect(result.fromCache, false);
    });

    test('强制刷新应该跳过去重直接调用 fetchFunction', () async {
      var callCount = 0;

      await manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        forceRefresh: true,
        fetchFunction: () async {
          callCount++;
          return ChapterContentResult(content: '内容1', fromCache: true);
        },
      );

      await manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        forceRefresh: true,
        fetchFunction: () async {
          callCount++;
          return ChapterContentResult(content: '内容2', fromCache: false);
        },
      );

      expect(callCount, 2);
    });

    test('请求完成后不应该有 pending 请求', () async {
      await manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        fetchFunction: () async => ChapterContentResult(content: '内容'),
      );

      expect(manager.hasPendingRequest('https://example.com/chapter/1'), false);
    });

    test('应该正确统计总请求数', () async {
      await manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        fetchFunction: () async => ChapterContentResult(content: '内容1'),
      );
      await manager.getChapterContentWithSource(
        'https://example.com/chapter/2',
        fetchFunction: () async => ChapterContentResult(content: '内容2'),
      );

      final stats = manager.getStatistics();
      expect(stats['total_requests'], 2);
    });

    test('去重命中时 fromCache 应该保留原始值', () async {
      // 第一个请求返回 fromCache=true
      final future1 = manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        fetchFunction: () async {
          await Future.delayed(Duration(milliseconds: 50));
          return ChapterContentResult(content: '章节内容', fromCache: true);
        },
      );

      // 第二个相同 URL 的请求触发去重
      final future2 = manager.getChapterContentWithSource(
        'https://example.com/chapter/1',
        fetchFunction: () async => ChapterContentResult(content: 'should not reach here', fromCache: false),
      );

      // 两个请求应该拿到相同结果，fromCache 都是 true
      final result1 = await future1;
      final result2 = await future2;

      expect(result1.content, result2.content);
      expect(result1.fromCache, true);
      expect(result2.fromCache, true);
    });
  });

  group('ChapterManager - getChapterContent 向后兼容测试', () {
    late ChapterManager manager;

    setUp(() {
      manager = ChapterManager();
      manager.reset();
    });

    tearDown(() {
      manager.reset();
    });

    test('应该正确返回字符串内容', () async {
      final result = await manager.getChapterContent(
        'https://example.com/chapter/1',
        fetchFunction: () async => '章节内容',
      );

      expect(result, '章节内容');
    });

    test('强制刷新应该直接调用 fetchFunction', () async {
      var callCount = 0;

      await manager.getChapterContent(
        'https://example.com/chapter/1',
        forceRefresh: true,
        fetchFunction: () async {
          callCount++;
          return '内容';
        },
      );

      expect(callCount, 1);
    });
  });
}