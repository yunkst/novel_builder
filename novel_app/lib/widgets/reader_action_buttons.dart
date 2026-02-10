import 'package:flutter/material.dart';

class ReaderActionButtons extends StatelessWidget {
  final bool isCloseupMode;
  final bool hasSelectedParagraphs;
  final bool isAutoScrolling;
  final bool isAutoScrollPaused;
  final VoidCallback onRewritePressed;
  final VoidCallback onToggleCloseupMode;
  final VoidCallback onToggleAutoScroll;

  const ReaderActionButtons({
    super.key,
    required this.isCloseupMode,
    required this.hasSelectedParagraphs,
    required this.isAutoScrolling,
    this.isAutoScrollPaused = false,
    required this.onRewritePressed,
    required this.onToggleCloseupMode,
    required this.onToggleAutoScroll,
  });

  @override
  Widget build(BuildContext context) {
    // 如果在特写模式下且有选中段落，显示改写按钮
    if (isCloseupMode && hasSelectedParagraphs) {
      return FloatingActionButton.extended(
        onPressed: onRewritePressed,
        icon: const Icon(Icons.edit),
        label: const Text('改写'),
        backgroundColor: Colors.transparent,
        heroTag: 'rewrite',
      );
    }

    // 正常阅读模式下，显示特写模式和自动滚屏按钮
    return Padding(
      padding: const EdgeInsets.only(bottom: 120.0), // 避免与底部章节切换按钮重叠
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 特写模式切换按钮（上方）
          FloatingActionButton(
            onPressed: onToggleCloseupMode,
            tooltip: isCloseupMode ? '关闭特写模式' : '开启特写模式',
            heroTag: 'closeup_mode',
            backgroundColor: Colors.transparent,
            child:
                Icon(isCloseupMode ? Icons.visibility : Icons.visibility_off),
          ),
          const SizedBox(height: 16), // 按钮间距
          // 自动滚屏按钮（下方）
          FloatingActionButton(
            onPressed: onToggleAutoScroll,
            tooltip: isAutoScrolling
                ? (isAutoScrollPaused ? '恢复自动滚动' : '暂停自动滚动')
                : '开始自动滚动',
            heroTag: 'auto_scroll',
            backgroundColor: Colors.transparent,
            child: Icon(isAutoScrolling
                ? (isAutoScrollPaused ? Icons.play_arrow : Icons.pause)
                : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
