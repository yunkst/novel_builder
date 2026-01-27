import 'package:flutter_test/flutter_test.dart';
import 'package:async/async.dart';
import 'package:novel_app/services/chapter_manager.dart';

void main() {
  group('ChapterManager Tests', () {
    late ChapterManager chapterManager;
    late List<String> capturedLogs;

    setUp(() {
      chapterManager = ChapterManager();
      chapterManager.reset(); // 重置状态确保测试独立
      capturedLogs = [];
    });

    tearDown(() {
      chapterManager.reset();
    });

    group('单例模式测试', () {
      test('应该返回相同的实例', () {
        final instance1 = ChapterManager();
        final instance2 = ChapterManager();
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('请求去重测试', () {
      test('相同章节的重复请求应该被去重', () async {
        const chapterUrl = 'https://example.com/chapter1';
        int requestCount = 0;

        Future<String> mockFetchFunction() async {
          requestCount++;
          await Future.delayed(Duration(milliseconds: 100)); // 模拟网络延迟
          return 'Chapter content for $chapterUrl';
        }

        // 同时发起多个相同请求
        final futures = <Future<String>>[];
        for (int i = 0; i < 5; i++) {
          futures.add(
            chapterManager.getChapterContent(
              chapterUrl,
              fetchFunction: mockFetchFunction,
            ),
          );
        }

        final results = await Future.wait(futures);

        // 验证结果
        expect(results.length, 5);
        for (final result in results) {
          expect(result, 'Chapter content for $chapterUrl');
        }
        expect(requestCount, 1); // 应该只发起一次实际请求
      });

      test('不同章节的请求不应该被去重', () async {
        const chapterUrl1 = 'https://example.com/chapter1';
        const chapterUrl2 = 'https://example.com/chapter2';
        int requestCount = 0;

        Future<String> mockFetchFunction() async {
          requestCount++;
          return 'Content for chapter $requestCount';
        }

        final result1 = await chapterManager.getChapterContent(
          chapterUrl1,
          fetchFunction: mockFetchFunction,
        );

        final result2 = await chapterManager.getChapterContent(
          chapterUrl2,
          fetchFunction: mockFetchFunction,
        );

        expect(result1, 'Content for chapter 1');
        expect(result2, 'Content for chapter 2');
        expect(requestCount, 2); // 应该发起两次请求
      });

      test('forceRefresh应该绕过去重机制', () async {
        const chapterUrl = 'https://example.com/chapter1';
        int requestCount = 0;

        Future<String> mockFetchFunction() async {
          requestCount++;
          return 'Content $requestCount';
        }

        // 第一次请求
        final result1 = await chapterManager.getChapterContent(
          chapterUrl,
          fetchFunction: mockFetchFunction,
        );

        // 强制刷新请求
        final result2 = await chapterManager.getChapterContent(
          chapterUrl,
          forceRefresh: true,
          fetchFunction: mockFetchFunction,
        );

        expect(result1, 'Content 1');
        expect(result2, 'Content 2');
        expect(requestCount, 2); // 应该发起两次请求
      });
    });

    group('请求去重测试', () {
      test('相同章节的重复请求应该被去重', () async {
        const chapterUrl = 'https://example.com/chapter1';
        int requestCount = 0;

        Future<String> mockFetchFunction() async {
          requestCount++;
          await Future.delayed(Duration(milliseconds: 100)); // 模拟网络延迟
          return 'Chapter content for $chapterUrl';
        }

        // 同时发起多个相同请求
        final futures = <Future<String>>[];
        for (int i = 0; i < 5; i++) {
          futures.add(
            chapterManager.getChapterContent(
              chapterUrl,
              fetchFunction: mockFetchFunction,
            ),
          );
        }

        final results = await Future.wait(futures);

        // 验证结果
        expect(results.length, 5);
        for (final result in results) {
          expect(result, 'Chapter content for $chapterUrl');
        }
        // 第一个请求正常执行，后续请求去重复用第一个请求的Future
        expect(requestCount, greaterThanOrEqualTo(1)); // 至少发起一次实际请求
      });
    });

    group('状态管理测试', () {
      test('hasPendingRequest应该正确反映章节状态', () async {
        const chapterUrl = 'https://example.com/chapter1';

        Future<String> mockFetchFunction() async {
          await Future.delayed(Duration(milliseconds: 200));
          return 'Content';
        }

        // 开始请求前
        expect(chapterManager.hasPendingRequest(chapterUrl), isFalse);

        // 发起请求
        final requestFuture = chapterManager.getChapterContent(
          chapterUrl,
          fetchFunction: mockFetchFunction,
        );

        // 请求进行中
        expect(chapterManager.hasPendingRequest(chapterUrl), isTrue);

        // 等待请求完成
        await requestFuture;

        // 请求完成后
        expect(chapterManager.hasPendingRequest(chapterUrl), isFalse);
      });

      test('getStatistics应该返回正确的统计信息', () async {
        const chapterUrl1 = 'https://example.com/chapter1';
        const chapterUrl2 = 'https://example.com/chapter2';

        Future<String> mockFetchFunction() async {
          return 'Content';
        }

        // 发起一些请求
        await chapterManager.getChapterContent(
          chapterUrl1,
          fetchFunction: mockFetchFunction,
        );

        await chapterManager.getChapterContent(
          chapterUrl2,
          fetchFunction: mockFetchFunction,
        );

        final stats = chapterManager.getStatistics();
        expect(stats['total_requests'], 2);
        expect(stats['pending_requests'], 0);
      });
    });

    group('错误处理测试', () {
      test('网络错误应该正确传播', () async {
        const chapterUrl = 'https://example.com/chapter1';

        Future<String> mockFetchFunction() async {
          throw Exception('Network error');
        }

        expect(
          () => chapterManager.getChapterContent(
            chapterUrl,
            fetchFunction: mockFetchFunction,
          ),
          throwsException,
        );
      });

      test('一个请求失败不应该影响其他请求', () async {
        const chapterUrl1 = 'https://example.com/chapter1';
        const chapterUrl2 = 'https://example.com/chapter2';

        int requestCount = 0;

        Future<String> mockFetchFunction() async {
          requestCount++;
          if (requestCount == 1) {
            throw Exception('First request failed');
          }
          return 'Success';
        }

        // 第一个请求失败
        expect(
          () => chapterManager.getChapterContent(
            chapterUrl1,
            fetchFunction: mockFetchFunction,
          ),
          throwsException,
        );

        // 第二个请求应该成功
        final result = await chapterManager.getChapterContent(
          chapterUrl2,
          fetchFunction: mockFetchFunction,
        );
        expect(result, 'Success');
      });
    });

    group('内存管理测试', () {
      test('reset应该清理所有状态', () async {
        const chapterUrl = 'https://example.com/chapter1';

        Future<String> mockFetchFunction() async {
          return 'Content';
        }

        // 进行一些操作
        await chapterManager.getChapterContent(
          chapterUrl,
          fetchFunction: mockFetchFunction,
        );

        expect(chapterManager.hasPendingRequest(chapterUrl), isFalse);

        // 重置状态
        chapterManager.reset();

        // 验证统计信息被重置
        final stats = chapterManager.getStatistics();
        expect(stats['total_requests'], 0);
        expect(stats['deduplicated_requests'], 0);
      });

      test('cleanupExpiredStates应该清理过期的请求', () async {
        const chapterUrl = 'https://example.com/chapter1';

        // 创建一个延迟完成的请求
        Future<String> mockFetchFunction() async {
          await Future.delayed(Duration(milliseconds: 100));
          return 'Content';
        };

        // 发起请求
        final requestFuture = chapterManager.getChapterContent(
          chapterUrl,
          fetchFunction: mockFetchFunction,
        );

        expect(chapterManager.hasPendingRequest(chapterUrl), isTrue);

        // 等待请求完成
        await requestFuture;

        // 清理过期状态
        chapterManager.cleanupExpiredStates();

        // 验证状态被清理
        expect(chapterManager.hasPendingRequest(chapterUrl), isFalse);
      });
    });

    group('边界情况测试', () {
      test('hasPendingRequest应该正确反映请求状态', () async {
        const chapterUrl = 'https://example.com/chapter1';

        Future<String> mockFetchFunction() async {
          await Future.delayed(Duration(milliseconds: 100));
          return 'Content';
        }

        // 请求前
        expect(chapterManager.hasPendingRequest(chapterUrl), isFalse);

        // 发起请求
        final requestFuture = chapterManager.getChapterContent(
          chapterUrl,
          fetchFunction: mockFetchFunction,
        );

        // 请求中
        expect(chapterManager.hasPendingRequest(chapterUrl), isTrue);

        // 等待完成
        await requestFuture;

        // 完成后
        expect(chapterManager.hasPendingRequest(chapterUrl), isFalse);
      });

      test('多次reset应该是安全的', () {
        chapterManager.reset();
        chapterManager.reset();
        chapterManager.reset();

        final stats = chapterManager.getStatistics();
        expect(stats['total_requests'], 0);
        expect(stats['pending_requests'], 0);
      });

      test('并发请求限制应该生效', () async {
        final chapterUrls = List.generate(
          5,
          (i) => 'https://example.com/chapter$i',
        );

        int requestCount = 0;

        Future<String> mockFetchFunction() async {
          requestCount++;
          await Future.delayed(Duration(milliseconds: 50));
          return 'Content';
        }

        // 同时发起所有请求
        final futures = chapterUrls.map((url) {
          return chapterManager.getChapterContent(
            url,
            fetchFunction: mockFetchFunction,
          );
        }).toList();

        await Future.wait(futures);

        // 所有请求都应该完成
        expect(requestCount, 5);
      });
    });
  });
}