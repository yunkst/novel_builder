import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/bookshelf_providers.dart';

/// CurrentBookshelfId Provider 单元测试
///
/// 测试书架持久化功能的核心行为：
/// - 默认值初始化
/// - 状态更新
/// - 多次设置书架ID的行为
///
/// 注意：由于SharedPreferences需要在Flutter环境中运行，此测试专注于Provider的状态管理逻辑。
/// 完整的集成测试（包括SharedPreferences持久化）需要在widget测试或E2E测试中验证。
void main() {
  // 初始化Flutter绑定以支持SharedPreferences
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('[CurrentBookshelfId] - Provider状态管理测试', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('build 应该返回默认值1', () {
      // Act
      final result = container.read(currentBookshelfIdProvider);

      // Assert
      expect(result, equals(1),
          reason: '应该返回默认书架ID（全部小说）');
    });

    test('setBookshelfId 应该更新Provider状态', () {
      // Arrange
      const newBookshelfId = 5;

      // Act
      container
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(newBookshelfId);

      // Assert
      final result = container.read(currentBookshelfIdProvider);
      expect(result, equals(newBookshelfId));
    });

    test('setBookshelfId 应该支持多次设置不同的书架ID', () {
      // Arrange
      const firstId = 3;
      const secondId = 7;

      final notifier = container.read(currentBookshelfIdProvider.notifier);

      // Act
      notifier.setBookshelfId(firstId);
      final firstResult = container.read(currentBookshelfIdProvider);

      notifier.setBookshelfId(secondId);
      final secondResult = container.read(currentBookshelfIdProvider);

      // Assert
      expect(firstResult, equals(firstId));
      expect(secondResult, equals(secondId));
    });

    test('setBookshelfId 应该支持设置为0（边界值测试）', () {
      // Arrange
      const zeroBookshelfId = 0;

      // Act
      container
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(zeroBookshelfId);

      // Assert
      final result = container.read(currentBookshelfIdProvider);
      expect(result, equals(zeroBookshelfId));
    });

    test('setBookshelfId 应该支持设置较大的书架ID值', () {
      // Arrange
      const largeBookshelfId = 999999;

      // Act
      container
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(largeBookshelfId);

      // Assert
      final result = container.read(currentBookshelfIdProvider);
      expect(result, equals(largeBookshelfId));
    });

    test('setBookshelfId 应该支持快速连续设置相同的书架ID', () {
      // Arrange
      const bookshelfId = 3;

      final notifier = container.read(currentBookshelfIdProvider.notifier);

      // Act - 快速连续设置相同值3次
      notifier.setBookshelfId(bookshelfId);
      notifier.setBookshelfId(bookshelfId);
      notifier.setBookshelfId(bookshelfId);

      // Assert
      final result = container.read(currentBookshelfIdProvider);
      expect(result, equals(bookshelfId));
    });

    test('Provider状态应该在多个容器间独立', () {
      // Arrange
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();

      // Act - 在container1中设置书架ID
      const bookshelfId1 = 5;
      container1
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(bookshelfId1);

      // 在container2中设置不同的书架ID
      const bookshelfId2 = 10;
      container2
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(bookshelfId2);

      // Assert - 两个容器的状态应该独立
      expect(container1.read(currentBookshelfIdProvider), equals(bookshelfId1));
      expect(container2.read(currentBookshelfIdProvider), equals(bookshelfId2));

      // Cleanup
      container1.dispose();
      container2.dispose();
    });

    test('Provider应该在dispose后重置状态', () {
      // Arrange - 设置书架ID为5
      const bookshelfId = 5;
      container
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(bookshelfId);

      expect(container.read(currentBookshelfIdProvider), equals(bookshelfId));

      // Act - 销毁容器并创建新容器
      container.dispose();
      final newContainer = ProviderContainer();

      // Assert - 新容器应该返回默认值
      expect(newContainer.read(currentBookshelfIdProvider), equals(1));

      // Cleanup
      newContainer.dispose();
      // 重新赋值以便tearDown正常工作
      container = ProviderContainer();
    });

    test('应该支持负数ID（虽然实际场景不会出现）', () {
      // Arrange
      const negativeId = -1;

      // Act
      container
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(negativeId);

      // Assert
      final result = container.read(currentBookshelfIdProvider);
      expect(result, equals(negativeId),
          reason: 'Provider不验证值范围，由调用方保证正确性');
    });
  });

  group('[CurrentBookshelfId] - 状态监听测试', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('应该能够监听状态变化', () {
      // Arrange
      const newBookshelfId = 7;
      final listenerValues = <int>[];

      // Act - 添加监听器
      container.listen<int>(
        currentBookshelfIdProvider,
        (previous, next) {
          listenerValues.add(next);
        },
        fireImmediately: true,
      );

      // 设置新值
      container
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(newBookshelfId);

      // Assert
      expect(listenerValues, equals([1, newBookshelfId]),
          reason: '应该收到初始值和更新后的值');
    });

    test('监听器应该只在值变化时被调用', () {
      // Arrange
      const bookshelfId = 5;
      final listenerValues = <int>[];

      container.listen<int>(
        currentBookshelfIdProvider,
        (previous, next) {
          listenerValues.add(next);
        },
        fireImmediately: false,
      );

      final notifier = container.read(currentBookshelfIdProvider.notifier);

      // Act - 设置相同值3次
      notifier.setBookshelfId(bookshelfId);
      notifier.setBookshelfId(bookshelfId);
      notifier.setBookshelfId(bookshelfId);

      // Assert
      expect(listenerValues, equals([bookshelfId]),
          reason: '相同值不应该重复触发监听器');
    });
  });

  group('[CurrentBookshelfId] - 并发访问测试', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('应该支持并发读取状态', () async {
      // Arrange
      const bookshelfId = 8;
      container
          .read(currentBookshelfIdProvider.notifier)
          .setBookshelfId(bookshelfId);

      // Act - 并发读取1000次
      final results = await Future.wait(
        List.generate(
          1000,
          (_) => Future.value(
            container.read(currentBookshelfIdProvider),
          ),
        ),
      );

      // Assert
      expect(results, everyElement(equals(bookshelfId)));
    });

    test('应该支持并发设置操作', () async {
      // Arrange
      final notifier = container.read(currentBookshelfIdProvider.notifier);

      // Act - 快速连续设置不同的值
      notifier.setBookshelfId(10);
      notifier.setBookshelfId(20);
      notifier.setBookshelfId(30);

      // Assert - 最终值应该是最后一次设置的值
      final result = container.read(currentBookshelfIdProvider);
      expect(result, equals(30),
          reason: '最终值应该是30');
    });
  });
}
