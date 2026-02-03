import 'package:flutter/foundation.dart';
import '../core/providers/reader_state_providers.dart';
import 'package:riverpod/riverpod.dart';

/// ReaderInteractionController (新版本)
///
/// 职责：
/// - 段落选择逻辑（单击、长按）
/// - 特写模式管理
/// - 选中文本提取
/// - 段落连续性检查
/// - 通过Riverpod Provider管理状态，不使用setState回调
///
/// 使用方式：
/// ```dart
/// final controller = ReaderInteractionController(ref: ref);
///
/// controller.handleParagraphTap(index, paragraphs);
/// controller.toggleCloseupMode();
/// ```
///
/// 状态变化通过Provider自动通知UI更新
class ReaderInteractionController {
  final Ref _ref;

  // ========== 构造函数 ==========

  ReaderInteractionController({required Ref ref}) : _ref = ref;

  // ========== 公开方法 ==========

  /// 处理段落点击
  ///
  /// [index] 段落索引
  /// [paragraphs] 所有段落列表
  /// [isMediaMarkup] 是否为媒体标记
  void handleParagraphTap(int index, List<String> paragraphs, {bool isMediaMarkup = false}) {
    _ref.read(interactionStateNotifierProvider.notifier).handleParagraphTap(
          index,
          paragraphs,
          isMediaMarkup: isMediaMarkup,
        );
  }

  /// 处理段落长按
  ///
  /// 长按显示操作菜单，这个方法只返回是否应该显示菜单
  /// 具体的菜单UI由 reader_screen.dart 处理
  bool shouldHandleLongPress(bool isCloseupMode) {
    if (isCloseupMode) {
      debugPrint('⚠️ ReaderInteractionController: 特写模式下不处理长按');
      return false; // 特写模式下不处理长按
    }
    return true;
  }

  /// 切换特写模式
  ///
  /// [clearSelection] 是否清除选择（默认true）
  void toggleCloseupMode({bool clearSelection = true}) {
    _ref.read(interactionStateNotifierProvider.notifier).toggleCloseupMode(
          clearSelection: clearSelection,
        );
  }

  /// 设置特写模式（直接设置，不切换）
  ///
  /// [value] 特写模式状态
  void setCloseupMode(bool value) {
    _ref.read(interactionStateNotifierProvider.notifier).setCloseupMode(value);
  }

  /// 清除段落选择
  void clearSelection() {
    _ref.read(interactionStateNotifierProvider.notifier).clearSelection();
  }

  /// 获取选中的文本
  ///
  /// [paragraphs] 所有段落列表
  /// 返回选中的文本内容，用双空行分隔
  String getSelectedText(List<String> paragraphs) {
    return _ref.read(interactionStateNotifierProvider.notifier).getSelectedText(paragraphs);
  }

  // ========== Getters ==========

  /// 是否在特写模式（从Provider获取）
  bool get isCloseupMode => _ref.read(interactionStateNotifierProvider).isCloseupMode;

  /// 选中的段落索引列表（从Provider获取）
  List<int> get selectedParagraphIndices =>
      _ref.read(interactionStateNotifierProvider).selectedParagraphIndices;

  /// 是否有选中段落（从Provider获取）
  bool get hasSelection => _ref.read(interactionStateNotifierProvider).hasSelection;

  /// 选中段落数量（从Provider获取）
  int get selectionCount => _ref.read(interactionStateNotifierProvider).selectionCount;
}
