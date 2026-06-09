import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:novel_app/services/hermes_sse_parser.dart';
import '../../core/theme/app_colors.dart';

/// 工具调用执行进度展示
///
/// 展示形式：
/// - running: 显示 emoji + label + 进度条
/// - completed: 折叠显示，点击展开查看参数和结果
class HermesToolProgress extends StatelessWidget {
  final List<ToolProgress> progressList;

  const HermesToolProgress({
    super.key,
    required this.progressList,
  });

  @override
  Widget build(BuildContext context) {
    if (progressList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: progressList.map((p) => _ToolCallCard(progress: p)).toList(),
    );
  }
}

class _ToolCallCard extends StatefulWidget {
  final ToolProgress progress;

  const _ToolCallCard({required this.progress});

  @override
  State<_ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<_ToolCallCard> {
  bool _isExpanded = false;

  @override
  void didUpdateWidget(_ToolCallCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // completed 时自动折叠
    if (widget.progress.status == 'completed' && _isExpanded) {
      setState(() => _isExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final theme = Theme.of(context);
    final isRunning = p.status == 'running';
    final isCompleted = p.status == 'completed' || p.status == 'done';
    final isError = p.status == 'error';

    Color statusColor;
    IconData statusIcon;
    if (isRunning) {
      statusColor = context.appColors.info;
      statusIcon = Icons.sync;
    } else if (isCompleted) {
      statusColor = context.appColors.success;
      statusIcon = Icons.check_circle;
    } else if (isError) {
      statusColor = context.appColors.error;
      statusIcon = Icons.error;
    } else {
      statusColor = context.appColors.warning;
      statusIcon = Icons.pending;
    }

    // 构建标题行
    final title = p.label ?? p.toolName;
    final titleContent = Row(
      children: [
        if (p.emoji != null) ...[
          Text(p.emoji!, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
        ],
        Icon(statusIcon, size: 16, color: statusColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            isRunning ? '$title...' : title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isRunning)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: statusColor,
            ),
          ),
      ],
    );

    // 可折叠内容
    final collapsibleContent = _buildCollapsibleContent(context, p, theme);

    if (!isCompleted) {
      // running / error 状态：直接显示内容
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleContent,
            if (collapsibleContent != null) ...[
              const SizedBox(height: 8),
              collapsibleContent,
            ],
          ],
        ),
      );
    }

    // completed 状态：折叠/展开
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(child: titleContent),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded && collapsibleContent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: collapsibleContent,
            ),
        ],
      ),
    );
  }

  Widget? _buildCollapsibleContent(BuildContext context, ToolProgress p, ThemeData theme) {
    // arguments 和 result 都为空时不需要折叠内容
    if ((p.arguments == null || p.arguments!.isEmpty) &&
        (p.result == null || p.result!.isEmpty)) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.arguments != null && p.arguments!.isNotEmpty) ...[
          _SectionHeader(title: '参数', icon: Icons.input),
          const SizedBox(height: 4),
          _JsonBlock(
            json: p.arguments!,
            theme: theme,
          ),
          const SizedBox(height: 8),
        ],
        if (p.result != null && p.result!.isNotEmpty) ...[
          _SectionHeader(title: '结果', icon: Icons.output),
          const SizedBox(height: 4),
          _JsonBlock(
            json: p.result!,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _JsonBlock extends StatelessWidget {
  final String json;
  final ThemeData theme;

  const _JsonBlock({required this.json, required this.theme});

  @override
  Widget build(BuildContext context) {
    // 尝试格式化 JSON
    String displayText = json;
    try {
      final decoded = jsonDecode(json);
      displayText = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      // 非 JSON 原文显示
    }

    // 截断过长内容
    const maxLines = 15;
    final lines = displayText.split('\n');
    final displayLines = lines.length > maxLines
        ? [...lines.take(maxLines), '...']
        : lines;
    final truncatedText = displayLines.join('\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectionArea(
        child: Text(
          truncatedText,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}