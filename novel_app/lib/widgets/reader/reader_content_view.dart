import 'dart:async';
import 'package:flutter/material.dart';
import '../paragraph_widget.dart';

/// ReaderContentView - 阅读器内容视图
///
/// 职责：
/// - 显示章节内容列表
/// - 处理段落选择和交互
/// - 支持触摸事件处理自动滚动
/// - 处理滚动通知
/// - 支持全文连续编辑模式
///
/// 依赖：
/// - ParagraphWidget (段落组件)
/// - AutoScrollMixin (自动滚动功能)
class ReaderContentView extends StatefulWidget {
  final List<String> paragraphs;
  final List<int> selectedParagraphIndices;
  final double fontSize;
  final bool isCloseupMode;
  final bool isEditMode;
  final bool isAutoScrolling;
  final ValueChanged<int> onParagraphTap;
  final ValueChanged<int> onParagraphLongPress;
  /// 内容变化回调
  /// - [index] 段落索引（-1 表示全文编辑，>=0 表示段落编辑）
  /// - [newContent] 新的内容
  final Function(int index, String newContent) onContentChanged;
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
  State<ReaderContentView> createState() => _ReaderContentViewState();
}

class _ReaderContentViewState extends State<ReaderContentView> {
  late TextEditingController _fullTextController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // 使用全文内容初始化（段落之间用两个换行符分隔）
    _fullTextController = TextEditingController(
      text: widget.paragraphs.join('\n\n'),
    );
  }

  /// 检查两个字符串列表是否内容相等
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(ReaderContentView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 从编辑模式切换到阅读模式时，确保最新内容已同步
    if (oldWidget.isEditMode && !widget.isEditMode) {
      // 退出编辑模式，确保最新内容已传递给父组件
      widget.onContentChanged(-1, _fullTextController.text);
    }

    // 当段落内容发生变化时（非编辑模式下），更新 controller
    // 使用深度比较避免因列表实例不同导致的不必要更新
    if (!widget.isEditMode &&
        (oldWidget.paragraphs.length != widget.paragraphs.length ||
         !_listEquals(oldWidget.paragraphs, widget.paragraphs))) {
      _fullTextController.text = widget.paragraphs.join('\n\n');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fullTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 编辑模式：显示全文编辑器
    if (widget.isEditMode) {
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.onPointerDown(),
        onPointerUp: (_) => widget.onPointerUp(),
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16.0),
          child: _buildFullTextEditor(),
        ),
      );
    }

    // 阅读模式：显示段落列表
    return _buildReadingMode(context);
  }

  /// 构建全文编辑器（编辑模式）
  Widget _buildFullTextEditor() {
    return TextField(
      controller: _fullTextController,
      maxLines: null,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        hintText: '开始编辑章节内容...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.all(16.0),
      ),
      style: TextStyle(
        fontSize: widget.fontSize,
        height: 1.8,
        letterSpacing: 0.5,
      ),
      onChanged: (value) {
        // 防抖：延迟 300ms 后再更新，避免频繁 setState 导致性能问题
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          // 将全文内容传递给父组件（index=-1 表示全文编辑）
          widget.onContentChanged(-1, value);
        });
      },
    );
  }

  /// 构建阅读模式（段落列表）
  Widget _buildReadingMode(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => widget.onPointerDown(),
      onPointerUp: (_) => widget.onPointerUp(),
      child: NotificationListener<ScrollNotification>(
        onNotification: widget.onScrollNotification,
        child: ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16.0),
          itemCount: widget.paragraphs.length + 1, // +1 为了添加底部空白
          itemBuilder: (context, index) {
            // 最后一个位置添加空白
            if (index == widget.paragraphs.length) {
              return SizedBox(
                height: 160, // 底部留白高度，避免被按钮遮挡
                child: Container(),
              );
            }

            final paragraph = widget.paragraphs[index];
            final isSelected = widget.selectedParagraphIndices.contains(index);

            return ParagraphWidget(
              paragraph: paragraph,
              index: index,
              fontSize: widget.fontSize,
              isCloseupMode: widget.isCloseupMode,
              isEditMode: widget.isEditMode,
              isSelected: isSelected,
              onTap: (idx) => widget.onParagraphTap(idx),
              onLongPress: (idx) => widget.onParagraphLongPress(idx),
              onContentChanged: (newContent) =>
                  widget.onContentChanged(index, newContent), // 传递 index
              onImageTap: (taskId, imageUrl, imageIndex) =>
                  widget.onImageTap(taskId, imageUrl, imageIndex),
              onImageDelete: (taskId) => widget.onImageDelete(taskId),
              generateVideoFromIllustration: widget.generateVideoFromIllustration,
              modelWidth: widget.modelWidth,
              modelHeight: widget.modelHeight,
            );
          },
        ),
      ),
    );
  }
}
