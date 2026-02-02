import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../lib/services/api_service_wrapper.dart';

/// 连接调试工具
/// 用于深入分析Dio连接问题的根本原因
class ConnectionDebugTool {
  static final ConnectionDebugTool _instance = ConnectionDebugTool._internal();
  factory ConnectionDebugTool() => _instance;
  ConnectionDebugTool._internal();

  final List<ConnectionEvent> _connectionEvents = [];
  Timer? _monitorTimer;
  Dio? _monitoredDio;

  /// 连接事件记录
  void recordEvent(String type, dynamic data) {
    final event = ConnectionEvent(
      timestamp: DateTime.now(),
      type: type,
      data: data,
    );
    _connectionEvents.add(event);

    // 保持最近100个事件
    if (_connectionEvents.length > 100) {
      _connectionEvents.removeAt(0);
    }

    debugPrint('🔗 [${event.timestamp}] $type: $data');
  }

  /// 开始监控连接状态
  void startMonitoring(Dio dio) {
    _monitoredDio = dio;

    recordEvent('MONITOR_START', '开始监控Dio连接');

    // 添加监控拦截器
    dio.interceptors.add(ConnectionMonitorInterceptor(this));

    // 定期检查连接健康状态
    _monitorTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkConnectionHealth();
    });
  }

  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    recordEvent('MONITOR_STOP', '停止监控连接');
  }

  /// 检查连接健康状态
  void _checkConnectionHealth() {
    if (_monitoredDio == null) return;

    try {
      // 检查Dio实例状态
      recordEvent('HEALTH_CHECK', {
        'dio_exists': _monitoredDio != null,
        'interceptors_count': _monitoredDio!.interceptors.length,
        'base_url': _monitoredDio!.options.baseUrl,
      });
    } catch (e) {
      recordEvent('HEALTH_CHECK_ERROR', e);
    }
  }

  /// 模拟常见问题场景
  Future<void> simulateProblemScenarios() async {
    debugPrint('\n🧪 开始模拟问题场景...');

    // 场景1: 快速连续dispose
    await _simulateRapidDispose();

    // 场景2: 并发请求竞争
    await _simulateConcurrentRequests();

    // 场景3: 应用生命周期切换
    await _simulateLifecycleChanges();
  }

  /// 模拟快速连续dispose
  Future<void> _simulateRapidDispose() async {
    debugPrint('\n📱 场景1: 模拟快速连续dispose');

    for (int i = 0; i < 3; i++) {
      final apiWrapper = ApiServiceWrapper();

      try {
        await apiWrapper.init();
        recordEvent('SCENARIO1_INIT', '初始化实例 $i');
      } catch (e) {
        recordEvent('SCENARIO1_INIT_ERROR', '初始化失败 $i: $e');
      }

      // 立即dispose
      apiWrapper.dispose();
      recordEvent('SCENARIO1_DISPOSE', 'Dispose实例 $i');

      // 短暂延迟
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  /// 模拟并发请求竞争
  Future<void> _simulateConcurrentRequests() async {
    debugPrint('\n🚀 场景2: 模拟并发请求竞争');

    final apiWrapper = ApiServiceWrapper();

    try {
      await apiWrapper.init();
      recordEvent('SCENARIO2_INIT', '并发测试初始化成功');

      // 创建50个并发请求
      final futures = <Future>[];

      for (int i = 0; i < 50; i++) {
        futures.add(_makeRequestWithErrorHandling(apiWrapper, i));
      }

      // 等待所有请求完成
      final results = await Future.wait(futures);

      final successCount = results.where((r) => r).length;
      recordEvent('SCENARIO2_RESULT', {
        'total_requests': results.length,
        'success_count': successCount,
        'failure_count': results.length - successCount,
      });
    } catch (e) {
      recordEvent('SCENARIO2_ERROR', '并发测试失败: $e');
    } finally {
      apiWrapper.dispose();
    }
  }

  /// 带错误处理的请求
  Future<bool> _makeRequestWithErrorHandling(
      ApiServiceWrapper apiWrapper, int requestId) async {
    try {
      await apiWrapper.searchNovels('concurrent_test_$requestId');
      recordEvent('SCENARIO2_REQUEST_SUCCESS', '请求 $requestId 成功');
      return true;
    } catch (e) {
      recordEvent('SCENARIO2_REQUEST_ERROR', {
        'request_id': requestId,
        'error': e.toString(),
        'is_connection_error': _isConnectionError(e),
      });
      return false;
    }
  }

  /// 模拟应用生命周期切换
  Future<void> _simulateLifecycleChanges() async {
    debugPrint('\n🔄 场景3: 模拟应用生命周期切换');

    final apiWrapper = ApiServiceWrapper();

    try {
      await apiWrapper.init();
      recordEvent('SCENARIO3_INIT', '生命周期测试初始化成功');

      // 模拟应用进入后台
      recordEvent('SCENARIO3_BACKGROUND', '应用进入后台');

      // 模拟应用快速回到前台
      await Future.delayed(Duration(milliseconds: 200));
      recordEvent('SCENARIO3_FOREGROUND', '应用回到前台');

      // 尝试请求
      try {
        await apiWrapper.searchNovels('lifecycle_test');
        recordEvent('SCENARIO3_REQUEST_SUCCESS', '生命周期切换后请求成功');
      } catch (e) {
        recordEvent('SCENARIO3_REQUEST_ERROR', {
          'error': e.toString(),
          'is_connection_error': _isConnectionError(e),
        });
      }
    } catch (e) {
      recordEvent('SCENARIO3_ERROR', '生命周期测试失败: $e');
    } finally {
      apiWrapper.dispose();
    }
  }

  /// 检查是否为连接错误
  bool _isConnectionError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('closed') ||
        errorStr.contains('connection') ||
        errorStr.contains('establish') ||
        errorStr.contains('dio') ||
        errorStr.contains('socket');
  }

  /// 生成分析报告
  void generateReport() {
    debugPrint('\n📊 === 连接问题分析报告 ===');

    // 统计各类事件
    final eventCounts = <String, int>{};
    final connectionErrors = <ConnectionEvent>[];

    for (final event in _connectionEvents) {
      eventCounts[event.type] = (eventCounts[event.type] ?? 0) + 1;

      if (event.type.contains('ERROR') && _isConnectionError(event.data)) {
        connectionErrors.add(event);
      }
    }

    debugPrint('\n📈 事件统计:');
    eventCounts.forEach((type, count) {
      debugPrint('  $type: $count');
    });

    debugPrint('\n❌ 连接错误详情:');
    for (final error in connectionErrors) {
      debugPrint('  [${error.timestamp}] ${error.data}');
    }

    // 分析问题模式
    _analyzeProblemPatterns(connectionErrors);

    debugPrint('\n💡 建议修复方案:');
    _generateRecommendations(connectionErrors);
  }

  /// 分析问题模式
  void _analyzeProblemPatterns(List<ConnectionEvent> errors) {
    if (errors.isEmpty) {
      debugPrint('  ✅ 未发现连接错误');
      return;
    }

    debugPrint('  🔍 问题模式分析:');

    // 检查是否有dispose后的请求
    final disposeErrors = errors
        .where((e) =>
            e.toString().contains('dispose') || e.toString().contains('closed'))
        .length;

    if (disposeErrors > 0) {
      debugPrint('    - 发现 $disposeErrors 个dispose后请求错误');
    }

    // 检查并发问题
    final concurrentErrors = errors
        .where((e) =>
            e.type.contains('CONCURRENT') || e.type.contains('SCENARIO2'))
        .length;

    if (concurrentErrors > 0) {
      debugPrint('    - 发现 $concurrentErrors 个并发相关错误');
    }

    // 检查生命周期问题
    final lifecycleErrors = errors
        .where(
            (e) => e.type.contains('LIFECYCLE') || e.type.contains('SCENARIO3'))
        .length;

    if (lifecycleErrors > 0) {
      debugPrint('    - 发现 $lifecycleErrors 个生命周期相关错误');
    }
  }

  /// 生成修复建议
  void _generateRecommendations(List<ConnectionEvent> errors) {
    debugPrint('    1. 🏗️ 实现连接池管理器，避免Dio实例被过早关闭');
    debugPrint('    2. 🔄 添加连接健康检查和自动重连机制');
    debugPrint('    3. 🚫 移除各Screen中的api.dispose()调用');
    debugPrint('    4. ⚙️ 优化连接池配置（减少maxConnectionsPerHost）');
    debugPrint('    5. 📱 实现应用生命周期感知的连接管理');
    debugPrint('    6. 🛡️ 添加请求重试和熔断机制');
    debugPrint('    7. 📊 实现连接状态监控和日志记录');
  }

  /// 清理资源
  void dispose() {
    stopMonitoring();
    _connectionEvents.clear();
    _monitoredDio = null;
  }
}

