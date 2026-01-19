import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // 移除此行
// import '../providers/reader_edit_mode_provider.dart'; // 移除此行
// import '../services/database_service.dart'; // 移除此行
import '../utils/media_markup_parser.dart';
import 'scene_image_preview.dart';

class ParagraphWidget extends StatefulWidget {
  final String paragraph;
  final int index;
  final double fontSize;
  final bool isCloseupMode;
  final bool isEditMode; // 新增
  final bool isSelected;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onLongPress;
  final ValueChanged<String>? onContentChanged;
  final Function(String taskId, String imageUrl, int imageIndex)? onImageTap;
  final Function(String taskId)? onImageDelete;
  final Function(String taskId)?
      generateVideoFromIllustration; // For generating video from image preview
  final int? modelWidth; // 新增：模型宽度
  final int? modelHeight; // 新增：模型高度

  const ParagraphWidget({
    super.key,
    required this.paragraph,
    required this.index,
    required this.fontSize,
    required this.isCloseupMode,
    required this.isEditMode, // 新增
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
    // final editModeProvider = Provider.of<ReaderEditModeProvider>(context, listen: false); // 移除此行
    // final bool isEditMode = editModeProvider.isEditMode; // 移除此行

    // 检查是否为插图标记
    if (MediaMarkupParser.isMediaMarkup(widget.paragraph)) {
      final markup = MediaMarkupParser.parseMediaMarkup(widget.paragraph).first;

      // 只处理插图类型
      if (markup.isIllustration) {
        // 插图段落
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 插图标题
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  '插图 ${widget.index + 1}', // index + 1 is paragraph number
                  style: TextStyle(
                    fontSize: widget.fontSize * 0.8,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // 插图内容
              SceneImagePreview(
                taskId: markup.id,
                onImageTap: widget.onImageTap,
                onDelete: widget.onImageDelete != null
                    ? (taskId) => widget.onImageDelete!(taskId)
                    : null,
                onImageDeleted: () {
                  // 单张图片删除成功后的处理，可能需要刷新列表
                  debugPrint('单张图片删除成功: ${markup.id}');
                },
                modelWidth: widget.modelWidth,
                modelHeight: widget.modelHeight,
              ),

              // 编辑模式下显示可编辑的标记文本
              if (widget.isEditMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
            ],
          ),
        );
      } else {
        // 其他媒体类型暂不处理，显示占位符
        return Container(
          padding: const EdgeInsets.all(16.0),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            border: Border.all(color: Colors.orange, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📎 ${markup.type}',
                style: TextStyle(
                  fontSize: widget.fontSize * 0.9,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${markup.id}',
                style: TextStyle(
                  fontSize: widget.fontSize * 0.8,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '暂不支持此媒体类型的显示',
                style: TextStyle(
                  fontSize: widget.fontSize * 0.9,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        );
      }
    }

    // 普通文本段落
    // 编辑模式使用TextField，阅读模式使用Text
    if (widget.isEditMode) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          border:
              Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _controller, // 使用 State 中的 controller
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
          // onChanged 已移除，改用 initState 中的 Listener
        ),
      );
    }

    // 阅读模式的文本段落
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 段落内容
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
