# LoggerService 增强与规范化实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 增强现有 LoggerService 功能并统一项目日志使用规范，解决 LoggerService 和 debugPrint 混用问题。

**架构:** 增强现有 LoggerService 添加分类、标签、搜索、统计功能，制定日志使用规范，逐步迁移关键路径日志。

**技术栈:**
- Dart/Flutter
- SharedPreferences (持久化)
- path_provider (文件导出)

**参考资料:**
- 现有实现: `lib/services/logger_service.dart`
- 日志查看界面: `lib/screens/log_viewer_screen.dart`
- 当前日志使用情况: LoggerService 21次 vs debugPrint 976次

---

## 阶段一：增强 LoggerService 功能

### Task 1: 添加日志分类系统

**目标:** 为日志添加分类标签，便于按功能模块筛选和分析日志。

**文件:**
- Modify: `lib/services/logger_service.dart:40-88`
- Test: `test/unit/services/logger_service_test.dart` (创建)

**Step 1: 添加 LogCategory 枚举**

在 `LogLevel` 枚举后添加 `LogCategory` 枚举:

```dart
/// 日志分类
enum LogCategory {
  /// 数据库操作
  database('数据库', 'database'),

  /// 网络请求
  network('网络', 'network'),

  /// AI功能
  ai('AI', 'ai'),

  /// UI交互
  ui('界面', 'ui'),

  /// 缓存管理
  cache('缓存', 'cache'),

  /// TTS播放
  tts('语音', 'tts'),

  /// 角色管理
  character('角色', 'character'),

  /// 通用/未分类
  general('通用', 'general');

  final String label;
  final String key;

  const LogCategory(this.label, this.key);
}
```

**Step 2: 扩展 LogEntry 模型**

在 `LogEntry` 类中添加 `category` 和 `tags` 字段:

```dart
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? stackTrace;
  final LogCategory category;  // 新增
  final List<String> tags;      // 新增

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
    this.category = LogCategory.general,  // 默认值
    this.tags = const [],                  // 默认值
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'level': level.index,
      'message': message,
      'stackTrace': stackTrace,
      'category': category.index,         // 新增
      'tags': tags,                        // 新增
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      level: LogLevel.values[map['level'] as int],
      message: map['message'] as String,
      stackTrace: map['stackTrace'] as String?,
      category: map.containsKey('category')              // 向后兼容
          ? LogCategory.values[map['category'] as int]
          : LogCategory.general,
      tags: map.containsKey('tags')                       // 向后兼容
          ? List<String>.from(map['tags'] as List)
          : const [],
    );
  }
}
```

**Step 3: 修改日志记录方法签名**

更新 `_log` 方法支持分类和标签:

```dart
void _log(
  String message,
  LogLevel level, [
  String? stackTrace,
  LogCategory category = LogCategory.general,
  List<String> tags = const [],
]) {
  final entry = LogEntry(
    timestamp: DateTime.now(),
    level: level,
    message: message,
    stackTrace: stackTrace,
    category: category,
    tags: tags,
  );

  _logs.add(entry);

  if (_logs.length > _maxLogs) {
    _logs.removeAt(0);
  }

  logChangeNotifier.value++;
  _schedulePersist();
}
```

**Step 4: 添加便捷方法**

为每个日志级别添加带分类的重载方法:

```dart
// 带分类的调试日志
void d(
  String message, {
  String? stackTrace,
  LogCategory category = LogCategory.general,
  List<String> tags = const [],
}) {
  _log(message, LogLevel.debug, stackTrace, category, tags);
}

// 其他级别同理...
void i(String message, {String? stackTrace, LogCategory category = LogCategory.general, List<String> tags = const []}) {
  _log(message, LogLevel.info, stackTrace, category, tags);
}

void w(String message, {String? stackTrace, LogCategory category = LogCategory.general, List<String> tags = const []}) {
  _log(message, LogLevel.warning, stackTrace, category, tags);
}

void e(String message, {String? stackTrace, LogCategory category = LogCategory.general, List<String> tags = const []}) {
  _log(message, LogLevel.error, stackTrace, category, tags);
}
```

**Step 5: 编写测试**

创建 `test/unit/services/logger_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/logger_service.dart';
import '../../test_bootstrap.dart';

void main() {
  // 初始化测试环境
  initDatabaseTests();

  group('LoggerService 日志分类功能', () {
    setUp(() async {
      await TestHelpers.initLoggerService();
    });

    tearDown(() async {
      await TestHelpers.clearLoggerService();
    });

    test('应正确记录日志分类', () async {
      LoggerService.instance.i(
        '测试消息',
        category: LogCategory.database,
      );

      final logs = LoggerService.instance.getLogs();
      expect(logs, hasLength(1));
      expect(logs.first.category, LogCategory.database);
    });

    test('应正确记录日志标签', () async {
      LoggerService.instance.e(
        '错误消息',
        category: LogCategory.network,
        tags: ['timeout', 'api'],
      );

      final logs = LoggerService.instance.getLogs();
      expect(logs.first.tags, contains('timeout'));
      expect(logs.first.tags, contains('api'));
    });

    test('默认分类应为general', () async {
      LoggerService.instance.d('消息');

      final logs = LoggerService.instance.getLogs();
      expect(logs.first.category, LogCategory.general);
      expect(logs.first.tags, isEmpty);
    });
  });
}
```

