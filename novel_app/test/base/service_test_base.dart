import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/services/database_service.dart';
import '../test_bootstrap.dart';

/// 服务测试基类
///
/// 提供服务测试的通用Mock和初始化逻辑
/// 所有服务层测试都应该继承此类
///
/// 使用示例：
/// ```dart
/// class MyServiceTest extends ServiceTestBase {
///   @override
///   Future<void> setUp() async {
///     await super.setUp();
///     // 自定义初始化
///   }
/// }
/// ```
abstract class ServiceTestBase {
  /// Mock数据库服务
  late MockDatabaseService mockDb;

  /// 设置测试环境
  ///
  /// 子类可以覆盖此方法添加自定义初始化逻辑
  Future<void> setUp() async {
    // 初始化测试环境
    initTests();

    // 创建Mock数据库
    mockDb = MockDatabaseService();
  }

  /// 清理测试环境
  ///
  /// 在测试完成后调用
  Future<void> tearDown() async {
    // 重置所有Mock调用
    reset(mockDb);
  }

  /// 验证Mock方法被调用
  ///
  /// 辅助方法：验证Mock对象的特定方法被调用了指定次数
  void verifyMockCalled<T extends Mock>(
    T mock,
    String methodName, {
    int times = 1,
    String? reason,
  }) {
    try {
      verify(() => (mock as dynamic).noSuchMethod(
        Invocation.method(
          Symbol(methodName),
          [],
        ),
      )).called(times);
    } catch (e) {
      final msg = reason ?? 'Mock方法 $methodName 应该被调用 $times 次';
      fail('$msg\n实际错误: $e');
    }
  }

  /// 验证Mock方法未被调用
  ///
  /// 辅助方法：验证Mock对象的特定方法从未被调用
  void verifyMockNeverCalled<T extends Mock>(
    T mock,
    String methodName, {
    String? reason,
  }) {
    try {
      verifyNever(() => (mock as dynamic).noSuchMethod(
        Invocation.method(
          Symbol(methodName),
          [],
        ),
      ));
    } catch (e) {
      final msg = reason ?? 'Mock方法 $methodName 不应该被调用';
      fail('$msg\n实际错误: $e');
    }
  }
}

/// Mock数据库服务
///
/// 使用Mockito生成的Mock类
class MockDatabaseService extends Mock implements DatabaseService {}