/// 连接事件
class ConnectionEvent {
  final DateTime timestamp;
  final String type;
  final dynamic data;

  ConnectionEvent({
    required this.timestamp,
    required this.type,
    required this.data,
  });

  @override
  String toString() {
    return 'ConnectionEvent{timestamp: $timestamp, type: $type, data: $data}';
  }
}

/// 连接监控拦截器
class ConnectionMonitorInterceptor extends Interceptor {
  final ConnectionDebugTool debugTool;

  ConnectionMonitorInterceptor(this.debugTool);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugTool.recordEvent('REQUEST_START', {
      'url': options.uri.toString(),
      'method': options.method,
    });
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugTool.recordEvent('RESPONSE_SUCCESS', {
      'status_code': response.statusCode,
      'url': response.requestOptions.uri.toString(),
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugTool.recordEvent('RESPONSE_ERROR', {
      'error_type': err.type.toString(),
      'message': err.message,
      'url': err.requestOptions.uri.toString(),
    });
    handler.next(err);
  }
}

/// 主测试函数
Future<void> runConnectionDebug() async {
  debugPrint('🔧 启动连接调试工具...');

  final debugTool = ConnectionDebugTool();

  try {
    // 初始化API服务并开始监控
    final apiWrapper = ApiServiceWrapper();
    await apiWrapper.init();

    debugTool.startMonitoring(apiWrapper.dio);

    // 等待监控稳定
    await Future.delayed(Duration(seconds: 2));

    // 模拟问题场景
    await debugTool.simulateProblemScenarios();

    // 等待所有事件记录完成
    await Future.delayed(Duration(seconds: 3));

    // 生成分析报告
    debugTool.generateReport();

    apiWrapper.dispose();
  } catch (e) {
    debugPrint('❌ 调试工具运行失败: $e');
  } finally {
    debugTool.dispose();
  }

  debugPrint('✅ 连接调试工具运行完成');
}