**Step 6: 运行测试**

```bash
cd novel_app
flutter test test/unit/services/logger_service_test.dart
```

预期: 所有测试通过

**Step 7: 提交**

```bash
git add lib/services/logger_service.dart test/unit/services/logger_service_test.dart
git commit -m "feat(logger): 添加日志分类和标签系统"
```

---

### Task 2: 添加日志搜索功能

**目标:** 支持按关键词、分类、标签组合搜索日志。

**文件:**
- Modify: `lib/services/logger_service.dart:261-294`
- Modify: `test/unit/services/logger_service_test.dart`

**Step 1: 添加搜索方法**

在 `LoggerService` 类中添加搜索方法:

```dart
/// 按关键词搜索日志
///
/// 参数:
/// - [query] 搜索关键词，支持消息内容和标签匹配
/// - [category] 可选，限定在特定分类中搜索
List<LogEntry> searchLogs(String query, {LogCategory? category}) {
  var results = _logs;

  // 按分类过滤
  if (category != null) {
    results = results.where((log) => log.category == category).toList();
  }

  // 按关键词搜索
  if (query.isNotEmpty) {
    final lowerQuery = query.toLowerCase();
    results = results.where((log) {
      // 搜索消息内容
      if (log.message.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // 搜索标签
      if (log.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))) {
        return true;
      }

      return false;
    }).toList();
  }

  return results;
}

/// 按分类获取日志
List<LogEntry> getLogsByCategory(LogCategory category) {
  return _logs.where((log) => log.category == category).toList();
}

/// 按标签获取日志
List<LogEntry> getLogsByTag(String tag) {
  return _logs.where((log) => log.tags.contains(tag)).toList();
}
```

**Step 2: 编写测试**

在 `logger_service_test.dart` 中添加:

```dart
group('LoggerService 搜索功能', () {
  setUp(() async {
    await TestHelpers.initLoggerService();

    // 准备测试数据
    LoggerService.instance.i('数据库连接成功', category: LogCategory.database, tags: ['connection']);
    LoggerService.instance.e('网络超时', category: LogCategory.network, tags: ['timeout', 'api']);
    LoggerService.instance.w('API限流', category: LogCategory.network, tags: ['api']);
    LoggerService.instance.d('缓存清理完成', category: LogCategory.cache);
  });

  tearDown(() async {
    await TestHelpers.clearLoggerService();
  });

  test('应能按关键词搜索消息', () {
    final results = LoggerService.instance.searchLogs('网络');

    expect(results, hasLength(2));
    expect(results.any((log) => log.message.contains('超时')), isTrue);
    expect(results.any((log) => log.message.contains('API')), isTrue);
  });

  test('应能按分类搜索', () {
    final results = LoggerService.instance.searchLogs('', category: LogCategory.network);

    expect(results, hasLength(2));
    expect(results.every((log) => log.category == LogCategory.network), isTrue);
  });

  test('应能按标签搜索', () {
    final results = LoggerService.instance.getLogsByTag('api');

    expect(results, hasLength(2));
    expect(results.every((log) => log.tags.contains('api')), isTrue);
  });

  test('应支持关键词和分类组合搜索', () {
    final results = LoggerService.instance.searchLogs('API', category: LogCategory.network);

    expect(results, hasLength(1));
    expect(results.first.message, contains('API'));
  });

  test('空关键词应返回所有日志', () {
    final results = LoggerService.instance.searchLogs('');

    expect(results.length, greaterThan(0));
  });
});
```

**Step 3: 运行测试**

```bash
flutter test test/unit/services/logger_service_test.dart
```

预期: 所有搜索测试通过

**Step 4: 提交**

```bash
git add lib/services/logger_service.dart test/unit/services/logger_service_test.dart
git commit -m "feat(logger): 添加日志搜索功能"
```

---

### Task 3: 添加日志统计功能

**目标:** 提供日志统计数据，了解日志分布和系统健康状况。

**文件:**
- Modify: `lib/services/logger_service.dart:294` (在 logCount 后添加)
- Modify: `test/unit/services/logger_service_test.dart`

**Step 1: 添加统计数据类**

在 `LogEntry` 类后添加统计类:

```dart
/// 日志统计数据
class LogStatistics {
  /// 总日志数
  final int total;

  /// 各级别日志数量
  final Map<LogLevel, int> byLevel;

  /// 各分类日志数量
  final Map<LogCategory, int> byCategory;

  /// 各级别占比
  Map<LogLevel, double> get levelPercentage {
    if (total == 0) return {};
    return byLevel.map((level, count) => MapEntry(level, count / total));
  }

  const LogStatistics({
    required this.total,
    required this.byLevel,
    required this.byCategory,
  });
}
```

**Step 2: 添加统计方法**

在 `LoggerService` 类中添加:

