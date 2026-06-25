import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/llm_logger/llm_call_record.dart';
import '../services/llm_logger/llm_logger.dart';
import '../utils/toast_utils.dart';
import '../widgets/common/common_widgets.dart';
import 'llm_log_detail_screen.dart';

/// AI 调用日志列表页
///
/// 显示最近的 LLM 调用记录，点击可查看完整的请求/响应详情。
/// 支持按状态过滤（全部/成功/失败）、刷新、清空。
class LlmLogListScreen extends StatefulWidget {
  const LlmLogListScreen({super.key});

  @override
  State<LlmLogListScreen> createState() => _LlmLogListScreenState();
}

class _LlmLogListScreenState extends State<LlmLogListScreen> {
  /// 状态过滤器
  _StatusFilter _filter = _StatusFilter.all;

  /// 所有记录（未过滤）
  List<LlmCallRecord> _allRecords = [];

  /// 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  /// 加载记录
  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final records = await LlmLogger.instance.getRecent(limit: 200);
      if (mounted) {
        setState(() {
          _allRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError('加载失败: $e');
      }
    }
  }

  /// 获取过滤后的记录
  List<LlmCallRecord> get _filteredRecords {
    switch (_filter) {
      case _StatusFilter.success:
        return _allRecords.where((r) => r.isSuccess).toList();
      case _StatusFilter.failure:
        return _allRecords.where((r) => !r.isSuccess).toList();
      case _StatusFilter.all:
        return _allRecords;
    }
  }

  /// 清空所有日志
  Future<void> _clearLogs() async {
    if (_allRecords.isEmpty) {
      ToastUtils.show('日志已为空');
      return;
    }

    final confirmed = await ConfirmDialog.show(
      context,
      title: '确认清空',
      message: '确定要清空所有 AI 调用日志吗？此操作不可撤销。',
      confirmText: '清空',
      icon: Icons.delete_outline,
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed == true && mounted) {
      await LlmLogger.instance.clear();
      await _loadRecords();
      if (mounted) ToastUtils.showSuccess('日志已清空');
    }
  }

  /// 复制全部记录（简要信息）
  Future<void> _copyAll() async {
    if (_filteredRecords.isEmpty) {
      ToastUtils.show('暂无日志可复制');
      return;
    }

    final text = _filteredRecords.map((r) {
      final status = r.isSuccess ? '✓' : '✗';
      return '[$status] ${_formatTime(r.timestamp)} [${r.model ?? '-'}] '
          '${r.durationText} | ${r.previewText}';
    }).join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ToastUtils.showSuccess('已复制 ${_filteredRecords.length} 条摘要');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 调用日志'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          // 状态过滤
          PopupMenuButton<_StatusFilter>(
            icon: const Icon(Icons.filter_list),
            tooltip: '按状态过滤',
            onSelected: (f) => setState(() => _filter = f),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _StatusFilter.all, child: Text('全部')),
              PopupMenuItem(value: _StatusFilter.success, child: Text('仅成功')),
              PopupMenuItem(value: _StatusFilter.failure, child: Text('仅失败')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyAll,
            tooltip: '复制摘要',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: '清空',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? _buildEmptyState(theme)
              : Column(
                  children: [
                    // 过滤状态提示
                    if (_filter != _StatusFilter.all)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: theme.colorScheme.secondaryContainer,
                        child: Row(
                          children: [
                            Text(
                              '过滤: ${_filter.label}（${records.length} 条）',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _filter = _StatusFilter.all),
                              child: const Text('清除'),
                            ),
                          ],
                        ),
                      ),
                    // 记录总数
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Text(
                        '共 ${records.length} 条记录（最多展示最近 200 条）',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    // 日志列表
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadRecords,
                        child: ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return _buildRecordTile(record, theme);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// 构建单条记录卡片
  Widget _buildRecordTile(LlmCallRecord record, ThemeData theme) {
    final statusColor = record.isSuccess
        ? Colors.green
        : (record.responseBody == null ? Colors.orange : Colors.red);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          record.isSuccess
              ? Icons.check_circle_outline
              : (record.responseBody == null
                  ? Icons.hourglass_top
                  : Icons.error_outline),
          size: 20,
          color: statusColor,
        ),
        title: Text(
          record.previewText.isEmpty ? '(无内容预览)' : record.previewText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _chip(record.model ?? 'unknown', theme),
                _chip(record.isStreaming ? 'stream' : 'blocking', theme),
                _chip(record.durationText, theme),
                if (record.totalTokens != null)
                  _chip('${record.totalTokens} tok', theme),
                if (!record.isSuccess && record.errorMessage != null)
                  _chip(record.errorMessage!, theme, isError: true),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(record.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LlmLogDetailScreen(record: record),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String text, ThemeData theme, {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isError ? Colors.red : theme.colorScheme.primary)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: isError ? Colors.red : theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == _StatusFilter.all ? '暂无 AI 调用记录' : '没有匹配的记录',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '触发 AI 功能后，调用记录会自动出现在这里',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化时间
  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$m-$d $h:$mi:$s';
  }
}

enum _StatusFilter {
  all('全部'),
  success('成功'),
  failure('失败');

  final String label;
  const _StatusFilter(this.label);
}
