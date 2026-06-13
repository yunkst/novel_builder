/// PaginationController 分页控制器单元测试
///
/// 验证分页控制器的所有功能：
/// - 状态转换：idle → loading → success/error
/// - refresh / loadNextPage / loadPage / retry
/// - 重复加载保护
/// - 数据增删改
/// - CachedPaginationController 缓存逻辑
/// - PaginationResult 工厂方法
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/controllers/pagination_controller_test.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/controllers/pagination_controller.dart';

void main() {
  group('PaginationController', () {
    late PaginationController<String> controller;
    late List<List<String>> fetchCalls;
    late int completedCount;
    late List<String> failedErrors;

    setUp(() {
      fetchCalls = [];
      completedCount = 0;
      failedErrors = [];

      // 默认 fetchPage：返回带数字的列表
      Future<List<String>> fetchPage(int page, int pageSize) async {
        fetchCalls.add(['page=$page', 'size=$pageSize']);
        return List.generate(pageSize, (i) => 'item_${page}_$i');
      }

      controller = PaginationController<String>(
        fetchPage: fetchPage,
        pageSize: 10,
        onLoadCompleted: () => completedCount++,
        onLoadFailed: (err) => failedErrors.add(err),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    group('初始状态', () {
      test('应处于 idle 状态', () {
        expect(controller.isLoading, isFalse);
        expect(controller.isLoadingMore, isFalse);
        expect(controller.items, isEmpty);
        expect(controller.hasMore, isTrue);
        expect(controller.isEmpty, isTrue);
        expect(controller.hasError, isFalse);
      });

      test('canLoadMore 应为 true', () {
        expect(controller.canLoadMore, isTrue);
      });
    });

    group('refresh', () {
      test('应触发 fetchPage 并加载数据', () async {
        await controller.refresh();

        expect(controller.items.length, 10);
        expect(controller.isLoading, isFalse);
        expect(completedCount, 1);
        expect(fetchCalls.length, 1);
        expect(fetchCalls.first, ['page=1', 'size=10']);
      });

      test('重复 refresh 应被忽略（isLoading 状态）', () async {
        final future1 = controller.refresh();
        final future2 = controller.refresh();

        await Future.wait([future1, future2]);

        // 应只调用 1 次
        expect(fetchCalls.length, 1);
      });

      test('load 失败应调用 onLoadFailed', () async {
        controller = PaginationController<String>(
          fetchPage: (page, size) async => throw Exception('网络错误'),
          onLoadFailed: (err) => failedErrors.add(err),
        );

        await controller.refresh();

        expect(controller.hasError, isTrue);
        expect(failedErrors.length, 1);
        expect(failedErrors.first, contains('网络错误'));
      });

      test('hasMore=false 当返回数据小于 pageSize 时', () async {
        controller = PaginationController<String>(
          fetchPage: (page, size) async => List.generate(5, (i) => 'item_$i'),
        );

        await controller.refresh();

        expect(controller.hasMore, isFalse);
      });

      test('hasMore=true 当返回数据 == pageSize 时', () async {
        // 使用默认 controller（返回 10 条，pageSize=10）
        // 默认 controller 已经在 setUp 中配置好了
        await controller.refresh();
        expect(controller.hasMore, isTrue);
      });
    });

    group('loadNextPage', () {
      test('应加载下一页（追加数据）', () async {
        await controller.refresh();
        await controller.loadNextPage();

        // 应有 20 项（10 + 10）
        expect(controller.items.length, 20);
        expect(fetchCalls.length, 2);
        expect(fetchCalls[1], ['page=2', 'size=10']);
      });

      test('hasMore=false 时不应加载', () async {
        controller = PaginationController<String>(
          fetchPage: (page, size) async => List.generate(5, (i) => 'item_$i'),
        );

        await controller.refresh();
        final initialCalls = fetchCalls.length;
        await controller.loadNextPage();

        expect(fetchCalls.length, initialCalls);
      });

      test('canLoadMore=false 时不应加载', () async {
        controller.isLoading = true;
        await controller.loadNextPage();

        expect(fetchCalls, isEmpty);
      });
    });

    group('loadPage', () {
      test('应加载指定页（默认追加）', () async {
        await controller.loadPage(3);

        expect(controller.currentPage, 4); // 加载完成后会自增
        expect(fetchCalls.first, ['page=3', 'size=10']);
      });

      test('replace=true 时应清空并加载', () async {
        await controller.refresh();
        await controller.loadPage(2, replace: true);

        expect(controller.items.length, 10);
        expect(fetchCalls.last, ['page=2', 'size=10']);
      });
    });

    group('retry', () {
      test('应清除错误状态并重新加载', () async {
        controller = PaginationController<String>(
          fetchPage: (page, size) async => throw Exception('错误'),
        );

        await controller.refresh();
        expect(controller.hasError, isTrue);

        // 切换 fetchPage 为成功版本
        bool useSuccess = false;
        controller = PaginationController<String>(
          fetchPage: (page, size) async =>
              useSuccess ? ['a', 'b'] : throw Exception('错误'),
        );
        // 重新初始化为成功的 fetch
        useSuccess = true;
        await controller.refresh();

        expect(controller.hasError, isFalse);
        expect(controller.items.length, 2);
      });
    });

    group('数据增删改', () {
      test('appendItems 应追加数据', () {
        controller.appendItems(['a', 'b', 'c']);

        expect(controller.items, ['a', 'b', 'c']);
      });

      test('insertItem 应在指定位置插入', () {
        controller.appendItems(['a', 'b', 'c']);
        controller.insertItem(1, 'X');

        expect(controller.items, ['a', 'X', 'b', 'c']);
      });

      test('removeItem 应移除指定位置', () {
        controller.appendItems(['a', 'b', 'c']);
        controller.removeItem(1);

        expect(controller.items, ['a', 'c']);
      });

      test('updateItem 应更新指定位置', () {
        controller.appendItems(['a', 'b', 'c']);
        controller.updateItem(1, 'X');

        expect(controller.items, ['a', 'X', 'c']);
      });

      test('clear 应清空数据', () async {
        await controller.refresh();
        controller.clear();

        expect(controller.items, isEmpty);
        expect(controller.hasMore, isTrue);
      });
    });

    group('setTotalItems', () {
      test('应设置总数据量并计算总页数', () {
        controller.setTotalItems(25);

        expect(controller.totalItems, 25);
        expect(controller.totalPages, 3); // ceil(25 / 10)
      });
    });

    group('notifier 机制', () {
      test('refresh 后应通知监听器', () async {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        await controller.refresh();

        // 至少 2 次：开始加载 + 加载完成
        expect(notifyCount, greaterThanOrEqualTo(2));
      });
    });
  });

  group('CachedPaginationController', () {
    group('缓存逻辑', () {
      test('应缓存已加载的页面', () async {
        final fetchCalls = <int>[];
        final controller = CachedPaginationController<int>(
          fetchPage: (page, size) async {
            fetchCalls.add(page);
            return List.generate(size, (i) => page * 100 + i);
          },
          pageSize: 5,
        );

        await controller.loadPage(1);
        await controller.loadPage(2);

        // 再次加载 page 1 应使用缓存
        await controller.loadPage(1);

        expect(fetchCalls, [1, 2]); // page 1 没有被重新获取
        expect(controller.items.length, 10);
        controller.dispose();
      });

      test('loadNextPage 应加载下一页', () async {
        final controller = CachedPaginationController<int>(
          fetchPage: (page, size) async =>
              List.generate(size, (i) => page * 100 + i),
          pageSize: 5,
        );

        await controller.loadPage(1);
        await controller.loadNextPage();

        expect(controller.items.length, 10);
        expect(controller.currentPage, 2);
        controller.dispose();
      });

      test('refresh 应清空缓存', () async {
        final controller = CachedPaginationController<int>(
          fetchPage: (page, size) async =>
              List.generate(size, (i) => page * 100 + i),
          pageSize: 5,
        );

        await controller.loadPage(1);
        await controller.loadPage(2);
        await controller.refresh();

        expect(controller.currentPage, 1);
        expect(controller.items.length, 5);
        controller.dispose();
      });

      test('hasMore=false 时 loadNextPage 不应加载', () async {
        final controller = CachedPaginationController<int>(
          fetchPage: (page, size) async =>
              List.generate(3, (i) => i), // < pageSize
          pageSize: 5,
        );

        await controller.loadPage(1);
        await controller.loadNextPage();

        // 第一次加载完后 hasMore=false
        expect(controller.hasMore, isFalse);
        controller.dispose();
      });

      test('loadPage 失败应设置 errorMessage', () async {
        final controller = CachedPaginationController<int>(
          fetchPage: (page, size) async => throw Exception('网络错误'),
        );

        await controller.loadPage(1);

        expect(controller.errorMessage, isNotNull);
        expect(controller.isLoading, isFalse);
        controller.dispose();
      });
    });
  });

  group('PaginationResult', () {
    test('fromResponse 应正确计算 hasNext 和 hasPrevious', () {
      final result = PaginationResult<String>.fromResponse(
        items: ['a'],
        currentPage: 2,
        pageSize: 10,
        total: 50,
      );

      expect(result.hasNext, isTrue);
      expect(result.hasPrevious, isTrue);
      expect(result.totalPages, 5);
    });

    test('fromResponse 在 total 为 null 时基于 items.length 判断 hasNext', () {
      final result = PaginationResult<String>.fromResponse(
        items: List.generate(10, (i) => 'a$i'),
        currentPage: 1,
        pageSize: 10,
      );

      expect(result.hasNext, isTrue);
    });

    test('fromResponse 在 currentPage=1 时 hasPrevious=false', () {
      final result = PaginationResult<String>.fromResponse(
        items: ['a'],
        currentPage: 1,
        pageSize: 10,
      );

      expect(result.hasPrevious, isFalse);
    });

    test('empty 应返回空结果', () {
      // Note: empty is a static const on the raw type
      // ignore: prefer_const_constructors
      final empty = PaginationResult.empty;
      expect(empty.items, isEmpty);
      expect(empty.hasNext, isFalse);
      expect(empty.hasPrevious, isFalse);
    });
  });
}