```dart
/// 获取日志统计信息
LogStatistics getStatistics() {
  final byLevel = <LogLevel, int>{};
  final byCategory = <LogCategory, int>{};

  // 初始化计数器
  for (final level in LogLevel.values) {
    byLevel[level] = 0;
  }
  for (final category in LogCategory.values) {
    byCategory[category] = 0;
  }

  // 统计
  for (final log in _logs) {
    byLevel[log.level] = byLevel[log.level]! + 1;
    byCategory[log.category] = byCategory[log.category]! + 1;
  }

  return LogStatistics(
    total: _logs.length,
    byLevel: byLevel,
    byCategory: byCategory,
  );
}
```

**Step 3: 编写测试**

```dart
group('LoggerService 统计功能', () {
  setUp(() async {
    await TestHelpers.initLoggerService();

    // 准备测试数据
    LoggerService.instance.d('调试1', category: LogCategory.database);
    LoggerService.instance.d('调试2', category: LogCategory.network);
    LoggerService.instance.i('信息1', category: LogCategory.database);
    LoggerService.instance.w('警告1', category: LogCategory.ai);
    LoggerService.instance.e('错误1', category: LogCategory.network);
    LoggerService.instance.e('错误2', category: LogCategory.network);
  });

  tearDown(() async {
    await TestHelpers.clearLoggerService();
  });

  test('应正确统计总日志数', () {
    final stats = LoggerService.instance.getStatistics();

    expect(stats.total, 6);
  });

  test('应正确统计各级别日志数', () {
    final stats = LoggerService.instance.getStatistics();

    expect(stats.byLevel[LogLevel.debug], 2);
    expect(stats.byLevel[LogLevel.info], 1);
    expect(stats.byLevel[LogLevel.warning], 1);
    expect(stats.byLevel[LogLevel.error], 2);
  });

  test('应正确统计各分类日志数', () {
    final stats = LoggerService.instance.getStatistics();

    expect(stats.byCategory[LogCategory.database], 2);
    expect(stats.byCategory[LogCategory.network], 3);
    expect(stats.byCategory[LogCategory.ai], 1);
  });

  test('应正确计算级别占比', () {
    final stats = LoggerService.instance.getStatistics();

    expect(stats.levelPercentage[LogLevel.debug], closeTo(0.333, 0.01));
    expect(stats.levelPercentage[LogLevel.error], closeTo(0.333, 0.01));
  });
});
```

**Step 4: 运行测试**

```bash
flutter test test/unit/services/logger_service_test.dart
```

预期: 所有统计测试通过

**Step 5: 提交**

```bash
git add lib/services/logger_service.dart test/unit/services/logger_service_test.dart
git commit -m "feat(logger): 添加日志统计功能"
```

---

### Task 4: 优化日志显示格式

**目标:** 在日志查看界面中优化日志条目的显示格式，添加分类和标签展示。

**文件:**
- Modify: `lib/screens/log_viewer_screen.dart:328-343`

**Step 1: 修改日志条目UI**

更新日志卡片显示，添加分类和标签:

```dart
Card(
  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  child: ListTile(
    dense: true,
    leading: Icon(
      log.level.icon,
      size: 18,
      color: _getLevelColor(log.level),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 消息内容
        Text(
          log.message,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        // 分类标签
        Wrap(
          spacing: 4,
          children: [
            Chip(
              label: Text(
                log.category.label,
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: _getCategoryColor(log.category).withOpacity(0.2),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            ...log.tags.map((tag) => Chip(
              label: Text(
                tag,
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: Colors.grey.withOpacity(0.1),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )),
          ],
        ),
      ],
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatTimestamp(log.timestamp),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        if (log.stackTrace != null && log.stackTrace!.isNotEmpty)
          InkWell(
            onTap: () {
              _showStackTraceDialog(log);
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '查看堆栈信息',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    ),
  ),
);
```

**Step 2: 添加分类颜色辅助方法**

在 `_LogViewerScreenState` 类中添加:

```dart
Color _getCategoryColor(LogCategory category) {
  switch (category) {
    case LogCategory.database:
      return Colors.purple;
    case LogCategory.network:
      return Colors.cyan;
    case LogCategory.ai:
      return Colors.deepOrange;
    case LogCategory.ui:
      return Colors.green;
    case LogCategory.cache:
      return Colors.orange;
    case LogCategory.tts:
      return Colors.teal;
    case LogCategory.character:
      return Colors.pink;
    case LogCategory.general:
      return Colors.grey;
  }
}
```

**Step 3: 测试UI效果**

```bash
flutter run --debug
```

操作: 打开日志查看界面，查看日志条目是否正确显示分类和标签

**Step 4: 提交**

```bash
git add lib/screens/log_viewer_screen.dart
git commit -m "feat(log_viewer): 优化日志显示格式，添加分类和标签展示"
```

---

### Task 5: 增强日志导出功能

**目标:** 实现真正的文件导出，支持按条件筛选导出，并添加分享功能。

**文件:**
- Modify: `lib/services/logger_service.dart:296-314`
- Modify: `lib/screens/log_viewer_screen.dart:82-120`

**Step 1: 增强导出方法**

修改 `exportToFile` 方法，添加筛选参数:

```dart
/// 导出日志到文件
///
/// 参数:
/// - [level] 可选，仅导出特定级别
/// - [category] 可选，仅导出特定分类
/// - [startDate] 可选，起始时间
/// - [endDate] 可选，结束时间
Future<File> exportToFile({
  LogLevel? level,
  LogCategory? category,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  // 应用筛选条件
  var logs = _logs;

  if (level != null) {
    logs = logs.where((log) => log.level == level).toList();
  }

  if (category != null) {
    logs = logs.where((log) => log.category == category).toList();
  }

  if (startDate != null) {
    logs = logs.where((log) => log.timestamp.isAfter(startDate)).toList();
  }

  if (endDate != null) {
    logs = logs.where((log) => log.timestamp.isBefore(endDate)).toList();
  }

  // 生成文件内容
  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = 'app_logs_$timestamp.txt';
  final file = File('${directory.path}/$fileName');

  final content = logs
      .map((log) {
        final timestamp = _formatTimestamp(log.timestamp);
        final category = '[${log.category.label}]';
        final tags = log.tags.isNotEmpty ? ' [${log.tags.join(', ')}]' : '';
        final stackTrace = log.stackTrace != null ? '\n${log.stackTrace}' : '';
        return '[$timestamp] [${log.level.label}] $category ${log.message}$tags$stackTrace';
      })
      .join('\n\n---\n\n');

  await file.writeAsString(content, flush: true);
  return file;
}

/// 导出为CSV格式（便于Excel分析）
Future<File> exportToCSV({
  LogLevel? level,
  LogCategory? category,
}) async {
  var logs = _logs;

  if (level != null) {
    logs = logs.where((log) => log.level == level).toList();
  }

  if (category != null) {
    logs = logs.where((log) => log.category == category).toList();
  }

  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = 'app_logs_$timestamp.csv';
  final file = File('${directory.path}/$fileName');

  // CSV 头部
  final header = 'Timestamp,Level,Category,Tags,Message,StackTrace\n';

  // CSV 内容
  final rows = logs.map((log) {
    final timestamp = _formatTimestamp(log.timestamp);
    final level = log.level.label;
    final category = log.category.label;
    final tags = log.tags.join(';');
    final message = _escapeCSV(log.message);
    final stackTrace = _escapeCSV(log.stackTrace ?? '');
    return '$timestamp,$level,$category,$tags,$message,$stackTrace';
  }).join('\n');

  await file.writeAsString(header + rows, flush: true);
  return file;
}

/// CSV 转义
String _escapeCSV(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
```

**Step 2: 更新导出UI**

在 `log_viewer_screen.dart` 中添加导出选项:

```dart
Future<void> _exportLogs() async {
  if (_displayedLogs.isEmpty) {
    _showSnackBar('暂无日志可导出');
    return;
  }

  setState(() {
    _isExporting = true;
  });

  try {
    // 显示导出选项对话框
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择导出格式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('文本格式 (.txt)'),
              subtitle: const Text('适合阅读和分析'),
              leading: const Icon(Icons.description),
              onTap: () => Navigator.pop(context, 'txt'),
            ),
            ListTile(
              title: const Text('CSV格式 (.csv)'),
              subtitle: const Text('适合Excel分析'),
              leading: const Icon(Icons.table_chart),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
          ],
        ),
      ),
    );

    if (format == null || !mounted) return;

    // 执行导出
    final file = format == 'txt'
        ? await LoggerService.instance.exportToFile(
            level: _selectedLevel == null ? null : LogLevel.error, // 示例
          )
        : await LoggerService.instance.exportToCSV();

    // 复制文件路径到剪贴板
    await Clipboard.setData(ClipboardData(text: file.path));

    if (mounted) {
      _showSnackBar('已导出到: ${file.path}');
    }
  } catch (e) {
    if (mounted) {
      _showSnackBar('导出失败: $e');
    }
  } finally {
    if (mounted) {
      setState(() {
        _isExporting = false;
      });
    }
  }
}
```

**Step 3: 测试导出功能**

```bash
flutter run --debug
```

操作:
1. 打开日志查看界面
2. 点击导出按钮
3. 选择导出格式
4. 验证文件生成成功

**Step 4: 提交**

```bash
git add lib/services/logger_service.dart lib/screens/log_viewer_screen.dart
git commit -m "feat(logger): 增强日志导出功能，支持多格式和筛选"
```

---

### Task 6: 性能优化 - 异步批量写入

**目标:** 优化持久化性能，避免频繁IO操作。

**文件:**
- Modify: `lib/services/logger_service.dart:156-233`

**Step 1: 添加批量写入配置**

在 `LoggerService` 类中添加配置:

```dart
/// 批量写入间隔（毫秒）
static const int _flushIntervalMs = 1000;

/// 上次持久化时间
DateTime? _lastPersistTime;
```

**Step 2: 修改持久化调度**

更新 `_schedulePersist` 方法:

```dart
void _schedulePersist() {
  _pendingPersist = true;

  // 批量写入优化：距离上次写入超过指定间隔才执行
  final now = DateTime.now();
  if (_lastPersistTime == null ||
      now.difference(_lastPersistTime!).inMilliseconds >= _flushIntervalMs) {
    _persist();
  }
}
```

**Step 3: 更新持久化方法**

更新 `_persist` 方法:

