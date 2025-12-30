import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // 移除此行
// import '../providers/reader_edit_mode_provider.dart'; // 移除此行
// import '../services/database_service.dart'; // 移除此行
import '../utils/media_markup_parser.dart';
import 'scene_image_preview.dart';

class ParagraphWidget extends StatelessWidget {
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
  final VoidCallback? onImageDelete;
  final Function(String taskId)? generateVideoFromIllustration; // For generating video from image preview

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
  });

  @override
  Widget build(BuildContext context) {
    // final editModeProvider = Provider.of<ReaderEditModeProvider>(context, listen: false); // 移除此行
    // final bool isEditMode = editModeProvider.isEditMode; // 移除此行
    
    // 检查是否为插图标记
    if (MediaMarkupParser.isMediaMarkup(paragraph)) {
      final markup = MediaMarkupParser.parseMediaMarkup(paragraph).first;

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
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  '插图 ${index + 1}', // index + 1 is paragraph number
                  style: TextStyle(
                    fontSize: fontSize * 0.8,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // 插图内容
              SceneImagePreview(
                taskId: markup.id,
                onImageTap: onImageTap,
                onDelete: onImageDelete,
                onImageDeleted: () {
                  // 单张图片删除成功后的处理，可能需要刷新列表
                  debugPrint('单张图片删除成功: ${markup.id}');
                },
              ),

              // 编辑模式下显示可编辑的标记文本
              if (isEditMode) ...[
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
                      fontSize: fontSize * 0.9,
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
                  fontSize: fontSize * 0.9,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${markup.id}',
                style: TextStyle(
                  fontSize: fontSize * 0.8,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '暂不支持此媒体类型的显示',
                style: TextStyle(
                  fontSize: fontSize * 0.9,
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
    if (isEditMode) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          border: Border.all(
              color: Colors.grey.withValues(alpha: 0.3),
              width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: TextEditingController(text: paragraph),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(
            fontSize: fontSize,
            height: 1.8,
            letterSpacing: 0.5,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          maxLines: null,
          onChanged: onContentChanged, // 使用回调函数
        ),
      );
    }

    // 阅读模式的文本段落
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 段落内容
        InkWell(
          onTap: isCloseupMode && onTap != null
              ? () => onTap!(index)
              : null,
          onLongPress: onLongPress != null
              ? () => onLongPress!(index)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withValues(alpha: 0.2)
                  : null,
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : isCloseupMode
                      ? Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1)
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              paragraph.trim(),
              style: TextStyle(
                fontSize: fontSize,
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
