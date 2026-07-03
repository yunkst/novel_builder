import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:novel_app/models/agent_chat_message.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'chapter_rewrite_entry_card.dart';
import '../../core/theme/app_colors.dart';

/// Agent 聊天消息气泡
class AgentMessageBubble extends StatelessWidget {
  final AgentChatMessage message;
  /// 流式 segments（当前回合进行中时非空，历史消息为 null）
  final List<AgentChatSegment>? streamingSegments;
  final bool showTimestamp;

  /// 回滚回调（仅 user 消息使用）：点击按钮后回滚至此消息,
  /// 由 [AgentChatDialog] 实现确认弹框 + 输入框回填。
  /// 传 null 表示不渲染回滚按钮。
  final VoidCallback? onRollback;

  const AgentMessageBubble({
    super.key,
    required this.message,
    this.streamingSegments,
    this.showTimestamp = true,
    this.onRollback,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AgentChatRole.user;

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
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                ),
                if (isUser && onRollback != null) ...[
                  const SizedBox(width: 6),
                  _buildRollbackButton(context),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getBubbleColor(BuildContext context) {
    final isUser = message.role == AgentChatRole.user;
    if (isUser) {
      return context.appColors.agentAccent;
    }
    return context.appColors.chatRoleBubble;
  }

  /// 回滚按钮（小图标 + tooltip）,仅 user 消息 + onRollback != null 时渲染
  Widget _buildRollbackButton(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return Tooltip(
      message: '回滚至此',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onRollback,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.undo,
            size: 14,
            color: muted,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final text = message.content;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: context.appColors.agentOnBrand,
            height: 1.4,
          ),
    );
  }

  /// 按 segments 顺序交替渲染文本片段和工具调用卡片
  Widget _buildAssistantContent(
    BuildContext context,
    List<AgentChatSegment> segments,
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
                      _runningLabel(call),
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
          // update_chapter_content / create_chapter 成功时，渲染跳转阅读器入口
          if ((call.name == 'update_chapter_content' || call.name == 'create_chapter') &&
              call.status == AgentToolStatus.completed &&
              _rewriteEntry != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ChapterRewriteEntryCard(
                data: _rewriteEntry!,
                titleText: call.name == 'create_chapter'
                    ? '查看新创建的章节'
                    : '查看重写后的章节',
              ),
            ),
        ],
      ),
    );
  }

  /// 解析工具结果中的重写成功信息（缓存，避免每次 build 重复解析）
  ChapterRewriteEntryData? get _rewriteEntry =>
      parseRewriteEntry(widget.call.result);

  /// running 态标题文案：内部走 LLM 流式的工具显示「已生成 N 字」进度，
  /// 其他工具维持原 `工具名...` 转圈语义。
  String _runningLabel(AgentToolCall call) {
    if (call.status != AgentToolStatus.running) return call.name;
    final progress = call.progressChars;
    if (progress != null && progress > 0) {
      return '${call.name} · 已生成 $progress 字...';
    }
    return '${call.name}...';
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