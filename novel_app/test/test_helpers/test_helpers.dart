import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/services/dify_service.dart';

/// 测试辅助函数库
///
/// 提供通用的测试辅助方法
class TestHelpers {
  /// 验证Mock对象的某个方法被调用
  static void verifyMockCall<T extends Mock>(
    T mock,
    String methodName, {
    int calledTimes = 1,
    dynamic capturedArg,
  }) {
    try {
      verify(() => (mock as dynamic).noSuchMethod(
            Invocation.method(
              Symbol(methodName),
              capturedArg != null ? [capturedArg] : [],
            ),
          )).called(calledTimes);
    } catch (e) {
      fail('Failed to verify method call: $methodName\nError: $e');
    }
  }

  /// 等待异步操作完成
  static Future<void> wait(int milliseconds) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// 验证抛出特定异常
  static Future<void> expectThrows<T>(
    Future<void> Function() callback,
  ) async {
    try {
      await callback();
      fail('Expected exception of type $T but none was thrown');
    } catch (e) {
      expect(e, isA<T>());
    }
  }
}

/// Mock类定义
@GenerateMocks([
  DatabaseService,
  ApiServiceWrapper,
  DifyService,
])
void main() {}
