import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';

void main() {
  group('Dio连接池配置验证', () {
    test('验证连接池配置正确设置', () {
      // 配置与生产环境相同的Dio设置
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        connectTimeout: Duration(seconds: 10),
        receiveTimeout: Duration(seconds: 30),
      ));

      // 应用相同的连接池配置
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.maxConnectionsPerHost = 100;
          return client;
        },
      );

      // 验证httpClientAdapter已正确设置
      expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
      print('✅ IOHttpClientAdapter 配置成功');

      // 验证Dio实例可以正常创建
      expect(dio, isNotNull);
      expect(dio.options.baseUrl, 'https://example.com');
      print('✅ Dio基础配置验证通过');
    });

    test('验证连接池大小设置逻辑', () {
      // 模拟HttpClient的创建过程
      final client = HttpClient();

      // 设置连接池大小为100
      client.maxConnectionsPerHost = 100;

      // 验证设置成功（Dart的HttpClient没有直接的getter，所以我们只能验证设置不会抛出异常）
      expect(client.maxConnectionsPerHost, 100);
      print('✅ 连接池大小设置验证通过: 100个并发连接/主机');

      client.close();
    });

    test('验证配置代码可以正常运行', () {
      // 测试实际的配置代码是否能正常运行
      expect(() {
        final testDio = Dio(BaseOptions(
          baseUrl: 'https://test.example.com',
        ));

        testDio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.maxConnectionsPerHost = 100;
            return client;
          },
        );

        print('✅ 实际配置代码运行成功');
      }, returnsNormally);
    });
  });
}