import '../../services/logger_service.dart';

/// 性能日志记录器
///
/// 自动记录操作耗时，用于性能监控和优化。
///
/// 使用示例:
/// ```dart
/// final perf = PerformanceLogger('数据库备份');
/// try {
///   await backupDatabase();
///   perf.complete();
/// } catch (e, st) {
///   perf.completeWithError(e, st);
/// }
/// ```
///
/// 输出示例：
/// - "数据库备份 完成 (耗时: 1234ms)"
/// - "数据库备份 失败: xxx (耗时: 567ms)"
class PerformanceLogger {
  final String _operation;
  final DateTime _start;
  final LogCategory _category;
  final List<String> _tags;

  PerformanceLogger(
    this._operation, {
    LogCategory category = LogCategory.general,
    List<String> tags = const [],
  })  : _start = DateTime.now(),
        _category = category,
        _tags = tags;

  /// 记录成功完成
  ///
  /// 参数：
  /// - [message] 可选的成功消息（默认："$_operation 完成"）
  void complete([String? message]) {
    final duration = DateTime.now().difference(_start).inMilliseconds;
    final msg = message ?? '$_operation 完成';

    LoggerService.instance.i(
      '$msg (耗时: ${duration}ms)',
      category: _category,
      tags: [..._tags, 'performance'],
    );
  }

  /// 记录失败
  ///
  /// 参数：
  /// - [error] 错误对象
  /// - [stackTrace] 可选的堆栈跟踪
  void completeWithError(Object error, [StackTrace? stackTrace]) {
    final duration = DateTime.now().difference(_start).inMilliseconds;

    LoggerService.instance.e(
      '$_operation 失败: $error (耗时: ${duration}ms)',
      stackTrace: stackTrace?.toString(),
      category: _category,
      tags: [..._tags, 'performance', 'error'],
    );
  }
}