```dart
Future<void> _persist() async {
  if (_isPersisting) {
    return;
  }

  if (!_pendingPersist) {
    return;
  }

  _isPersisting = true;
  _pendingPersist = false;
  _lastPersistTime = DateTime.now();

  try {
    await _persistLogs();
  } finally {
    _isPersisting = false;

    if (_pendingPersist) {
      await _persist();
    }
  }
}
```

**Step 4: 添加强制刷新方法**

用于确保重要日志立即写入:

```dart
/// 强制刷新到持久化存储
///
/// 用于确保重要日志立即写入，而非等待批量写入。
Future<void> flush() async {
  if (_pendingPersist) {
    await _persist();
  }
}
```

**Step 5: 编写性能测试**

```dart
group('LoggerService 性能测试', () {
  test('批量写入应减少持久化次数', () async {
    await TestHelpers.initLoggerService();
    final prefs = await SharedPreferences.getInstance();

    // 清空计数（如果有的话）
    await TestHelpers.clearLoggerService();

    final stopwatch = Stopwatch()..start();

    // 快速记录100条日志
    for (int i = 0; i < 100; i++) {
      LoggerService.instance.d('日志 $i');
    }

    // 等待批量写入完成
    await LoggerService.instance.flush();

    stopwatch.stop();

    // 验证所有日志都被持久化
    final logsJson = prefs.getString('app_logs');
    expect(logsJson, isNotNull);

    final List<dynamic> decoded = jsonDecode(logsJson!);
    expect(decoded.length, 100);

    print('批量写入100条日志耗时: ${stopwatch.elapsedMilliseconds}ms');

    await TestHelpers.clearLoggerService();
  });
});
```

**Step 6: 运行测试**

```bash
flutter test test/unit/services/logger_service_test.dart
```

预期: 性能测试通过，耗时合理（< 500ms）

**Step 7: 提交**

```bash
git add lib/services/logger_service.dart test/unit/services/logger_service_test.dart
git commit -m "perf(logger): 优化持久化性能，实现异步批量写入"
```

---

## 阶段二：制定日志使用规范

### Task 7: 编写日志使用指南文档

**目标:** 创建清晰的日志使用规范文档，指导团队正确使用日志系统。

**文件:**
- Create: `docs/logging-guidelines.md`

**Step 1: 创建文档**

创建完整的日志使用指南:

```markdown
# 日志系统使用指南

## 概述

本项目使用自研的 `LoggerService` 进行统一的日志管理，支持日志分类、标签、搜索、统计和导出功能。

## 日志级别使用规范

### DEBUG - 调试信息
- **用途:** 开发和调试过程中的详细信息
- **场景:** 变量值、执行流程、临时调试
- **示例:** `LoggerService.instance.d('用户ID: $userId')`
- **注意:** 生产环境应尽量减少

### INFO - 信息级别
- **用途:** 重要的业务流程和状态变更
- **场景:** 功能启动、任务完成、状态变更
- **示例:**
  - `LoggerService.instance.i('数据库升级完成', category: LogCategory.database)`
  - `LoggerService.instance.i('缓存清理完成', category: LogCategory.cache)`

### WARNING - 警告级别
- **用途:** 潜在问题或异常情况
- **场景:** 降级处理、重试、资源不足
- **示例:**
  - `LoggerService.instance.w('API限流，等待重试', category: LogCategory.network, tags: ['rate-limit'])`
  - `LoggerService.instance.w('缓存空间不足，开始清理', category: LogCategory.cache)`

### ERROR - 错误级别
- **用途:** 错误和异常情况
- **场景:** 操作失败、异常捕获、崩溃
- **示例:**
  - `LoggerService.instance.e('数据库连接失败', stackTrace: stackTrace.toString(), category: LogCategory.database)`
  - `LoggerService.instance.e('API请求失败', category: LogCategory.network, tags: ['timeout'])`

## 日志分类规范

| 分类 | 标签 | 使用场景 |
|-----|------|---------|
| `LogCategory.database` | 数据库 | 数据库操作、查询、迁移 |
| `LogCategory.network` | 网络 | API请求、响应、超时 |
| `LogCategory.ai` | AI | Dify调用、内容生成 |
| `LogCategory.ui` | 界面 | 页面跳转、交互事件 |
| `LogCategory.cache` | 缓存 | 缓存读写、清理 |
| `LogCategory.tts` | 语音 | TTS播放、状态变更 |
| `LogCategory.character` | 角色 | 角色管理、提取 |
| `LogCategory.general` | 通用 | 未分类日志 |

## 日志标签使用规范

标签用于更细粒度的日志搜索，建议使用以下标签:

**网络相关:**
- `timeout` - 请求超时
- `retry` - 重试操作
- `api` - API调用
- `websocket` - WebSocket连接

**AI相关:**
- `dify` - Dify工作流
- `generation` - 内容生成
- `stream` - 流式响应

**缓存相关:**
- `hit` - 缓存命中
- `miss` - 缓存未命中
- `cleanup` - 缓存清理

**示例:**
```dart
LoggerService.instance.w(
  'Dify API超时，正在重试',
  category: LogCategory.ai,
  tags: ['dify', 'timeout', 'retry'],
);
```

## 最佳实践

### ✅ 推荐做法

1. **为所有错误日志添加堆栈跟踪**
   ```dart
   try {
     await someOperation();
   } catch (e, stackTrace) {
     LoggerService.instance.e(
       '操作失败',
       stackTrace: stackTrace.toString(),
       category: LogCategory.database,
     );
   }
   ```

2. **使用有意义的日志消息**
   ```dart
   // 好
   LoggerService.instance.i('用户切换到章节: $chapterTitle', category: LogCategory.ui);

   // 不好
   LoggerService.instance.i('切换');
   ```

3. **合理使用分类和标签**
   ```dart
   LoggerService.instance.e(
     'API请求失败: POST /api/generate',
     category: LogCategory.network,
     tags: ['api', 'post', 'generate'],
   );
   ```

4. **重要操作后强制刷新**
   ```dart
   LoggerService.instance.e('应用崩溃', stackTrace: stackTrace);
   await LoggerService.instance.flush(); // 确保写入
   ```

### ❌ 禁止做法

1. **不要混用 LoggerService 和 debugPrint**
   ```dart
   // 错误
   LoggerService.instance.e('错误');
   debugPrint('错误'); // 冗余

   // 正确
   LoggerService.instance.e('错误');
   ```

2. **不要在循环中频繁记录日志**
   ```dart
   // 错误
   for (int i = 0; i < 10000; i++) {
     LoggerService.instance.d('处理第$i个'); // 性能问题
   }

   // 正确
   LoggerService.instance.i('开始处理10000个项目', category: LogCategory.general);
   for (int i = 0; i < 10000; i++) {
     // 处理
   }
   LoggerService.instance.i('处理完成', category: LogCategory.general);
   ```

3. **不要记录敏感信息**
   ```dart
   // 错误
   LoggerService.instance.d('用户密码: $password');

   // 正确
   LoggerService.instance.d('用户登录成功', category: LogCategory.ui);
   ```

## 日志查看和分析

### 在APP中查看
1. 打开 **设置** 页面
2. 点击 **应用日志**
3. 使用过滤器按级别或分类查看
4. 点击日志条目查看堆栈信息
5. 使用搜索功能查找关键词

### 导出日志
1. 在日志查看界面点击 **导出** 按钮
2. 选择导出格式（TXT或CSV）
3. 文件保存在应用文档目录

### 日志搜索示例
```dart
// 搜索所有网络错误
final networkErrors = LoggerService.instance.searchLogs(
  '',
  category: LogCategory.network,
).where((log) => log.level == LogLevel.error).toList();

