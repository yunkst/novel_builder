import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/scenario_sessions_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/novel_agent/agent_scenario.dart';
import 'agent_icons.dart';

class AgentChatComposer extends ConsumerStatefulWidget {
  final void Function(String text, int? mediaId)? onSend;
  final VoidCallback? onAttachMedia;
  final int? attachedMediaId;
  final void Function(int? mediaId)? onClearAttachment;

  const AgentChatComposer({
    super.key,
    this.onSend,
    this.onAttachMedia,
    this.attachedMediaId,
    this.onClearAttachment,
  });

  @override
  ConsumerState<AgentChatComposer> createState() => _AgentChatComposerState();
}

class _AgentChatComposerState extends ConsumerState<AgentChatComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text, widget.attachedMediaId);
    _controller.clear();
    widget.onClearAttachment?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(currentChatStateProvider);
    final colors = context.appColors;
    final prompts = ScenarioQuickPrompts.forScenario(chatState.scenarioId);
    final isSupp = chatState.isLoading && chatState.supplementaryCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prompts.isNotEmpty && !chatState.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in prompts)
                    ActionChip(
                      avatar: Icon(AgentIcons.wand, size: 14),
                      label: Text(p.label, style: const TextStyle(fontSize: 11)),
                      backgroundColor: colors.chatInputBackground,
                      side: BorderSide(color: colors.divider),
                      onPressed: () {
                        _controller.text = p.text;
                        _controller.selection = TextSelection(
                            baseOffset: p.text.length, extentOffset: p.text.length);
                      },
                    ),
                ],
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.chatInputBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 1,
                      style: TextStyle(
                          fontSize: 13, color: colors.chatPrimaryText),
                      decoration: InputDecoration(
                        hintText: '和写作助手说点什么…',
                        hintStyle: TextStyle(color: colors.chatHintText),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '添加图片',
                  icon: Icon(AgentIcons.plus, size: 19),
                  color: colors.inkSoft,
                  onPressed: widget.onAttachMedia,
                ),
                const SizedBox(width: 2),
                _SendButton(
                  enabled: _hasText,
                  isSupplementary: isSupp,
                  onPressed: _send,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Enter 发送 · Shift+Enter 换行',
              style: TextStyle(
                  fontSize: 9.5,
                  color: colors.chatHintText,
                  fontFamily: 'JetBrainsMono')),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool isSupplementary;
  final VoidCallback onPressed;
  const _SendButton(
      {required this.enabled, required this.isSupplementary, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = enabled
        ? (isSupplementary
            ? colors.chatButtonPrimary.withValues(alpha: 0.5)
            : colors.chatButtonPrimary)
        : colors.chatDivider;
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        boxShadow: enabled && !isSupplementary
            ? [
                BoxShadow(
                  color: colors.chatButtonPrimary.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: IconButton(
        tooltip: '发送',
        icon: Icon(AgentIcons.send, size: 17),
        color: colors.agentOnBrand,
        padding: EdgeInsets.zero,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
