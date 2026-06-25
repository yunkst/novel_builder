import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/llm_logger/llm_call_record.dart';
import '../utils/toast_utils.dart';

/// AI 调用日志详情页
///
/// 展示单条 LLM 调用的完整元数据和请求/响应内容。
/// - 请求体和响应体以 JSON 美化格式展示（带折叠）
/// - 支持复制单个区块或全部内容
class LlmLogDetailScreen extends StatefulWidget {
  final LlmCallRecord record;

  const LlmLogDetailScreen({super.key, required this.record});

  @override
  State<LlmLogDetailScreen> createState() => _LlmLogDetailScreenState();
}

class _LlmLogDetailScreenState extends State<LlmLogDetailScreen> {
  /// 各区块展开状态
  final Map<String, bool> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('调用详情'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            onPressed: _copyAll,
            tooltip: '复制全部',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildStatusHeader(r, theme),
          const SizedBox(height: 12),
          _buildMetadataCard(r, theme),
          const SizedBox(height: 12),
          _buildJsonSection(
            title: '请求体 (Request Body)',
            icon: Icons.upload_outlined,
            content: r.requestBody,
            accent: Colors.blue,
          ),
          const SizedBox(height: 12),
          if (r.responseBody != null)
            _buildJsonSection(
              title: '响应体 (Response Body)',
              icon: Icons.download_outlined,
              content: r.responseBody!,
              accent: Colors.green,
            )
          else
            _buildPlaceholderCard(
              '响应尚未完成',
              '该调用可能仍在进行中或被异常中断',
              Icons.hourglass_top,
              Colors.orange,
            ),
          if (r.errorMessage != null && r.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildErrorCard(r.errorMessage!, theme),
          ],
        ],
      ),
    );
  }

  /// 顶部状态条
  Widget _buildStatusHeader(LlmCallRecord r, ThemeData theme) {
    final color = r.isSuccess
        ? Colors.green
        : (r.responseBody == null ? Colors.orange : Colors.red);
    final icon = r.isSuccess
        ? Icons.check_circle
        : (r.responseBody == null ? Icons.hourglass_top : Icons.error);
    final label = r.isSuccess
        ? '调用成功'
        : (r.responseBody == null ? '调用中' : '调用失败');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          if (r.durationMs != null)
            Text(
              '耗时 ${r.durationText}',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  /// 元数据卡片
  Widget _buildMetadataCard(LlmCallRecord r, ThemeData theme) {
    final rows = <MapEntry<String, String>>[
      MapEntry('时间', _formatTime(r.timestamp)),
      MapEntry('模型', r.model ?? '-'),
      MapEntry('端点', r.endpoint),
      MapEntry('模式', r.isStreaming ? '流式 (stream)' : '阻塞 (blocking)'),
      MapEntry('记录 ID', r.id),
    ];

    if (r.promptTokens != null) {
      rows.add(MapEntry('Prompt Tokens', '${r.promptTokens}'));
    }
    if (r.completionTokens != null) {
      rows.add(MapEntry('Completion Tokens', '${r.completionTokens}'));
    }
    if (r.totalTokens != null) {
      rows.add(MapEntry('Total Tokens', '${r.totalTokens}'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('元数据',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...rows.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          e.value,
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// JSON 内容区块（可折叠 + 美化）
  Widget _buildJsonSection({
    required String title,
    required IconData icon,
    required String content,
    required Color accent,
  }) {
    final isExpanded = _expanded[title] ?? true;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded[title] = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Text(
                    '${(content.length / 1024).toStringAsFixed(1)} KB',
                    style: TextStyle(
                      fontSize: 11,
                      color: accent.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => _copyText(content, '$title 已复制'),
                    tooltip: '复制',
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  _prettyJson(content),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 占位卡片
  Widget _buildPlaceholderCard(
      String title, String subtitle, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 错误卡片
  Widget _buildErrorCard(String error, ThemeData theme) {
    return Card(
      color: Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('错误信息',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              error,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  /// 复制全部
  void _copyAll() {
    final r = widget.record;
    final buf = StringBuffer();
    buf.writeln('=== AI 调用详情 ===');
    buf.writeln('ID: ${r.id}');
    buf.writeln('时间: ${_formatTime(r.timestamp)}');
    buf.writeln('模型: ${r.model ?? '-'}');
    buf.writeln('端点: ${r.endpoint}');
    buf.writeln('模式: ${r.isStreaming ? '流式' : '阻塞'}');
    if (r.durationMs != null) buf.writeln('耗时: ${r.durationText}');
    if (r.totalTokens != null) buf.writeln('Total Tokens: ${r.totalTokens}');
    if (r.errorMessage != null) buf.writeln('错误: ${r.errorMessage}');
    buf.writeln('\n--- 请求体 ---');
    buf.writeln(_prettyJson(r.requestBody));
    if (r.responseBody != null) {
      buf.writeln('\n--- 响应体 ---');
      buf.writeln(_prettyJson(r.responseBody!));
    }
    _copyText(buf.toString(), '已复制全部内容');
  }

  void _copyText(String text, String successTip) {
    Clipboard.setData(ClipboardData(text: text));
    ToastUtils.showSuccess(successTip);
  }

  /// 美化 JSON 字符串（尝试解析后重新缩进）
  static String _prettyJson(String raw) {
    if (raw.trim().isEmpty) return raw;
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw; // 解析失败时返回原文
    }
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
