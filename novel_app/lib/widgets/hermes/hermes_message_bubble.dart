import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:novel_app/models/hermes_message.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import '../../core/theme/app_colors.dart';

/// Hermes 聊天消息气泡
class HermesMessageBubble extends StatelessWidget {
  final HermesMessage message;
  /// 流式 segments（当前回合进行中时非空，历史消息为 null）
  final List<HermesSegment>? streamingSegments;
  final bool showTimestamp;

  const HermesMessageBubble({
    super.key,
    required this.message,
    this.streamingSegments,
    this.showTimestamp = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == HermesRole.user;

    // 流式气泡用 streamingSegments，历史气泡用 message.segments
    final effectiveSegments = streamingSegments ?? message.segments;
    final isStreaming = streamingSegments != null;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 8,
        right: isUser ? 8 : 48,
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _getBubbleColor(context),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.appColors.avatarShadow.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isUser
                ? _buildContent(context)
                : _buildAssistantContent(context, effectiveSegments, isStreaming),
          ),
          if (showTimestamp) ...[
            const SizedBox(height: 2),
            Text(
              _formatTime(message.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBubbleColor(BuildContext context) {
    final isUser = message.role == HermesRole.user;
    if (isUser) {
      return context.appColors.hermesAccent;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Widget _buildContent(BuildContext context) {
    final text = message.content;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: context.appColors.hermesOnBrand,
            height: 1.4,
          ),
    );
  }

  /// 按 segments 顺序交替渲染文本片段和工具调用卡片
  Widget _buildAssistantContent(
    BuildContext context,
    List<HermesSegment> segments,
    bool isStreaming,
  ) {
    if (segments.isEmpty) return const SizedBox.shrink();

    final lastIndex = segments.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.asMap().entries.map((entry) {
        final idx = entry.key;
        final segment = entry.value;
        final isLast = idx == lastIndex;

        return switch (segment) {
          TextSegment s => _buildTextSegment(context, s, isStreaming && isLast),
          ToolCallSegment s => Padding(
              padding: EdgeInsets.only(
                // 与上一个元素之间留间距
                top: idx > 0 ? 8 : 0,
                bottom: isLast ? 0 : 4,
              ),
              child: AgentToolCallCard(call: s.call),
            ),
        };
      }).toList(),
    );
  }

  Widget _buildTextSegment(
    BuildContext context,
    TextSegment segment,
    bool isStreaming,
  ) {
    final text = segment.content;

    if (isStreaming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: MarkdownBody(
              data: text,
              styleSheet: _markdownStyle(context),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    }

    if (text.isEmpty) return const SizedBox.shrink();

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: _markdownStyle(context),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownStyleSheet(
      p: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
      h1: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      h2: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      h3: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        color: theme.colorScheme.primary,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// 可展开的工具调用卡片
///
/// 每个卡片独立管理自己的展开/折叠状态。
/// 使用 StatefulWidget 确保流式更新时不丢失展开状态。
class AgentToolCallCard extends StatefulWidget {
  final AgentToolCall call;
  const AgentToolCallCard({super.key, required this.call});

  @override
  State<AgentToolCallCard> createState() => _AgentToolCallCardState();
}

class _AgentToolCallCardState extends State<AgentToolCallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final call = widget.call;

    final statusIcon = switch (call.status) {
      AgentToolStatus.running => Icons.sync,
      AgentToolStatus.completed => Icons.check_circle,
      AgentToolStatus.error => Icons.error,
      AgentToolStatus.rejected => Icons.cancel,
    };
    final statusColor = switch (call.status) {
      AgentToolStatus.running => theme.colorScheme.primary,
      AgentToolStatus.completed => theme.colorScheme.tertiary,
      AgentToolStatus.error => theme.colorScheme.error,
      AgentToolStatus.rejected => theme.colorScheme.outline,
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏（可点击展开/折叠）
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      call.status == AgentToolStatus.running
                          ? '${call.name}...'
                          : call.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          // 展开内容
          if (_expanded) _buildExpandedBody(context, call),
        ],
      ),
    );
  }

  Widget _buildExpandedBody(BuildContext context, AgentToolCall call) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 6),
          _buildSection(
            context,
            '参数',
            _formatJson(call.arguments),
          ),
          if (call.result != null) ...[
            const SizedBox(height: 6),
            _buildSection(
              context,
              call.status == AgentToolStatus.error ? '错误' : '结果',
              _formatJsonString(call.result!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String label, String content) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
          ),
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  String _formatJson(Map<String, dynamic> args) {
    try {
      return const JsonEncoder.withIndent('  ').convert(args);
    } catch (_) {
      return args.toString();
    }
  }

  String _formatJsonString(String s) {
    try {
      final decoded = jsonDecode(s);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return s;
    }
  }
}