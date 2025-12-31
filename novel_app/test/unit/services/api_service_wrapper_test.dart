import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dio/dio.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import '../../test_helpers/mock_data.dart';

/// ApiServiceWrapper基础测试
///
/// 注意：由于ApiServiceWrapper使用真实的Dio、SharedPreferences和自动生成的DefaultApi，
/// 完整的单元测试需要依赖注入支持或集成测试环境。
///
/// 当前测试验证基本功能的存在性和单例模式。
/// 更详细的测试建议：
/// 1. 添加依赖注入支持（forTesting工厂方法）
/// 2. 创建集成测试（需要运行的后端服务）
/// 3. 使用HTTP mocking库（如http_mock_adapter）

@GenerateMocks([])
import 'api_service_wrapper_test.mocks.dart';

void main() {
  group('ApiServiceWrapper', () {
    late ApiServiceWrapper apiWrapper;

    setUp(() {
      apiWrapper = ApiServiceWrapper();
    });

    tearDown(() async {
      apiWrapper.dispose();
    });

    group('基础功能验证', () {
      test('should be singleton', () {
        final instance1 = ApiServiceWrapper();
        final instance2 = ApiServiceWrapper();

        expect(identical(instance1, instance2), isTrue);
      });

      test('should have init method', () {
        expect(() => apiWrapper.init(), returnsNormally);
      });

      test('should have dispose method', () {
        expect(() => apiWrapper.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls', () {
        apiWrapper.dispose();
        expect(() => apiWrapper.dispose(), returnsNormally);
      });
    });

    group('API方法存在性验证', () {
      test('searchNovels method exists', () {
        expect(() => apiWrapper.searchNovels('test'), returnsNormally);
      });

      test('getChapters method exists', () {
        expect(() => apiWrapper.getChapters('test-novel-url'), returnsNormally);
      });

      test('getChapterContent method exists', () {
        expect(() => apiWrapper.getChapterContent('test-chapter-url'), returnsNormally);
      });

      test('checkImageToVideoHealth method exists', () {
        expect(() => apiWrapper.checkImageToVideoHealth(), returnsNormally);
      });
    });

    group('Dio配置验证', () {
      test('should provide Dio instance', () {
        final dio = apiWrapper.dio;
        expect(dio, isNotNull);
        expect(dio, isA<Dio>());
      });

      test('should provide DefaultApi instance', () {
        final api = apiWrapper.defaultApi;
        expect(api, isNotNull);
      });
    });

    group('配置方法', () {
      test('getHost method exists', () {
        expect(() => apiWrapper.getHost(), returnsNormally);
      });

      test('getToken method exists', () {
        expect(() => apiWrapper.getToken(), returnsNormally);
      });
    });

    group('集成测试说明', () {
      test('integration tests require backend service', () async {
        // 这是一个文档性测试，说明集成测试的注意事项
        // 实际集成测试应该：
        // 1. 启动后端服务（localhost:3800）
        // 2. 配置有效的backend_host和backend_token
        // 3. 使用真实的网络请求测试API调用
        // 4. 验证响应数据格式和错误处理

        expect(true, isTrue); // 占位测试
      }, skip: '集成测试需要运行中的后端服务');
    });
  });
}
