/// 破坏性操作确认对话框
///
/// Phase 4: Agent 调用破坏性工具前弹出，让用户确认或拒绝
library;

import 'dart:convert';

import 'package:flutter/material.dart';

class HermesConfirmationDialog extends StatefulWidget {
  final String toolName;
  final Map<String, dynamic> args;
  final String toolCallId;
  final String description;
  final DateTime requestedAt;
  final void Function(bool approved) onRespond;

  const HermesConfirmationDialog({
    super.key,
    required this.toolName,
    required this.args,
    required this.toolCallId,
    required this.description,
    required this.requestedAt,
    required this.onRespond,
  });

  @override
  State<HermesConfirmationDialog> createState() =>
      _HermesConfirmationDialogState();
}

class _HermesConfirmationDialogState extends State<HermesConfirmationDialog> {
  bool _isExpanded = false;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 30;
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _remainingSeconds = (30 -
                DateTime.now().difference(widget.requestedAt).inSeconds)
            .clamp(0, 30);
      });
      if (_remainingSeconds <= 0) {
        // 超时自动拒绝
        widget.onRespond(false);
        if (mounted) Navigator.of(context).pop();
        return false;
      }
      return mounted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded,
          color: theme.colorScheme.error, size: 32),
      title: const Text('确认修改'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.description,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '工具: ${widget.toolName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isExpanded ? '收起参数' : '查看参数',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    _formatArgs(widget.args),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '$_remainingSeconds 秒后自动拒绝',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onRespond(false);
            Navigator.of(context).pop();
          },
          child: const Text('拒绝'),
        ),
        FilledButton(
          onPressed: () {
            widget.onRespond(true);
            Navigator.of(context).pop();
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  String _formatArgs(Map<String, dynamic> args) {
    try {
      return const JsonEncoder.withIndent('  ').convert(args);
    } catch (_) {
      return args.toString();
    }
  }
}

/// 工具名到用户友好描述的映射
String describeToolAction(String toolName, Map<String, dynamic> args) {
  switch (toolName) {
    case 'update_chapter_content':
      final content = args['content'] as String? ?? '';
      return '将完全替换指定章节的正文（约 ${content.length} 字）';
    case 'create_custom_chapter':
      return '将创建新章节 "${args['title']}"';
    case 'update_character':
      return '将更新角色 "${args['name']}"';
    case 'create_character':
      return '将创建新角色 "${args['name']}"';
    case 'update_background_setting':
      return '将更新小说的背景设定（约 ${(args['setting'] as String? ?? '').length} 字）';
    case 'update_outline':
      return '将保存/更新大纲 "${args['title']}"';
    default:
      return '将执行工具 $toolName';
  }
}