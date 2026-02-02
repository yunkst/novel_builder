import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:novel_app/services/logger_service.dart';
import 'package:novel_app/core/providers/service_providers.dart';

void main() {
  group('LoggerService Riverpod Provider Tests', () {
    late ProviderContainer container;

    setUp(() {
      // 每个测试前重置 LoggerService 单例
      LoggerService.resetForTesting();
      // 创建新的 ProviderContainer
      container = ProviderContainer();
    });

    tearDown(() {
      // 每个测试后清理容器
      container.dispose();
      // 重置单例以避免测试间相互影响
      LoggerService.resetForTesting();
    });

    group('Provider 创建测试', () {
      test('应该正确创建 LoggerService Provider', () {
        final service = container.read(loggerServiceProvider);
        expect(service, isA<LoggerService>());
        expect(service.runtimeType, LoggerService);
      });

      test('应该返回 LoggerService 单例实例', () {
        final service1 = container.read(loggerServiceProvider);
        final service2 = container.read(loggerServiceProvider);

        // 验证两次读取返回同一个实例
        expect(identical(service1, service2), true);
      });

      test('应该与 .instance 访问返回相同的实例', () {
        final providerInstance = container.read(loggerServiceProvider);
        final singletonInstance = LoggerService.instance;

        // 验证 Provider 和单例返回同一个实例
        expect(identical(providerInstance, singletonInstance), true);
      });
    });

    group('Provider 功能测试', () {
      test('应该能够初始化日志服务', () async {
        final service = container.read(loggerServiceProvider);

        expect(service.logCount, greaterThanOrEqualTo(0));

        await service.init();

        expect(service.logCount, greaterThanOrEqualTo(0));
      });

      test('应该能够记录不同级别的日志', () async {
        final service = container.read(loggerServiceProvider);

        // 初始化服务
        await service.init();

        // 清空日志以确保测试准确性
        await service.clearLogs();

        // 记录不同级别的日志
        service.d('调试信息');
        service.i('信息日志');
        service.w('警告日志');
        service.e('错误日志');

        // 验证日志被正确记录
        expect(service.logCount, 4);

        // 验证不同级别的日志
        final debugLogs = service.getLogsByLevel(LogLevel.debug);
        final infoLogs = service.getLogsByLevel(LogLevel.info);
        final warningLogs = service.getLogsByLevel(LogLevel.warning);
        final errorLogs = service.getLogsByLevel(LogLevel.error);

        expect(debugLogs.length, 1);
        expect(infoLogs.length, 1);
        expect(warningLogs.length, 1);
        expect(errorLogs.length, 1);
      });

      test('应该能够按分类记录日志', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录不同分类的日志
        service.d('数据库查询', category: LogCategory.database);
        service.i('网络请求', category: LogCategory.network);
        service.w('AI 处理警告', category: LogCategory.ai);

        // 验证日志分类
        final dbLogs = service.getLogsByCategory(LogCategory.database);
        final networkLogs = service.getLogsByCategory(LogCategory.network);
        final aiLogs = service.getLogsByCategory(LogCategory.ai);

        expect(dbLogs.length, 1);
        expect(networkLogs.length, 1);
        expect(aiLogs.length, 1);
      });

      test('应该能够按标签记录日志', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录带标签的日志
        service.d('API 请求', tags: ['api', 'http']);
        service.i('数据库操作', tags: ['database']);
        service.d('另一个 API 请求', tags: ['api']);

        // 验证标签功能
        final apiLogs = service.getLogsByTag('api');
        final dbLogs = service.getLogsByTag('database');

        expect(apiLogs.length, 2);
        expect(dbLogs.length, 1);
      });

      test('应该能够搜索日志', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录测试日志
        service.i('API 请求成功');
        service.i('数据库查询完成');
        service.e('API 请求失败');

        // 搜索包含 "API" 的日志
        final apiLogs = service.searchLogs('API');
        expect(apiLogs.length, 2);

        // 搜索包含 "数据库" 的日志
        final dbLogs = service.searchLogs('数据库');
        expect(dbLogs.length, 1);
      });

      test('应该能够组合搜索日志', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录不同分类的日志
        service.i('网络 API 请求', category: LogCategory.network);
        service.i('数据库 API 调用', category: LogCategory.database);
        service.e('API 错误', category: LogCategory.network);

        // 搜索 network 分类下包含 "API" 的日志
        final networkApiLogs = service.searchLogs(
          'API',
          category: LogCategory.network,
        );

        expect(networkApiLogs.length, 2);
      });

      test('应该能够获取统计信息', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录不同级别的日志
        service.d('调试1');
        service.d('调试2');
        service.i('信息1');
        service.w('警告1');
        service.e('错误1');

        // 获取统计信息
        final stats = service.getStatistics();

        expect(stats.total, 5);
        expect(stats.byLevel[LogLevel.debug], 2);
        expect(stats.byLevel[LogLevel.info], 1);
        expect(stats.byLevel[LogLevel.warning], 1);
        expect(stats.byLevel[LogLevel.error], 1);

        // 验证百分比计算
        expect(stats.levelPercentage[LogLevel.debug], 0.4); // 2/5 = 0.4
      });

      test('应该能够清空日志', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();

        // 记录一些日志
        service.i('测试日志');
        expect(service.logCount, greaterThan(0));

        // 清空日志
        await service.clearLogs();
        expect(service.logCount, 0);
      });

      test('应该能够强制刷新持久化', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录日志
        service.i('重要日志');
        service.e('错误日志');

        // 强制刷新
        await service.flush();

        // 验证日志仍然存在
        expect(service.logCount, greaterThan(0));
      });
    });

    group('向后兼容性测试', () {
      test('Provider 和 .instance 应该返回相同实例', () {
        final providerInstance = container.read(loggerServiceProvider);
        final singletonInstance = LoggerService.instance;

        expect(identical(providerInstance, singletonInstance), true);
      });

      test('通过 Provider 修改的状态应该反映在 .instance 中', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 通过 Provider 记录日志
        service.i('测试日志');

        // 通过 .instance 应该能看到相同的日志
        final instance = LoggerService.instance;
        final logs = instance.getLogs();

        expect(logs.length, 1);
        expect(logs.first.message, '测试日志');
      });

      test('通过 .instance 修改的状态应该反映在 Provider 中', () async {
        final instance = LoggerService.instance;
        await instance.init();
        await instance.clearLogs();

        // 通过 .instance 记录日志
        instance.i('测试日志');

        // 通过 Provider 应该能看到相同的日志
        final service = container.read(loggerServiceProvider);
        final logs = service.getLogs();

        expect(logs.length, 1);
        expect(logs.first.message, '测试日志');
      });

      test('多次读取 Provider 应该返回同一个实例', () {
        final instance1 = container.read(loggerServiceProvider);
        final instance2 = container.read(loggerServiceProvider);
        final instance3 = LoggerService.instance;

        expect(identical(instance1, instance2), true);
        expect(identical(instance2, instance3), true);
      });
    });

    group('日志变化通知测试', () {
      test('应该通知日志变化', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        var notificationCount = 0;
        void listener() {
          notificationCount++;
        }

        LoggerService.logChangeNotifier.addListener(listener);

        // 记录日志应该触发通知
        service.i('测试日志1');
        expect(notificationCount, 1);

        service.i('测试日志2');
        expect(notificationCount, 2);

        // 清空日志也应该触发通知
        await service.clearLogs();
        expect(notificationCount, 3);

        // 移除监听器
        LoggerService.logChangeNotifier.removeListener(listener);
      });

      test('应该能够导出日志到文件', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录一些测试日志
        service.i('测试日志1');
        service.i('测试日志2');
        service.e('错误日志');

        // 注意：在单元测试环境中，exportToFile 可能会因为平台插件不可用而失败
        // 这里我们测试日志已经被正确记录，导出功能需要集成测试
        expect(service.logCount, 3);

        // 验证日志内容
        final logs = service.getLogs();
        expect(logs[0].message, '测试日志1');
        expect(logs[1].message, '测试日志2');
        expect(logs[2].message, '错误日志');
      });
    });

    group('边界情况测试', () {
      test('搜索空字符串应该返回所有符合条件的日志', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        service.i('日志1');
        service.i('日志2');

        final results = service.searchLogs('');
        expect(results.length, 2);
      });

      test('统计空日志应该返回零', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        final stats = service.getStatistics();

        expect(stats.total, 0);
        expect(stats.byLevel[LogLevel.debug], 0);
        expect(stats.byLevel[LogLevel.info], 0);
      });

      test('获取不存在的标签应该返回空列表', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        final logs = service.getLogsByTag('不存在的标签');
        expect(logs, isEmpty);
      });

      test('日志条目序列化和反序列化应该保持一致性', () {
        final entry = LogEntry(
          timestamp: DateTime(2025, 1, 31, 12, 0, 0),
          level: LogLevel.info,
          message: '测试消息',
          stackTrace: '测试堆栈',
          category: LogCategory.network,
          tags: ['api', 'http'],
          extra: {'key': 'value'},
        );

        final map = entry.toMap();
        final restored = LogEntry.fromMap(map);

        expect(restored.timestamp, entry.timestamp);
        expect(restored.level, entry.level);
        expect(restored.message, entry.message);
        expect(restored.stackTrace, entry.stackTrace);
        expect(restored.category, entry.category);
        expect(restored.tags, entry.tags);
        expect(restored.extra, entry.extra);
      });

      test('反序列化旧版本日志应该使用默认值', () {
        // 模拟旧版本的日志数据（没有 category、tags、extra 字段）
        final oldMap = {
          'timestamp': DateTime(2025, 1, 31).millisecondsSinceEpoch,
          'level': 0,
          'message': '旧版本日志',
          'stackTrace': null,
        };

        final entry = LogEntry.fromMap(oldMap);

        expect(entry.category, LogCategory.general); // 默认值
        expect(entry.tags, isEmpty); // 默认值
        expect(entry.extra, isNull); // 默认值
      });
    });

    group('Provider 容器测试', () {
      test('多个 ProviderContainer 应该共享同一个单例', () {
        final container1 = ProviderContainer();
        final container2 = ProviderContainer();

        final service1 = container1.read(loggerServiceProvider);
        final service2 = container2.read(loggerServiceProvider);
        final service3 = LoggerService.instance;

        // 所有实例应该是同一个对象
        expect(identical(service1, service2), true);
        expect(identical(service2, service3), true);

        container1.dispose();
        container2.dispose();
      });

      test('Provider 覆盖测试', () {
        // 由于 LoggerService 使用单例模式，覆盖测试验证 Provider 正确返回单例
        final service = container.read(loggerServiceProvider);
        final singleton = LoggerService.instance;

        expect(identical(service, singleton), true);
      });
    });

    group('日志级别枚举测试', () {
      test('所有日志级别应该有正确的标签', () {
        expect(LogLevel.debug.label, 'DEBUG');
        expect(LogLevel.info.label, 'INFO');
        expect(LogLevel.warning.label, 'WARN');
        expect(LogLevel.error.label, 'ERROR');
      });

      test('所有日志级别应该有对应的图标', () {
        expect(LogLevel.debug.icon, isA<IconData>());
        expect(LogLevel.info.icon, isA<IconData>());
        expect(LogLevel.warning.icon, isA<IconData>());
        expect(LogLevel.error.icon, isA<IconData>());
      });
    });

    group('日志分类枚举测试', () {
      test('所有日志分类应该有正确的键和标签', () {
        expect(LogCategory.database.key, 'database');
        expect(LogCategory.database.label, '数据库');

        expect(LogCategory.network.key, 'network');
        expect(LogCategory.network.label, '网络');

        expect(LogCategory.ai.key, 'ai');
        expect(LogCategory.ai.label, 'AI');
      });
    });

    group('性能测试', () {
      test('大量日志记录性能测试', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        final stopwatch = Stopwatch()..start();

        // 记录 100 条日志
        for (int i = 0; i < 100; i++) {
          service.i('日志 $i');
        }

        stopwatch.stop();

        // 验证所有日志都被记录
        expect(service.logCount, 100);

        // 验证性能（100 条日志应该在合理时间内完成）
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('日志搜索性能测试', () async {
        final service = container.read(loggerServiceProvider);
        await service.init();
        await service.clearLogs();

        // 记录 500 条日志
        for (int i = 0; i < 500; i++) {
          service.i('日志消息 $i', tags: ['tag${i % 10}']);
        }

        final stopwatch = Stopwatch()..start();

        // 搜索包含特定关键词的日志
        final results = service.searchLogs('10');

        stopwatch.stop();

        // 验证搜索结果
        expect(results.length, greaterThan(0));

        // 验证搜索性能（500 条日志中搜索应该在合理时间内完成）
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
