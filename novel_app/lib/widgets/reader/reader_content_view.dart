import 'package:flutter/material.dart';
import '../paragraph_widget.dart';

/// ReaderContentView - 阅读器内容视图
///
/// 职责：
/// - 显示章节内容列表
/// - 处理段落选择和交互
/// - 支持触摸事件处理自动滚动
/// - 处理滚动通知
///
/// 依赖：
/// - ParagraphWidget (段落组件)
/// - AutoScrollMixin (自动滚动功能)
class ReaderContentView extends StatelessWidget {
  final List<String> paragraphs;
  final List<int> selectedParagraphIndices;
  final double fontSize;
  final bool isCloseupMode;
  final bool isEditMode;
  final bool isAutoScrolling;
  final ValueChanged<int> onParagraphTap;
  final ValueChanged<int> onParagraphLongPress;
  final Function(int, String) onContentChanged; // 修改：添加 index 参数
  final Function(String, String, int) onImageTap;
  final Function(String) onImageDelete;
  final Function(String) generateVideoFromIllustration;
  final int? modelWidth;
  final int? modelHeight;
  final ScrollController scrollController;
  final Function() onPointerDown;
  final Function() onPointerUp;
  final bool Function(ScrollNotification) onScrollNotification;

  const ReaderContentView({
    super.key,
    required this.paragraphs,
    required this.selectedParagraphIndices,
    required this.fontSize,
    required this.isCloseupMode,
    required this.isEditMode,
    required this.isAutoScrolling,
    required this.onParagraphTap,
    required this.onParagraphLongPress,
    required this.onContentChanged,
    required this.onImageTap,
    required this.onImageDelete,
    required this.generateVideoFromIllustration,
    required this.modelWidth,
    required this.modelHeight,
    required this.scrollController,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onScrollNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => onPointerDown(),
      onPointerUp: (_) => onPointerUp(),
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount: paragraphs.length + 1, // +1 为了添加底部空白
          itemBuilder: (context, index) {
            // 最后一个位置添加空白
            if (index == paragraphs.length) {
              return SizedBox(
                height: 160, // 底部留白高度，避免被按钮遮挡
                child: Container(),
              );
            }

            final paragraph = paragraphs[index];
            final isSelected = selectedParagraphIndices.contains(index);

            return ParagraphWidget(
              paragraph: paragraph,
              index: index,
              fontSize: fontSize,
              isCloseupMode: isCloseupMode,
              isEditMode: isEditMode,
              isSelected: isSelected,
              onTap: (idx) => onParagraphTap(idx),
              onLongPress: (idx) => onParagraphLongPress(idx),
              onContentChanged: (newContent) =>
                  onContentChanged(index, newContent), // 传递 index
              onImageTap: (taskId, imageUrl, imageIndex) =>
                  onImageTap(taskId, imageUrl, imageIndex),
              onImageDelete: (taskId) => onImageDelete(taskId),
              generateVideoFromIllustration: generateVideoFromIllustration,
              modelWidth: modelWidth,
              modelHeight: modelHeight,
            );
          },
        ),
      ),
    );
  }
}
