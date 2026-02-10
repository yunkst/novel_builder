import 'dart:math';
import '../../services/logger_service.dart';

/// 关联ID日志追踪器
///
/// 支持全链路追踪，通过唯一的correlation_id关联所有相关日志。
///
/// 使用示例:
/// ```dart
/// // 开始一个新的关联操作
/// final correlationId = CorrelationLogger.start();
///
/// // 在所有相关日志中使用关联标签
/// LoggerService.instance.i('开始处理', tags: ['corr:$correlationId']);
///
/// // ... 其他操作
/// LoggerService.instance.i('处理中', tags: ['corr:$correlationId']);
///
/// // 结束关联操作
/// CorrelationLogger.end(correlationId);
///
/// // 查询时可以通过标签过滤所有相关日志
/// final logs = LoggerService.instance.getLogsByTag('corr:$correlationId');
/// ```
class CorrelationLogger {
  static String? _currentId;

  /// 开始新的关联操作
  ///
  /// 返回一个唯一的关联ID，格式：{timestamp}-{random}
  /// 例如："1706712000000-1234"
  static String start() {
    _currentId ??=
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(10000)}';
    LoggerService.instance.d(
      '关联操作开始',
      tags: ['correlation', 'start', 'corr:$_currentId'],
    );
    return _currentId!;
  }

  /// 结束关联操作
  ///
  /// 参数：
  /// - [correlationId] 可选的关联ID，如果不提供则使用当前ID
  static void end([String? correlationId]) {
    final id = correlationId ?? _currentId;
    LoggerService.instance.d(
      '关联操作结束',
      tags: ['correlation', 'end', if (id != null) 'corr:$id'],
    );
    if (id == _currentId) {
      _currentId = null;
    }
  }

  /// 获取当前关联ID
  static String? get currentId => _currentId;

  /// 为标签列表添加关联ID
  ///
  /// 使用示例：
  /// ```dart
  /// final tags = CorrelationLogger.withCorrelation(['api', 'request']);
  /// LoggerService.instance.i('请求中', tags: tags);
  /// ```
  static List<String> withCorrelation(List<String> tags) {
    if (_currentId == null) return tags;
    return [...tags, 'corr:$_currentId'];
  }

  /// 检查是否有活跃的关联操作
  static bool get hasActiveCorrelation => _currentId != null;
}
