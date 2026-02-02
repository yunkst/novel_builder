import 'dart:async';
import '../../services/logger_service.dart';

/// 日志作用域 - 聚合相关日志为单个事件
///
/// 使用示例:
/// ```dart
/// return LogScope.capture(
///   name: '重新生成场景插图',
///   category: LogCategory.network,
///   tags: ['api', 'scene_illustration'],
///   context: {
///     'taskId': taskId,
///     'count': count,
///   },
///   action: () async {
///     // ... 业务逻辑
///     return result;
///   },
/// );
/// ```
///
/// 效果：
/// Before: 18条碎片化日志
/// After: 1条聚合日志 "重新生成场景插图 完成 (taskId=xxx, count=3)"
class LogScope {
  final String name;
  final LogCategory category;
  final List<String> tags;
  final DateTime startTime;
  final Map<String, dynamic> _context = {};

  LogScope({
    required this.name,
    required this.category,
    this.tags = const [],
  }) : startTime = DateTime.now();

  /// 添加上下文信息
  void addContext(String key, dynamic value) {
    _context[key] = value;
  }

  /// 执行操作并自动记录
  ///
  /// 参数：
  /// - [name] 操作名称
  /// - [category] 日志分类
  /// - [tags] 日志标签
  /// - [action] 要执行的操作
  /// - [context] 可选的上下文信息（键值对）
  ///
  /// 返回：操作的结果
  ///
  /// 抛出：如果操作失败，重新抛出异常
  static Future<T> capture<T>({
    required String name,
    required LogCategory category,
    required List<String> tags,
    required Future<T> Function() action,
    Map<String, dynamic>? context,
  }) async {
    final scope = LogScope(name: name, category: category, tags: tags);
    if (context != null) {
      scope._context.addAll(context);
    }

    try {
      final result = await action();
      scope._logSuccess(result);
      return result;
    } catch (e, stackTrace) {
      scope._logFailure(e, stackTrace);
      rethrow;
    }
  }

  void _logSuccess([dynamic result]) {
    final duration = DateTime.now().difference(startTime);

    final message =
        _context.isNotEmpty ? '$name 完成 (${_formatContext()})' : '$name 完成';

    // 如果耗时超过1秒，在消息中显示
    final finalMessage = duration.inSeconds >= 1
        ? '$message (耗时: ${duration.inSeconds}s)'
        : message;

    LoggerService.instance.i(
      finalMessage,
      category: category,
      tags: [...tags, 'success'],
    );
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    final duration = DateTime.now().difference(startTime);

    final message = _context.isNotEmpty
        ? '$name 失败: $error (${_formatContext()})'
        : '$name 失败: $error';

    final finalMessage = duration.inSeconds >= 1
        ? '$message (耗时: ${duration.inSeconds}s)'
        : message;

    LoggerService.instance.e(
      finalMessage,
      stackTrace: stackTrace.toString(),
      category: category,
      tags: [...tags, 'error'],
    );
  }

  String _formatContext() {
    if (_context.isEmpty) return '';

    final entries =
        _context.entries.map((e) => '${e.key}=${e.value}').join(', ');
    return entries;
  }
}
