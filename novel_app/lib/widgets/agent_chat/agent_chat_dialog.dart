import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/core/providers/agent_scenario_provider.dart';
import 'package:novel_app/core/providers/chat_session_providers.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/core/providers/scenario_session.dart';
import 'package:novel_app/services/novel_agent/agent_scenario_factory.dart';
import 'package:novel_app/core/providers/reading_context_providers.dart';
import 'package:novel_app/models/agent_chat_message.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/core/providers/webview_providers.dart';
import 'package:novel_app/screens/llm_config_management_screen.dart';
import 'package:novel_app/services/llm_config_service.dart';
import 'package:novel_app/widgets/agent_chat/chat_history_sheet.dart';
import 'package:novel_app/widgets/agent_chat/agent_message_bubble.dart';
import 'package:novel_app/widgets/agent_chat/agent_novel_picker_dialog.dart';
import 'package:novel_app/widgets/agent_chat/agent_scenario_config_dialog.dart';
import '../../core/theme/app_colors.dart';

/// Agent 聊天对话框
class AgentChatDialog extends ConsumerStatefulWidget {
  const AgentChatDialog({super.key});

  @override
  ConsumerState<AgentChatDialog> createState() => _AgentChatDialogState();
}

class _AgentChatDialogState extends ConsumerState<AgentChatDialog> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isFullscreen = false;
  // 输入框是否有内容(驱动发送按钮 enabled/disabled 视觉)
  bool _hasText = false;
  // 消息列表是否贴底:驱动"回到底部"按钮显隐 + 新消息自动跟随策略
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _hasText = _inputController.text.trim().isNotEmpty;
    _inputController.addListener(_onInputChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  /// 输入框内容变化时,仅在"有内容 ↔ 无内容"边界触发重建
  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  /// 滚动监听:判断是否贴底,驱动"回到底部"按钮显隐
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = (position.maxScrollExtent - position.pixels) <= 80;
    if (_isAtBottom != atBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(currentChatStateProvider);
    final session = ref.read(currentSessionProvider);

    ref.listen(currentChatStateProvider, (prev, next) {
      final prevCount = prev?.messages.length ?? 0;
      final nextCount = next.messages.length;
      final hasNew = nextCount > prevCount ||
          (next.isLoading && next.streamingSegments.isNotEmpty);
      if (!hasNew) return;
      // 仅在用户已贴底时自动跟随,避免打断用户浏览历史
      if (!_isAtBottom) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
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
              _buildHeader(session),
              if (chatState.scenarioId == ScenarioIds.webviewExtract)
                _buildWebViewInfoBar(),
              if (chatState.scenarioId == ScenarioIds.writing)
                _buildCurrentNovelBar(chatState),
              Expanded(child: _buildMessageList(chatState)),
              if (chatState.error != null && !chatState.isLoading)
                _buildErrorBar(chatState.error!, session),
              _buildContextTag(),
              _buildInputBar(chatState, session),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ScenarioSession? session) {
    final chatState = ref.watch(currentChatStateProvider);
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [appColors.agentBrandStart, appColors.agentBrandEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: appColors.agentBrandStart.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一排:场景名称(独立一行)
          Row(
            children: [
              Icon(Icons.auto_awesome, color: appColors.agentOnBrand, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chatState.scenarioDisplayName,
                  style: TextStyle(
                    color: appColors.agentOnBrand,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二排:操作按钮(靠右)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 会话历史按钮（运行中禁用，提示等待）
              IconButton(
                icon: Icon(Icons.history,
                    color: appColors.agentOnBrandMuted, size: 20),
                tooltip: '会话历史',
                onPressed: chatState.isLoading
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('当前对话进行中，请等待完成后再切换'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : () => _showHistorySheet(),
              ),
              // 场景切换按钮
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.swap_horiz,
                  color: appColors.agentOnBrandMuted,
                  size: 20,
                ),
                tooltip: '切换场景',
                onSelected: (scenarioId) {
                  final info = AgentScenarioFactory.availableScenarios
                      .where((s) => s.id == scenarioId)
                      .firstOrNull;
                  if (info != null) {
                    // 切换场景：设置当前 scenario + 懒创建目标 session
                    ref.read(currentAgentScenarioProvider.notifier).state = info.id;
                    // 新 scenario 还没选会话，重置 sessionId 让 ScenarioSession 自取最近
                    ref.read(currentChatSessionIdProvider.notifier).state = null;
                    ref.read(scenarioSessionsProvider.notifier).get(info.id);
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
              // 场景配置按钮
              IconButton(
                icon: Icon(Icons.tune,
                    color: appColors.agentOnBrandMuted, size: 20),
                tooltip: '场景配置',
                onPressed: () => _showScenarioConfigDialog(chatState),
              ),
              IconButton(
                icon: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: appColors.agentOnBrandMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
                tooltip: _isFullscreen ? '退出全屏' : '全屏',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: appColors.agentOnBrandMuted, size: 20),
                onPressed: () {
                  session?.clearConversation();
                },
                tooltip: '清空对话',
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: appColors.agentOnBrandMuted, size: 20),
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(AgentChatState chatState) {
    if (chatState.messages.isEmpty && !chatState.isLoading) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            // 流式响应时，在最后一条 assistant 消息显示 streaming segments
            if (index == chatState.messages.length && chatState.isLoading) {
              return AgentMessageBubble(
                message: AgentChatMessage(role: AgentChatRole.assistant),
                streamingSegments: chatState.streamingSegments,
                showTimestamp: false,
              );
            }

            final message = chatState.messages[index];
            // 仅 user 消息提供回滚入口；agent 运行中禁用(防止与并发状态冲突)
            final canRollback = message.role == AgentChatRole.user && !chatState.isLoading;
            return AgentMessageBubble(
              message: message,
              onRollback: canRollback ? () => _handleRollback(index) : null,
            );
          },
        ),
        // 回到底部浮动按钮:仅当用户向上浏览离开底部时淡入
        Positioned(
          right: 16,
          bottom: 16,
          child: IgnorePointer(
            ignoring: _isAtBottom,
            child: AnimatedOpacity(
              opacity: _isAtBottom ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: _buildJumpToBottomButton(),
            ),
          ),
        ),
      ],
    );
  }

  /// "回到底部"浮动按钮
  Widget _buildJumpToBottomButton() {
    final appColors = context.appColors;
    return Material(
      color: appColors.agentAccent,
      elevation: 4,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _scrollToBottom,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 24,
          ),
        ),
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
    final chatState = ref.watch(currentChatStateProvider);

    // 从历史消息的 ToolCallSegment 统计
    int pageInfoCount = 0;
    int executeJsOk = 0;
    int executeJsFail = 0;
    int saveScriptOk = 0;
    bool hasCacheHit = false;

    void scan(List<AgentChatSegment> segs) {
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
        color: appColors.agentAccent.withValues(alpha: 0.06),
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
              Icon(Icons.link, size: 14, color: appColors.agentAccent),
              const SizedBox(width: 4),
              Text('当前页面', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: appColors.agentAccent)),
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
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: c,
            )),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final chatState = ref.watch(currentChatStateProvider);

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

  Widget _buildErrorBar(String error, ScenarioSession? session) {
    final appColors = context.appColors;
    // 命中"LLM 未配置"关键字 → 显示"去设置"按钮；否则显示"重试"按钮
    final isNotConfigured =
        error.contains(LlmConfigService.notConfiguredMessage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const SizedBox(width: 8),
          if (isNotConfigured)
            TextButton.icon(
              onPressed: session == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const LlmConfigManagementScreen(),
                        ),
                      ),
              icon: const Icon(Icons.settings, size: 14),
              label: const Text('去设置', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: appColors.error,
              ),
            )
          else
            TextButton.icon(
              onPressed: session == null
                  ? null
                  : () => session.retryLastRound(),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('重试', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: appColors.error,
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

  /// 写作场景专用：展示当前小说（Agent 工作上下文）
  ///
  /// 当 AI 调用 `select_novel` 或 `create_novel` 工具后，UI 会自动更新展示。
  /// 用户也可点击"切换"按钮手动选择。
  Widget _buildCurrentNovelBar(AgentChatState chatState) {
    final appColors = context.appColors;
    final currentNovel = chatState.currentNovel;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: appColors.agentAccent.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book, size: 16, color: appColors.agentAccent),
          const SizedBox(width: 6),
          Expanded(
            child: currentNovel == null
                ? Text(
                    '尚未选择小说 — 请 AI 调用 select_novel 或点击右侧切换',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '当前小说：',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      TextSpan(
                        text: currentNovel.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: appColors.agentAccent,
                        ),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          TextButton.icon(
            onPressed: () => _showNovelPickerDialog(chatState),
            icon: const Icon(Icons.swap_horiz, size: 14),
            label: const Text('切换', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 28),
              foregroundColor: appColors.agentAccent,
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出小说选择对话框
  Future<void> _showNovelPickerDialog(AgentChatState chatState) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => const AgentNovelPickerDialog(),
    );
    if (picked != null) {
      final session = ref.read(currentSessionProvider);
      await session?.selectNovel(picked);
    }
  }

  /// 弹出会话历史底部抽屉（当前 scenario 下的会话列表）
  ///
  /// 运行中拦截已由按钮 onPressed 处理，这里只负责拉起 sheet。
  Future<void> _showHistorySheet() async {
    final scenarioId = ref.read(currentAgentScenarioProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChatHistorySheet(scenarioId: scenarioId),
    );
  }

  /// 弹出场景级 LLM 配置对话框
  ///
  /// 让用户为当前场景单独配置 LLM 后端（覆盖全局默认）。
  /// 配置写入 SharedPreferences，下次 sendMessage 自动生效。
  Future<void> _showScenarioConfigDialog(AgentChatState chatState) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => AgentScenarioConfigDialog(
        scenarioId: chatState.scenarioId,
      ),
    );
  }

  Widget _buildInputBar(AgentChatState chatState, ScenarioSession? session) {
    final theme = Theme.of(context);
    final appColors = context.appColors;
    final quickPrompts =
        ScenarioQuickPrompts.forScenario(chatState.scenarioId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // 微信式输入区：输入框与发送/停止按钮同行
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  enabled: !chatState.isLoading,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText:
                        chatState.isLoading ? '等待回复...' : '输入消息...',
                    hintStyle: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    filled: true,
                    fillColor: appColors.chatInputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 8),
              _buildSendStopButton(chatState, session, theme, appColors),
            ],
          ),
        ],
      ),
    );
  }

  /// 发送/停止按钮（圆形 40x40，微信风格）
  ///
  /// 状态优先级：isLoading（停止）> _hasText（可发送）> 空内容（禁用）。
  Widget _buildSendStopButton(
    AgentChatState chatState,
    ScenarioSession? session,
    ThemeData theme,
    AppColors appColors,
  ) {
    if (chatState.isLoading) {
      return _circleIconButton(
        icon: Icons.stop_rounded,
        bg: appColors.error,
        fg: appColors.agentOnBrand,
        onPressed: () => session?.cancel(),
        tooltip: '停止',
      );
    }
    if (_hasText) {
      return _circleIconButton(
        icon: Icons.send_rounded,
        bg: appColors.agentAccent,
        fg: appColors.agentOnBrand,
        onPressed: () => _sendMessage(session),
        tooltip: '发送',
      );
    }
    return _circleIconButton(
      icon: Icons.send_rounded,
      bg: theme.colorScheme.outline.withValues(alpha: 0.3),
      fg: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      onPressed: null,
      tooltip: '发送',
    );
  }

  /// 圆形图标按钮（无文字，固定 40x40）
  Widget _circleIconButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 20, color: fg),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
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
                color: appColors.agentAccent),
            label: Text(p.label, style: const TextStyle(fontSize: 12)),
            backgroundColor: appColors.agentAccent.withValues(alpha: 0.08),
            side: BorderSide(
              color: appColors.agentAccent.withValues(alpha: 0.2),
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

  void _sendMessage(ScenarioSession? session) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    session?.sendMessage(text);

    _focusNode.requestFocus();
  }

  /// 回滚到指定 user 消息 — 弹确认框,通过后删除该消息及之后所有记录,
  /// 并把该消息文本回填到输入框(等待用户编辑后重新发送)。
  ///
  /// 索引 [messageIndex] 对应点击时刻的 messages 位置;弹框期间列表可能已变化,
  /// 故内部用 ref.read 重新读取最新长度计算"将删除的条数"。
  Future<void> _handleRollback(int messageIndex) async {
    final chatState = ref.read(currentChatStateProvider);
    if (chatState.isLoading) return;

    final messages = chatState.messages;
    if (messageIndex < 0 || messageIndex >= messages.length) return;
    final target = messages[messageIndex];
    if (target.role != AgentChatRole.user) return;

    final willRemove = messages.length - messageIndex;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('回滚对话'),
        content: Text(
          '将删除此消息之后的 $willRemove 条记录(含此消息),\n'
          '并把此消息内容放回输入框,是否继续?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认回滚'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final session = ref.read(currentSessionProvider);
    session?.rollbackToMessage(
      messageIndex,
      contentCallback: (text) {
        if (!mounted) return;
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(
          offset: text.length,
        );
        // 手动触发一次输入监听,确保 _hasText / 发送按钮状态刷新
        final hasText = _inputController.text.trim().isNotEmpty;
        if (_hasText != hasText) {
          setState(() => _hasText = hasText);
        }
        _focusNode.requestFocus();
      },
    );
  }
}
