import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/services/api_service_wrapper.dart';
import '../lib/services/cache_manager.dart';

// 生成Mock类
@GenerateMocks([Dio])
import 'dio_connection_test.mocks.dart';

void main() {
  group('Dio 连接问题测试', () {
    late ApiServiceWrapper apiWrapper;
    late CacheManager cacheManager;

    setUp(() {
      apiWrapper = ApiServiceWrapper();
      cacheManager = CacheManager();
    });

    test('场景1: 多个Screen dispose导致的连接关闭问题', () async {
      print('\n=== 测试场景1: 多个Screen dispose问题 ===');

      // 模拟应用初始化
      try {
        await apiWrapper.init();
        print('✓ API服务初始化成功');
      } catch (e) {
        print('⚠️ API服务初始化失败 (正常，测试环境): $e');
        return;
      }

      // 获取Dio实例引用
      final dioBeforeDispose = apiWrapper.dio;

      // 模拟多个Screen依次调用dispose
      print('📱 模拟Screen A dispose...');
      apiWrapper.dispose();

      print('📱 模拟Screen B dispose...');
      apiWrapper.dispose();

      print('📱 模拟Screen C dispose...');
      apiWrapper.dispose();

      // 尝试进行网络请求
      try {
        await apiWrapper.searchNovels('test');
        print('❌ 预期应该失败，但请求成功了');
      } catch (e) {
        print('✓ 请求失败，符合预期: $e');

        // 检查是否包含连接关闭的错误信息
        if (e.toString().contains('closed') ||
            e.toString().contains('establish a new connection')) {
          print('🎯 确认发现了连接关闭的问题！');
        }
      }
    });

    test('场景2: 并发请求下的连接池竞争', () async {
      print('\n=== 测试场景2: 并发连接池竞争 ===');

      try {
        await apiWrapper.init();
      } catch (e) {
        print('⚠️ 跳过并发测试，API初始化失败: $e');
        return;
      }

      // 创建多个并发请求
      final futures = <Future>[];
      print('🔄 启动20个并发请求...');

      for (int i = 0; i < 20; i++) {
        futures.add(
          apiWrapper.searchNovels('test$i').catchError((e) {
            print('❌ 请求 $i 失败: $e');
            return e;
          })
        );
      }

      // 等待所有请求完成
      final results = await Future.wait(futures);

      // 统计失败数量
      final failures = results.where((r) => r is Exception).length;
      print('📊 并发测试结果: ${results.length} 个请求，$failures 个失败');

      if (failures > 0) {
        print('🎯 发现并发请求问题！');
      }
    });

    test('场景3: 应用生命周期切换对连接的影响', () async {
      print('\n=== 测试场景3: 应用生命周期影响 ===');

      try {
        await apiWrapper.init();
      } catch (e) {
        print('⚠️ 跳过生命周期测试，API初始化失败: $e');
        return;
      }

      // 模拟应用活跃状态
      print('📱 应用进入前台...');
      cacheManager.setAppActive(true);

      // 等待缓存管理器启动
      await Future.delayed(Duration(milliseconds: 100));

      // 模拟应用进入后台
      print('📱 应用进入后台...');
      cacheManager.setAppActive(false);

      // 模拟应用快速切换回前台
      print('📱 应用快速回到前台...');
      cacheManager.setAppActive(true);

      // 尝试进行请求
      try {
        await apiWrapper.searchNovels('test');
        print('✓ 生命周期切换后请求正常');
      } catch (e) {
        print('❌ 生命周期切换后请求失败: $e');

        if (e.toString().contains('closed') ||
            e.toString().contains('establish a new connection')) {
          print('🎯 生命周期切换导致连接问题！');
        }
      }
    });

    test('场景4: 连接池配置压力测试', () async {
      print('\n=== 测试场景4: 连接池压力测试 ===');

      try {
        await apiWrapper.init();
      } catch (e) {
        print('⚠️ 跳过压力测试，API初始化失败: $e');
        return;
      }

      // 获取Dio实例检查配置
      final dio = apiWrapper.dio;
      print('🔧 当前Dio配置:');
      print('  - 连接超时: ${dio.options.connectTimeout}');
      print('  - 接收超时: ${dio.options.receiveTimeout}');
      print('  - 发送超时: ${dio.options.sendTimeout}');

      // 模拟大量连接同时建立
      final futures = <Future>[];
      print('🚀 启动100个并发连接测试...');

      for (int i = 0; i < 100; i++) {
        futures.add(
          apiWrapper.searchNovels('stress_test_$i').timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('⏰ 请求 $i 超时');
              return 'timeout';
            }
          ).catchError((e) {
            print('💥 请求 $i 异常: ${e.toString().substring(0, 50)}...');
            return e;
          })
        );
      }

      final results = await Future.wait(futures);

      final timeouts = results.where((r) => r == 'timeout').length;
      final errors = results.where((r) => r is Exception).length;
      final success = results.length - timeouts - errors;

      print('📊 压力测试结果:');
      print('  - 成功: $success');
      print('  - 超时: $timeouts');
      print('  - 错误: $errors');

      if (timeouts > 10 || errors > 10) {
        print('🎯 连接池配置可能存在问题！');
      }
    });

    test('场景5: 内存泄漏和资源清理检查', () async {
      print('\n=== 测试场景5: 资源清理检查 ===');

      ApiServiceWrapper? testWrapper;

      // 创建多个API包装器实例并检查资源
      for (int i = 0; i < 5; i++) {
        testWrapper = ApiServiceWrapper();
        try {
          await testWrapper.init();
          print('✓ 实例 $i 初始化成功');
        } catch (e) {
          print('⚠️ 实例 $i 初始化失败: $e');
        }

        // 立即dispose
        testWrapper.dispose();
        print('🗑️ 实例 $i 已dispose');
      }

      // 强制垃圾回收
      print('🗑️ 执行垃圾回收...');
      // 注意：在测试环境中，我们无法强制执行真正的垃圾回收

      print('✓ 资源清理测试完成');
    });

    tearDown(() {
      // 清理测试资源
      cacheManager.dispose();
      apiWrapper.dispose();
    });
  });

  group('Dio 配置分析', () {
    test('分析当前Dio配置的问题', () async {
      print('\n=== Dio配置分析 ===');

      final apiWrapper = ApiServiceWrapper();

      try {
        await apiWrapper.init();
        final dio = apiWrapper.dio;

        print('📋 当前配置:');
        print('  - BaseURL: ${dio.options.baseUrl}');
        print('  - ConnectTimeout: ${dio.options.connectTimeout}');
        print('  - ReceiveTimeout: ${dio.options.receiveTimeout}');
        print('  - SendTimeout: ${dio.options.sendTimeout}');

        // 检查连接池配置
        if (dio.httpClientAdapter is IOHttpClientAdapter) {
          print('  - HttpClientAdapter: IOHttpClientAdapter');
          print('  - 连接池配置: 需要检查maxConnectionsPerHost设置');
        }

        print('\n⚠️ 潜在问题:');
        print('  1. 多个Screen调用dispose()会关闭共享的Dio实例');
        print('  2. 连接池大小(100)可能过大，导致系统资源耗尽');
        print('  3. 空闲超时设置可能过短');
        print('  4. 缺少连接健康检查机制');
        print('  5. 没有自动重连机制');

      } catch (e) {
        print('❌ 无法获取Dio配置: $e');
      } finally {
        apiWrapper.dispose();
      }
    });
  });
}