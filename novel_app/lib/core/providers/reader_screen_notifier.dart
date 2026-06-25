/// ReaderScreen Notifier
///
/// 负责管理阅读器屏幕的业务逻辑和状态
/// 包括对话框管理、章节导航等功能
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reader_screen_notifier.g.dart';

/// ReaderScreen 状态
///
/// 管理阅读器屏幕的各种状态变化
class ReaderScreenState {
  /// 对话框显示状态
  final bool showEditDialog;
  final bool showIllustrationDialog;

  /// 加载状态
  final bool isLoading;

  /// 错误信息
  final String errorMessage;

  /// 默认构造函数
  const ReaderScreenState({
    this.showEditDialog = false,
    this.showIllustrationDialog = false,
    this.isLoading = false,
    this.errorMessage = '',
  });

  /// 复制并修改部分字段
  ReaderScreenState copyWith({
    bool? showEditDialog,
    bool? showIllustrationDialog,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ReaderScreenState(
      showEditDialog: showEditDialog ?? this.showEditDialog,
      showIllustrationDialog:
          showIllustrationDialog ?? this.showIllustrationDialog,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ReaderScreenNotifier
///
/// 管理阅读器屏幕的业务逻辑，包括：
/// - 对话框状态管理
/// - 章节内容刷新
@riverpod
class ReaderScreenNotifier extends _$ReaderScreenNotifier {
  @override
  ReaderScreenState build() {
    return const ReaderScreenState();
  }

  // ========== 对话框管理方法 ==========

  /// 显示编辑对话框
  void showEditDialog() {
    state = state.copyWith(showEditDialog: true);
  }

  /// 隐藏编辑对话框
  void hideEditDialog() {
    state = state.copyWith(showEditDialog: false);
  }

  /// 显示插图对话框
  void showIllustrationDialog() {
    state = state.copyWith(showIllustrationDialog: true);
  }

  /// 隐藏插图对话框
  void hideIllustrationDialog() {
    state = state.copyWith(showIllustrationDialog: false);
  }

  // ========== 加载状态管理 ==========

  /// 设置加载状态
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// 设置错误信息
  void setError(String errorMessage) {
    state = state.copyWith(errorMessage: errorMessage);
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
