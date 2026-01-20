import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';

/// 日志查看页面
///
/// 提供应用日志的查看、过滤、导出和清空功能。
/// 日志按时间倒序显示（最新日志在最上方），支持按级别过滤。
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  /// 当前选择的日志级别过滤器
  LogLevel? _selectedLevel;

  /// 当前显示的日志列表
  late List<LogEntry> _displayedLogs;

  /// 是否正在导出
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    // 监听日志变化
    LoggerService.logChangeNotifier.addListener(_onLogChanged);
  }

  @override
  void dispose() {
    // 移除监听器
    LoggerService.logChangeNotifier.removeListener(_onLogChanged);
    super.dispose();
  }

  /// 日志变化回调
  void _onLogChanged() {
    // 当日志发生变化时重新加载
    if (mounted) {
      _loadLogs();
    }
  }

  /// 从LoggerService加载日志
  void _loadLogs() {
    final logs = _selectedLevel == null
        ? LoggerService.instance.getLogs()
        : LoggerService.instance.getLogsByLevel(_selectedLevel);
    setState(() {
      _displayedLogs = logs;
    });
  }

  /// 复制所有日志到剪贴板
  ///
  /// 将当前过滤后的所有日志格式化为纯文本后复制到剪贴板。
  void _copyAllLogs() async {
    if (_displayedLogs.isEmpty) {
      _showSnackBar('暂无日志可复制');
      return;
    }

    final text = _displayedLogs
        .map((log) {
          final stackTrace = log.stackTrace != null ? '\n${log.stackTrace}' : '';
          return '[${_formatTimestamp(log.timestamp)}] [${log.level.label}] ${log.message}$stackTrace';
        })
        .join('\n\n---\n\n');

    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      _showSnackBar('已复制 ${_displayedLogs.length} 条日志到剪贴板');
    }
  }

  /// 导出日志到文件
  ///
  /// 将当前过滤后的所有日志导出为文本文件。
  Future<void> _exportLogs() async {
    if (_displayedLogs.isEmpty) {
      _showSnackBar('暂无日志可导出');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // 使用临时方案：生成文本内容后让用户复制
      final text = _displayedLogs
          .map((log) {
            final stackTrace = log.stackTrace != null ? '\n${log.stackTrace}' : '';
            return '[${_formatTimestamp(log.timestamp)}] [${log.level.label}] ${log.message}$stackTrace';
          })
          .join('\n\n---\n\n');

      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        _showSnackBar('已复制日志内容，请粘贴到文本文件保存');
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

  /// 清空所有日志
  ///
  /// 显示确认对话框，用户确认后清空所有日志。
  Future<void> _clearLogs() async {
    if (_displayedLogs.isEmpty) {
      _showSnackBar('日志已为空');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有日志吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '清空',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await LoggerService.instance.clearLogs();
      _loadLogs();
      _showSnackBar('日志已清空');
    }
  }

  /// 显示SnackBar提示
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  /// 格式化时间戳
  ///
  /// 将DateTime格式化为易读的字符串格式。
  /// 格式: YYYY-MM-DD HH:mm:ss
  String _formatTimestamp(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  /// 获取日志级别的颜色
  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用日志'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 级别过滤按钮
          PopupMenuButton<LogLevel?>(
            icon: const Icon(Icons.filter_list),
            tooltip: '过滤日志',
            onSelected: (level) {
              setState(() {
                _selectedLevel = level;
                _loadLogs();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部'),
              ),
              const PopupMenuDivider(),
              ...LogLevel.values.map(
                (level) => PopupMenuItem(
                  value: level,
                  child: Row(
                    children: [
                      Icon(level.icon, size: 18, color: _getLevelColor(level)),
                      const SizedBox(width: 8),
                      Text(level.label),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 导出按钮
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            onPressed: _isExporting ? null : _exportLogs,
            tooltip: '导出日志',
          ),
          // 复制按钮
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyAllLogs,
            tooltip: '复制全部日志',
          ),
          // 清空按钮
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: '清空日志',
          ),
        ],
      ),
      body: _displayedLogs.isEmpty
          ? // 空状态提示
          Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bug_report_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedLevel == null ? '暂无日志' : '暂无${_selectedLevel!.label}级别日志',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : // 日志列表（倒序显示，最新日志在最上方）
          Column(
              children: [
                // 过滤状态提示
                if (_selectedLevel != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Row(
                      children: [
                        Icon(
                          _selectedLevel!.icon,
                          size: 16,
                          color: _getLevelColor(_selectedLevel!),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '仅显示 ${_selectedLevel!.label} 级别日志 (${_displayedLogs.length} 条)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedLevel = null;
                              _loadLogs();
                            });
                          },
                          child: const Text('清除过滤'),
                        ),
                      ],
                    ),
                  ),
                // 日志列表
                Expanded(
                  child: ListView.builder(
                    itemCount: _displayedLogs.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final log = _displayedLogs[_displayedLogs.length - 1 - index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            log.level.icon,
                            size: 18,
                            color: _getLevelColor(log.level),
                          ),
                          title: Text(
                            log.message,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
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
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// 显示堆栈信息对话框
  void _showStackTraceDialog(LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(log.level.icon, color: _getLevelColor(log.level)),
            const SizedBox(width: 8),
            const Text('堆栈信息'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              log.stackTrace ?? '无堆栈信息',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: log.stackTrace ?? ''));
              Navigator.pop(context);
              _showSnackBar('已复制堆栈信息');
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }
}
