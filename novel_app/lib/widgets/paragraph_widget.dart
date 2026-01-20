import 'package:flutter/material.dart';
import '../utils/media_markup_parser.dart';
import 'scene_image_preview.dart';

class ParagraphWidget extends StatefulWidget {
  final String paragraph;
  final int index;
  final double fontSize;
  final bool isCloseupMode;
  final bool isEditMode;
  final bool isSelected;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onLongPress;
  final ValueChanged<String>? onContentChanged;
  final Function(String taskId, String imageUrl, int imageIndex)? onImageTap;
  final Function(String taskId)? onImageDelete;
  final Function(String taskId)? generateVideoFromIllustration;
  final int? modelWidth;
  final int? modelHeight;

  const ParagraphWidget({
    super.key,
    required this.paragraph,
    required this.index,
    required this.fontSize,
    required this.isCloseupMode,
    required this.isEditMode,
    required this.isSelected,
    this.onTap,
    this.onLongPress,
    this.onContentChanged,
    this.onImageTap,
    this.onImageDelete,
    this.generateVideoFromIllustration,
    this.modelWidth,
    this.modelHeight,
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
    // 监听文本变化，但不触发重建
    _controller.addListener(() {
      if (widget.onContentChanged != null) {
        widget.onContentChanged!(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(ParagraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有在外部内容真正改变时才更新
    if (oldWidget.paragraph != widget.paragraph) {
      // 检查是否是用户编辑导致的更新（避免覆盖用户输入）
      if (_controller.text != widget.paragraph) {
        _controller.text = widget.paragraph;
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
    // 检查是否为插图标记
    if (MediaMarkupParser.isMediaMarkup(widget.paragraph)) {
      return _buildIllustrationWidget();
    }

    return _buildTextWidget();
  }

  Widget _buildIllustrationWidget() {
    final markup = MediaMarkupParser.parseMediaMarkup(widget.paragraph).first;

    if (!markup.isIllustration) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIllustrationTitle(),
          _buildIllustrationContent(markup),
          if (widget.isEditMode) _buildIllustrationMarkup(markup),
        ],
      ),
    );
  }

  Widget _buildIllustrationTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Text(
        '插图 ${widget.index + 1}',
        style: TextStyle(
          fontSize: widget.fontSize * 0.8,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildIllustrationContent(dynamic markup) {
    return SceneImagePreview(
      taskId: markup.id,
      onImageTap: widget.onImageTap,
      onDelete: widget.onImageDelete != null
          ? (taskId) => widget.onImageDelete!(taskId)
          : null,
      onImageDeleted: () {
        debugPrint('单张图片删除成功: ${markup.id}');
      },
      modelWidth: widget.modelWidth,
      modelHeight: widget.modelHeight,
    );
  }

  Widget _buildIllustrationMarkup(dynamic markup) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            MediaMarkupParser.createIllustrationMarkup(markup.id),
            style: TextStyle(
              fontSize: widget.fontSize * 0.9,
              fontFamily: 'monospace',
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextWidget() {
    // 编辑模式使用TextField，阅读模式使用Text
    if (widget.isEditMode) {
      return _buildEditableText();
    }

    return _buildReadableText();
  }

  Widget _buildEditableText() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _controller,
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
              color:
                  widget.isSelected ? Colors.blue.withValues(alpha: 0.2) : null,
              border: widget.isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : widget.isCloseupMode
                      ? Border.all(
                          color: Colors.blue.withValues(alpha: 0.3), width: 1)
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.paragraph.trim(),
              style: TextStyle(
                fontSize: widget.fontSize,
                height: 1.8,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
