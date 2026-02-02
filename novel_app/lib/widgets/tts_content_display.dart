import 'package:flutter/material.dart';
import 'common/common_widgets.dart';

/// TTS内容显示组件
class TtsContentDisplay extends StatefulWidget {
  final List<String> paragraphs;
  final int currentIndex;
  final ValueChanged<int>? onParagraphTap;

  const TtsContentDisplay({
    super.key,
    required this.paragraphs,
    required this.currentIndex,
    this.onParagraphTap,
  });

  @override
  State<TtsContentDisplay> createState() => _TtsContentDisplayState();
}

class _TtsContentDisplayState extends State<TtsContentDisplay> {
  @override
  Widget build(BuildContext context) {
    if (widget.paragraphs.isEmpty) {
      return const EmptyStateWidget(
        message: '暂无内容',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: widget.paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = widget.paragraphs[index];
        final isCurrent = index == widget.currentIndex;
        final isPast = index < widget.currentIndex;

        return GestureDetector(
          onTap: () => widget.onParagraphTap?.call(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primaryContainer
                  : isPast
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.06)
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
                        ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)
                        : Theme.of(context).colorScheme.onSurface,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        );
      },
    );
  }
}
