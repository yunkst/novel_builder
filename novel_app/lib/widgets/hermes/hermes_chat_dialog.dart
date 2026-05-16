import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/hermes_providers.dart';
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

    return Dialog(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.92,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(notifier),
              Expanded(child: _buildMessageList(chatState)),
              if (chatState.error != null) _buildErrorBar(chatState.error!),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              enabled: !chatState.isLoading,
              decoration: InputDecoration(
                hintText: chatState.isLoading ? '等待回复...' : '输入消息...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: chatState.isLoading ? null : (_) => _sendMessage(notifier),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: chatState.isLoading
                ? const IconButton(
                    onPressed: null,
                    icon: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton.filled(
                    onPressed: () => _sendMessage(notifier),
                    icon: const Icon(Icons.send, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                    ),
                  ),
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

    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // 重新获取焦点
    _focusNode.requestFocus();
  }
}
