import 'package:flutter/material.dart';

/// TTS内容显示组件
class TtsContentDisplay extends StatefulWidget {
  final List<String> paragraphs;
  final int currentIndex;

  const TtsContentDisplay({
    super.key,
    required this.paragraphs,
    required this.currentIndex,
  });

  @override
  State<TtsContentDisplay> createState() => _TtsContentDisplayState();
}

class _TtsContentDisplayState extends State<TtsContentDisplay> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(TtsContentDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当当前段落索引变化时，滚动到该段落
    if (widget.currentIndex != oldWidget.currentIndex) {
      _scrollToCurrentParagraph();
    }
  }

  void _scrollToCurrentParagraph() {
    if (_scrollController.hasClients) {
      // 计算目标位置（每个段落大约占80高度）
      final targetOffset = widget.currentIndex * 80.0;
      final maxScroll = _scrollController.position.maxScrollExtent;

      _scrollController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paragraphs.isEmpty) {
      return const Center(
        child: Text('暂无内容'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: widget.paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = widget.paragraphs[index];
        final isCurrent = index == widget.currentIndex;
        final isPast = index < widget.currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? Theme.of(context).colorScheme.primaryContainer
                : isPast
                    ? Colors.grey.shade100
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isCurrent
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Text(
            paragraph,
            style: TextStyle(
              fontSize: isCurrent ? 22 : 18,
              height: 1.6,
              color: isCurrent
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : isPast
                      ? Colors.grey.shade600
                      : Theme.of(context).colorScheme.onSurface,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.justify,
          ),
        );
      },
    );
  }
}
