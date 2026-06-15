import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/hermes_providers.dart';
import 'package:novel_app/core/providers/reading_context_providers.dart';
import 'package:novel_app/models/hermes_message.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'package:novel_app/services/novel_agent/agent_scenario_factory.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/core/providers/webview_providers.dart';
import 'package:novel_app/widgets/hermes/hermes_confirmation_dialog.dart';
import 'package:novel_app/widgets/hermes/hermes_message_bubble.dart';
import '../../core/theme/app_colors.dart';

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
      if (nextCount > prevCount || (next.isLoading && next.streamingSegments.isNotEmpty)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }

      // Phase 4: 监听待处理的确认，弹出确认弹窗
      if (next.pendingConfirmation != null &&
          (prev?.pendingConfirmation?.toolCallId != next.pendingConfirmation!.toolCallId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showConfirmationDialog(next.pendingConfirmation!, notifier);
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
              if (chatState.scenarioId == ScenarioIds.webviewExtract)
                _buildWebViewInfoBar(),
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
    final chatState = ref.watch(hermesChatProvider);
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [appColors.hermesBrandStart, appColors.hermesBrandEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: appColors.hermesBrandStart.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: appColors.hermesOnBrand, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chatState.scenarioDisplayName,
                  style: TextStyle(
                    color: appColors.hermesOnBrand,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // 场景切换按钮
          PopupMenuButton<String>(
            icon: Icon(
              Icons.swap_horiz,
              color: appColors.hermesOnBrandMuted,
              size: 20,
            ),
            tooltip: '切换场景',
            onSelected: (scenarioId) {
              final info = AgentScenarioFactory.availableScenarios
                  .where((s) => s.id == scenarioId)
                  .firstOrNull;
              if (info != null) {
                notifier.switchScenario(info.id, info.displayName);
              }
            },
            itemBuilder: (context) => AgentScenarioFactory.availableScenarios
                .map((s) => PopupMenuItem(
                      value: s.id,
                      child: Row(
                        children: [
                          Text(s.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(s.displayName),
                          if (s.id == chatState.scenarioId) ...[
                            const Spacer(),
                            Icon(Icons.check, size: 16,
                                color: Theme.of(context).colorScheme.primary),
                          ],
                        ],
                      ),
                    ))
                .toList(),
          ),
          IconButton(
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: appColors.hermesOnBrandMuted,
              size: 20,
            ),
            onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
            tooltip: _isFullscreen ? '退出全屏' : '全屏',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: appColors.hermesOnBrandMuted, size: 20),
            onPressed: () {
              notifier.clearConversation();
            },
            tooltip: '清空对话',
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: appColors.hermesOnBrandMuted, size: 20),
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
        // 流式响应时，在最后一条 assistant 消息显示 streaming segments
        if (index == chatState.messages.length && chatState.isLoading) {
          return HermesMessageBubble(
            message: HermesMessage(role: HermesRole.assistant),
            streamingSegments: chatState.streamingSegments,
            showTimestamp: false,
          );
        }

        final message = chatState.messages[index];
        return HermesMessageBubble(message: message);
      },
    );
  }

  /// Phase 4: 弹出确认弹窗
  void _showConfirmationDialog(
    PendingConfirmation confirmation,
    HermesChatNotifier notifier,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => HermesConfirmationDialog(
        toolName: confirmation.toolName,
        args: confirmation.args,
        toolCallId: confirmation.toolCallId,
        description: describeToolAction(
          confirmation.toolName,
          confirmation.args,
        ),
        requestedAt: confirmation.requestedAt,
        onRespond: notifier.respondToConfirmation,
      ),
    );
  }

  /// 网页提取场景专用信息栏
  ///
  /// 显示当前 WebView 页面 URL 和本会话工具调用统计
  Widget _buildWebViewInfoBar() {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final currentUrl = ref.watch(webviewCurrentUrlProvider);
    final chatState = ref.watch(hermesChatProvider);

    // 从历史消息的 ToolCallSegment 统计
    int pageInfoCount = 0;
    int executeJsOk = 0;
    int executeJsFail = 0;
    int saveScriptOk = 0;
    bool hasCacheHit = false;

    void scan(List<HermesSegment> segs) {
      for (final s in segs) {
        if (s is! ToolCallSegment) {
          continue;
        }
        final c = s.call;
        switch (c.name) {
          case 'get_page_info':
            pageInfoCount++;
          case 'execute_js':
            if (c.status == AgentToolStatus.completed) {
              executeJsOk++;
            } else if (c.status == AgentToolStatus.error) {
              executeJsFail++;
            }
          case 'save_script':
            if (c.status == AgentToolStatus.completed) {
              saveScriptOk++;
            }
          case 'get_cached_script':
            if (c.status == AgentToolStatus.completed) {
              hasCacheHit = true;
            }
        }
      }
    }

    for (final m in chatState.messages) {
      scan(m.segments);
    }
    scan(chatState.streamingSegments);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: appColors.hermesAccent.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 14, color: appColors.hermesAccent),
              const SizedBox(width: 4),
              Text('当前页面', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: appColors.hermesAccent)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(currentUrl, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _chip(context, Icons.pageview, 'page_info', '$pageInfoCount'),
            _chip(context, Icons.check_circle_outline, 'execute_js', executeJsOk > 0 ? '$executeJsOk ok' : '0', theme.colorScheme.tertiary),
            if (executeJsFail > 0) _chip(context, Icons.error_outline, 'execute_js', '$executeJsFail fail', theme.colorScheme.error),
            if (saveScriptOk > 0) _chip(context, Icons.save_outlined, 'saved', '', theme.colorScheme.tertiary),
            if (hasCacheHit) _chip(context, Icons.flash_on, 'cache hit', '', theme.colorScheme.tertiary),
          ]),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, String value, [Color? color]) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    final text = value.isEmpty ? label : '$label $value';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: c)),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final chatState = ref.watch(hermesChatProvider);

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
            chatState.scenarioDisplayName,
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
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: appColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: appColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: appColors.error, fontSize: 12),
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
    final appColors = context.appColors;
    final quickPrompts =
        ScenarioQuickPrompts.forScenario(chatState.scenarioId);

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
          // 快速输入提示词（仅在场景配置了提示词且非加载时显示）
          if (quickPrompts.isNotEmpty && !chatState.isLoading)
            _buildQuickPrompts(quickPrompts, theme, appColors),
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
              if (chatState.isLoading)
                FilledButton.icon(
                  onPressed: () => notifier.cancelRequest(),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('停止'),
                  style: FilledButton.styleFrom(
                    backgroundColor: appColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => _sendMessage(notifier),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('发送'),
                  style: FilledButton.styleFrom(
                    backgroundColor: appColors.hermesAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 快速输入提示词 chip 行
  Widget _buildQuickPrompts(
    List<ScenarioQuickPrompt> prompts,
    ThemeData theme,
    AppColors appColors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: prompts.map((p) {
          return ActionChip(
            avatar: Icon(Icons.auto_awesome, size: 14,
                color: appColors.hermesAccent),
            label: Text(p.label, style: const TextStyle(fontSize: 12)),
            backgroundColor: appColors.hermesAccent.withValues(alpha: 0.08),
            side: BorderSide(
              color: appColors.hermesAccent.withValues(alpha: 0.2),
            ),
            onPressed: () => _insertPrompt(p.text),
          );
        }).toList(),
      ),
    );
  }

  /// 将提示词追加到输入框末尾
  void _insertPrompt(String text) {
    final current = _inputController.text;
    final sep = current.isEmpty ? '' : ' ';
    _inputController.text = current + sep + text;
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
    );
    _focusNode.requestFocus();
  }

  void _sendMessage(HermesChatNotifier notifier) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    notifier.sendMessage(text);

    _focusNode.requestFocus();
  }
}