// 搜索特定标签
final timeoutLogs = LoggerService.instance.getLogsByTag('timeout');

// 查看统计
final stats = LoggerService.instance.getStatistics();
print('总日志: ${stats.total}');
print('错误占比: ${stats.levelPercentage[LogLevel.error]}');
```

## 迁移指南

### 从 debugPrint 迁移到 LoggerService

**替换前:**
```dart
debugPrint('数据库连接成功');
```

**替换后:**
```dart
LoggerService.instance.i('数据库连接成功', category: LogCategory.database);
```

**批量替换规则（按优先级）:**

1. **优先级1 - 错误日志（必须迁移）**
   - 所有 `debugPrint` 报告错误的地方
   - 所有异常捕获

2. **优先级2 - 重要业务流程（必须迁移）**
   - 数据库操作
   - 网络请求
   - AI调用

3. **优先级3 - 临时调试（可选迁移）**
   - 开发调试信息
   - 性能分析

## 性能考虑

- LoggerService 使用异步批量写入，性能影响最小
- 内存限制1000条日志，自动FIFO清理
- 重要日志使用 `flush()` 确保立即写入

## 故障排查

### 日志未显示
1. 确认已初始化: `await LoggerService.instance.init()`
2. 检查日志过滤器设置
3. 确认日志级别是否被过滤

### 日志丢失
1. 检查是否超过1000条限制
2. 确认 `flush()` 是否在关键位置调用
3. 检查 SharedPreferences 是否可用

### 性能问题
1. 减少循环中的日志记录
2. 使用合适的日志级别
3. 避免记录大量数据
```

**Step 2: 提交文档**

```bash
git add docs/logging-guidelines.md
git commit -m "docs(logging): 添加日志系统使用指南"
```

---

## 阶段三：规范化迁移

### Task 8: 创建迁移检查工具

**目标:** 创建一个静态分析工具，检测滥用 debugPrint 的情况。

**文件:**
- Create: `tool/lint/logging_rules.dart`
- Create: `analysis_options.yaml` (修改)

**Step 1: 创建自定义 lint 规则**

创建 `tool/lint/logging_rules.dart`:

