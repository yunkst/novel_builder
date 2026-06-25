import 'package:flutter/material.dart';
import '../utils/media_markup_parser.dart';

class ParagraphWidget extends StatefulWidget {
  final String paragraph;
  final int index;
  final double fontSize;
  final double textBrightness;
  final bool isCloseupMode;
  final bool isEditMode;
  final bool isSelected;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onLongPress;
  final ValueChanged<String>? onContentChanged;

  const ParagraphWidget({
    super.key,
    required this.paragraph,
    required this.index,
    required this.fontSize,
    this.textBrightness = 1.0,
    required this.isCloseupMode,
    required this.isEditMode,
    required this.isSelected,
    this.onTap,
    this.onLongPress,
    this.onContentChanged,
  });

  @override
  State<ParagraphWidget> createState() => _ParagraphWidgetState();
}

class _ParagraphWidgetState extends State<ParagraphWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.paragraph);
  }

  @override
  void didUpdateWidget(ParagraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有在外部内容真正改变时才更新
    if (oldWidget.paragraph != widget.paragraph) {
      // 检查是否是用户编辑导致的更新（避免覆盖用户输入）
      if (_controller.text != widget.paragraph) {
        _controller.value = TextEditingValue(
          text: widget.paragraph,
          selection: TextSelection.collapsed(offset: widget.paragraph.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否为插图标记 — 仅在编辑模式下展示原始标记文本
    if (MediaMarkupParser.isMediaMarkup(widget.paragraph)) {
      return _buildMediaMarkupWidget();
    }

    return _buildTextWidget();
  }

  /// 插图标记展示（编辑模式下展示原始标记，阅读模式下隐藏）
  Widget _buildMediaMarkupWidget() {
    if (widget.isEditMode) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.paragraph,
          style: TextStyle(
            fontSize: widget.fontSize * 0.9,
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    // 阅读模式下不渲染插图标记
    return const SizedBox.shrink();
  }

  Widget _buildTextWidget() {
    if (widget.isEditMode) {
      return _buildEditableText();
    }
    return _buildReadableText();
  }

  Widget _buildEditableText() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onContentChanged,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontSize: widget.fontSize,
          height: 1.8,
          letterSpacing: 0.5,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        maxLines: null,
      ),
    );
  }

  Widget _buildReadableText() {
    final baseColor = Theme.of(context).textTheme.bodyLarge?.color ??
        Theme.of(context).colorScheme.onSurface;
    final effectiveColor = baseColor.withValues(alpha: widget.textBrightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: widget.isCloseupMode && widget.onTap != null
              ? () => widget.onTap!(widget.index)
              : null,
          onLongPress: widget.onLongPress != null
              ? () => widget.onLongPress!(widget.index)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : null,
              border: widget.isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2)
                  : widget.isCloseupMode
                      ? Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          width: 1)
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.paragraph.trim(),
              style: TextStyle(
                fontSize: widget.fontSize,
                height: 1.8,
                letterSpacing: 0.5,
                color: effectiveColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}