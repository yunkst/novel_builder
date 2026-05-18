import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/hermes_providers.dart';
import 'package:novel_app/core/providers/reading_context_providers.dart';
import 'package:novel_app/models/hermes_message.dart';
import 'package:novel_app/widgets/hermes/hermes_message_bubble.dart';
import 'package:novel_app/widgets/hermes/hermes_settings_dialog.dart';

/// Hermes 聊天对话框
class HermesChatDialog extends ConsumerStatefulWidget {
  const HermesChatDialog({super.key});

  @override
  ConsumerState<HermesChatDialog> createState() => _HermesChatDialogState();
}

class _HermesChatDialogState extends ConsumerState<HermesChatDialog> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(hermesChatProvider);
    final notifier = ref.read(hermesChatProvider.notifier);

    ref.listen(hermesChatProvider, (prev, next) {
      final prevCount = prev?.messages.length ?? 0;
      final nextCount = next.messages.length;
      if (nextCount > prevCount || (next.isLoading && next.streamingContent != null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    return Dialog(
      insetPadding: _isFullscreen ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _isFullscreen ? double.infinity : MediaQuery.of(context).size.width * 0.92,
            maxHeight: _isFullscreen ? double.infinity : MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(notifier),
              Expanded(child: _buildMessageList(chatState)),
              if (chatState.error != null) _buildErrorBar(chatState.error!),
              _buildContextTag(),
              _buildInputBar(chatState, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(HermesChatNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Hermes AI 助手',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
            tooltip: _isFullscreen ? '退出全屏' : '全屏',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const HermesSettingsDialog(),
              );
            },
            tooltip: '设置',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
            onPressed: () {
              notifier.clearConversation();
            },
            tooltip: '清空对话',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(HermesChatState chatState) {
    if (chatState.messages.isEmpty && !chatState.isLoading) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // 流式响应时，在最后一条 assistant 消息显示 streaming content
        if (index == chatState.messages.length && chatState.isLoading) {
          return HermesMessageBubble(
            message: HermesMessage.assistant(''),
            streamingContent: chatState.streamingContent,
            activeToolProgress: chatState.activeToolProgress,
            showTimestamp: false,
          );
        }

        final message = chatState.messages[index];
        return HermesMessageBubble(message: message);
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Hermes AI 助手',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入消息开始对话',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextTag() {
    final readingContext = ref.watch(readingContextProvider);
    if (!readingContext.hasContext) return const SizedBox.shrink();

    final label = readingContext.displayLabel;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 0),
      child: Wrap(
        spacing: 6,
        children: [
          ActionChip(
            avatar: const Icon(Icons.book, size: 14),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onPressed: () {
              final current = _inputController.text;
              final sep = current.isEmpty ? '' : ' ';
              _inputController.text = current + sep + label;
              _inputController.selection = TextSelection.collapsed(
                offset: _inputController.text.length,
              );
              _focusNode.requestFocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(HermesChatState chatState, HermesChatNotifier notifier) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _inputController,
            focusNode: _focusNode,
            enabled: !chatState.isLoading,
            maxLines: 5,
            minLines: 1,
            decoration: InputDecoration(
              hintText: chatState.isLoading ? '等待回复...' : '输入消息...（Enter 换行，点击发送）',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: chatState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.icon(
                        onPressed: () => _sendMessage(notifier),
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('发送'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage(HermesChatNotifier notifier) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    notifier.sendMessage(text);

    _focusNode.requestFocus();
  }
}
