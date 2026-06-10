import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:novel_app/models/hermes_message.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import '../../core/theme/app_colors.dart';

/// Hermes 聊天消息气泡
class HermesMessageBubble extends StatelessWidget {
  final HermesMessage message;
  final String? streamingContent;
  final List<AgentToolCall> agentToolCalls;
  final bool showTimestamp;

  const HermesMessageBubble({
    super.key,
    required this.message,
    this.streamingContent,
    this.agentToolCalls = const [],
    this.showTimestamp = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == HermesRole.user;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUser)
                  _buildContent(context)
                else
                  _buildAssistantContent(context),
                // Phase 4: Agent 工具调用卡片
                if (agentToolCalls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildAgentToolCalls(context),
                ],
              ],
            ),
          ),
          if (showTimestamp) ...[
            const SizedBox(height: 2),
            Text(
              _formatTime(message.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
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
      style: TextStyle(
        color: context.appColors.hermesOnBrand,
        fontSize: 15,
        height: 1.4,
      ),
    );
  }

  Widget _buildAssistantContent(BuildContext context) {
    final text = streamingContent ?? message.content;
    final isStreaming = streamingContent != null && message.content.isEmpty;

    if (isStreaming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: MarkdownBody(
              data: text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
                code: TextStyle(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildStreamingIndicator(context),
        ],
      );
    }

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          height: 1.4,
        ),
        h1: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        code: TextStyle(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingIndicator(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Phase 4: 渲染 Agent 工具调用卡片
  Widget _buildAgentToolCalls(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: agentToolCalls.map((call) {
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
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
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