```dart
/// 自定义日志检查规则
///
/// 用法: dart run tool/lint/logging_rules.dart
import 'dart:io';

void main() async {
  print('🔍 开始检查日志使用规范...\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ 未找到 lib 目录');
    return;
  }

  int totalDebugPrint = 0;
  int filesWithDebugPrint = 0;
  final filesWithIssues = <String, List<String>>{};

  await for (final entity in libDir.list(recursive: true, followLinks: false)) {
    if (entity.path.endsWith('.dart')) {
      final file = File(entity.path);
      final contents = await file.readAsString();
      final lines = contents.split('\n');

      final issues = <String>[];
      int debugPrintCount = 0;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNumber = i + 1;

        // 检查 debugPrint 使用
        if (line.contains('debugPrint(')) {
          debugPrintCount++;
          totalDebugPrint++;

          // 检查是否有对应的 LoggerService 调用
          // 简单启发式：如果同一行或相邻行没有 LoggerService，标记为问题
          bool hasLoggerService = false;
          for (int j = lineNumber - 2; j <= lineNumber + 2 && j < lines.length; j++) {
            if (j >= 0 && lines[j].contains('LoggerService.instance.')) {
              hasLoggerService = true;
              break;
            }
          }

          if (!hasLoggerService) {
            issues.add('  行 $lineNumber: debugPrint 使用');
          }
        }
      }

      if (issues.isNotEmpty) {
        filesWithIssues[entity.path] = issues;
        filesWithDebugPrint++;
      }
    }
  }

  // 打印报告
  print('📊 检查结果:\n');
  print('  总 debugPrint 使用次数: $totalDebugPrint');
  print('  涉及文件数: $filesWithDebugPrint');
  print('  需要迁移的文件: ${filesWithIssues.length}\n');

  if (filesWithIssues.isNotEmpty) {
    print('⚠️  发现问题的文件:\n');
    filesWithIssues.forEach((file, issues) {
      print('📄 $file');
      issues.forEach(print);
      print('');
    });
  } else {
    print('✅ 所有文件都符合日志规范！');
  }

  print('\n💡 建议:');
  print('  1. 将 debugPrint 迁移到 LoggerService');
  print('  2. 参考 docs/logging-guidelines.md 获取详细指南');
  print('  3. 优先迁移错误和重要业务流程日志');
}
```

**Step 2: 添加到 analysis_options.yaml**

在 `analysis_options.yaml` 中添加自定义规则提示:

```yaml
# 日志规范提示
linter:
  rules:
    # 其他规则...
    - avoid_print
```

**Step 3: 测试检查工具**

```bash
dart run tool/lint/logging_rules.dart
```

预期输出: 显示当前使用 debugPrint 的文件和行号

**Step 4: 提交工具**

```bash
git add tool/lint/logging_rules.dart analysis_options.yaml
git commit -m "tool(lint): 添加日志规范检查工具"
```

---

### Task 9: 迁移关键服务层日志

**目标:** 将服务层的关键日志迁移到 LoggerService。

**文件:**
- Modify: `lib/services/database_service.dart`
- Modify: `lib/services/dify_service.dart`
- Modify: `lib/services/api_service_wrapper.dart`

**Step 1: 迁移 database_service.dart**

定位关键日志位置:

```bash
# 使用 grep 查找 debugPrint
grep -n "debugPrint" lib/services/database_service.dart
```

逐个替换:

**替换前:**
```dart
debugPrint('数据库升级: $from -> $to');
```

**替换后:**
```dart
LoggerService.instance.i(
  '数据库升级: $from -> $to',
  category: LogCategory.database,
  tags: ['migration', 'upgrade'],
);
```

**关键位置迁移清单:**
1. 数据库升级完成
2. 表创建成功
3. 事务开始/提交/回滚
4. 查询性能警告
5. 错误和异常

**Step 2: 迁移 dify_service.dart**

**示例替换:**

替换前:
```dart
debugPrint('🎯 === 特写生成完成 ===');
debugPrint('完整内容长度: ${completeContent.length}');
```

替换后:
```dart
LoggerService.instance.i(
  '特写生成完成，内容长度: ${completeContent.length}',
  category: LogCategory.ai,
  tags: ['dify', 'generation', 'complete'],
);
```

**Step 3: 迁移 api_service_wrapper.dart**

**示例替换:**

替换前:
```dart
debugPrint('=== API请求失败 ===');
debugPrint('状态码: ${statusCode}');
```

替换后:
```dart
LoggerService.instance.e(
  'API请求失败: $endpoint',
  category: LogCategory.network,
  tags: ['api', 'error', 'endpoint'],
);
```

**Step 4: 验证迁移效果**

运行检查工具:
```bash
dart run tool/lint/logging_rules.dart
```

确认服务层日志已迁移

**Step 5: 运行测试**

```bash
flutter test test/unit/services/
```

确保功能未受影响

**Step 6: 提交迁移**

```bash
git add lib/services/database_service.dart lib/services/dify_service.dart lib/services/api_service_wrapper.dart
git commit -m "refactor(logger): 迁移服务层日志到LoggerService"
```

---

### Task 10: 移除双重记录

**目标:** 移除 main.dart 中的双重日志记录。

**文件:**
- Modify: `lib/main.dart`

**Step 1: 定位双重记录**

查找同时使用 LoggerService 和 debugPrint 的地方:

```dart
LoggerService.instance.e(error, stackTrace: stackTrace);
debugPrint('=== $error ==='); // 移除这行
```

**Step 2: 移除冗余的 debugPrint**

将:
```dart
final error = 'Flutter Error: ${details.exception}';
LoggerService.instance.e(error, stackTrace: stackTrace);
debugPrint('=== $error ===');
debugPrint('Stack trace: $stackTrace');
```

