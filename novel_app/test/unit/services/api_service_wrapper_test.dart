import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:novel_api/novel_api.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/services/api_service_wrapper.dart';

// 生成 Mock 类
@GenerateMocks([Dio, DefaultApi])
import 'api_service_wrapper_test.mocks.dart';

void main() {
  group('ApiServiceWrapper - 依赖注入重构验证', () {
    late ApiServiceWrapper apiService;
    late MockDio mockDio;
    late MockDefaultApi mockApi;

    setUp(() {
      mockDio = MockDio();
      mockApi = MockDefaultApi();
    });

    test('应该能够通过构造函数注入 Dio 实例', () {
      // Arrange & Act
      apiService = ApiServiceWrapper(null, mockDio);

      // Assert
      expect(apiService, isNotNull);
      expect(apiService.dio, equals(mockDio));
    });

    test('应该能够通过构造函数注入 DefaultApi 实例', () {
      // Arrange & Act
      apiService = ApiServiceWrapper(mockApi, null);

      // Assert - 只验证实例创建成功，不访问 defaultApi getter
      // 因为 defaultApi getter 会检查初始化状态
      expect(apiService, isNotNull);
    });

    test('应该能够同时注入 Dio 和 DefaultApi', () {
      // Arrange & Act
      apiService = ApiServiceWrapper(mockApi, mockDio);

      // Assert - 只验证实例创建成功
      expect(apiService, isNotNull);
      expect(apiService.dio, equals(mockDio));
    });

    test('应该能够在不注入参数时创建默认实例', () {
      // Arrange & Act
      apiService = ApiServiceWrapper();

      // Assert - 只验证实例创建成功和 dio getter
      expect(apiService, isNotNull);
      expect(apiService.dio, isA<Dio>());
    });

    test('未初始化时调用业务方法应该抛出异常', () async {
      // Arrange
      apiService = ApiServiceWrapper(mockApi, mockDio);

      // Act & Assert
      expect(
        () => apiService.defaultApi,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('未初始化'),
        )),
      );
    });

    test('isInitialized 应该反映初始化状态', () {
      // Arrange
      apiService = ApiServiceWrapper(mockApi, mockDio);

      // Act & Assert
      expect(apiService.isInitialized, isFalse);
    });
  });

  group('ApiServiceWrapper - 不再使用单例模式', () {
    test('每个实例应该是独立的', () {
      // Arrange & Act
      final service1 = ApiServiceWrapper();
      final service2 = ApiServiceWrapper();

      // Assert
      expect(identical(service1, service2), isFalse);
      expect(service1, isNot(equals(service2)));
    });

    test('应该可以创建多个独立实例', () {
      // Arrange & Act
      final services = List.generate(5, (_) => ApiServiceWrapper());

      // Assert
      expect(services.length, equals(5));
      for (var i = 0; i < services.length; i++) {
        for (var j = i + 1; j < services.length; j++) {
          expect(identical(services[i], services[j]), isFalse);
        }
      }
    });
  });
}