改为:
```dart
final error = 'Flutter Error: ${details.exception}';
LoggerService.instance.e(
  error,
  stackTrace: stackTrace.toString(),
  category: LogCategory.general,
  tags: ['flutter-error'],
);
```

**Step 3: 验证应用正常启动**

```bash
flutter run --debug
```

触发一些错误，确认日志正确记录

**Step 4: 提交修改**

```bash
git add lib/main.dart
git commit -m "refactor(logger): 移除双重日志记录"
```

---

### Task 11: 更新日志查看界面统计

**目标:** 在日志查看界面添加统计信息展示。

**文件:**
- Modify: `lib/screens/log_viewer_screen.dart`

**Step 1: 添加统计显示**

在 AppBar 中添加统计按钮:

```dart
actions: [
  // 统计按钮
  IconButton(
    icon: const Icon(Icons.bar_chart),
    onPressed: _showStatistics,
    tooltip: '查看统计',
  ),
  // 其他按钮...
],
```

**Step 2: 实现统计对话框**

```dart
void _showStatistics() {
  final stats = LoggerService.instance.getStatistics();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bar_chart),
          SizedBox(width: 8),
          Text('日志统计'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            // 总数
            ListTile(
              title: const Text('总日志数'),
              trailing: Text(
                '${stats.total}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),

            // 按级别统计
            const Text('按级别', style: TextStyle(fontWeight: FontWeight.bold)),
            ...LogLevel.values.map((level) {
              final count = stats.byLevel[level] ?? 0;
              final percentage = stats.levelPercentage[level] ?? 0.0;
              return ListTile(
                leading: Icon(level.icon, color: _getLevelColor(level)),
                title: Text(level.label),
                trailing: Text('$count (${(percentage * 100).toStringAsFixed(1)}%)'),
              );
            }),
            const Divider(),

            // 按分类统计
            const Text('按分类', style: TextStyle(fontWeight: FontWeight.bold)),
            ...LogCategory.values.map((category) {
              final count = stats.byCategory[category] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return ListTile(
                leading: Icon(
                  Icons.label_outline,
                  color: _getCategoryColor(category),
                ),
                title: Text(category.label),
                trailing: Text('$count'),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
```

**Step 3: 测试统计功能**

```bash
flutter run --debug
```

操作: 打开日志查看界面 → 点击统计按钮 → 查看统计信息

**Step 4: 提交修改**

```bash
git add lib/screens/log_viewer_screen.dart
git commit -m "feat(log_viewer): 添加日志统计信息展示"
```

---

### Task 12: 添加搜索界面

**目标:** 在日志查看界面添加搜索功能。

**文件:**
- Modify: `lib/screens/log_viewer_screen.dart`

**Step 1: 添加搜索框**

在 body 顶部添加搜索框:

```dart
body: Column(
  children: [
    // 搜索框
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索日志...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _loadLogs();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _performSearch();
          });
        },
      ),
    ),
    // 其他内容...
  ],
),
```

**Step 2: 添加搜索状态**

在 `_LogViewerScreenState` 中添加:

```dart
String _searchQuery = '';
```

**Step 3: 实现搜索方法**

```dart
void _performSearch() {
  if (_searchQuery.isEmpty) {
    _loadLogs(); // 恢复原始列表
  } else {
    final results = LoggerService.instance.searchLogs(
      _searchQuery,
      category: _selectedLevel == null ? null : _categoryFromLevel(_selectedLevel),
    );
    setState(() {
      _displayedLogs = results;
    });
  }
}

LogCategory? _categoryFromLevel(LogLevel? level) {
  // 简化版本：不转换，返回null搜索所有分类
  // 实际可以添加映射逻辑
  return null;
}
```

**Step 4: 测试搜索功能**

```bash
flutter run --debug
```

操作: 在搜索框输入关键词，验证结果正确

**Step 5: 提交修改**

```bash
git add lib/screens/log_viewer_screen.dart
git commit -m "feat(log_viewer): 添加日志搜索功能"
```

---

## 总结

本计划分为三个阶段：

### 阶段一：增强 LoggerService 功能（Task 1-6）
- ✅ 添加日志分类和标签系统
- ✅ 添加日志搜索功能
- ✅ 添加日志统计功能
- ✅ 优化日志显示格式
- ✅ 增强日志导出功能
- ✅ 性能优化 - 异步批量写入

### 阶段二：制定日志使用规范（Task 7）
- ✅ 编写日志使用指南文档

### 阶段三：规范化迁移（Task 8-12）
- ✅ 创建迁移检查工具
- ✅ 迁移关键服务层日志
- ✅ 移除双重记录
- ✅ 更新日志查看界面统计
- ✅ 添加搜索界面

## 预期成果

完成后将实现：
1. 统一的日志系统，功能完善
2. 清晰的使用规范和文档
3. 从 debugPrint 到 LoggerService 的有序迁移
4. 强大的日志分析和查看能力
5. 良好的性能表现

## 注意事项

- 所有修改需保持向后兼容
- 每个任务独立提交，便于回滚
- 测试覆盖所有新增功能
- 文档与代码同步更新
