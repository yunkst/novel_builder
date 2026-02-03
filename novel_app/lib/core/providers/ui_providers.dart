/// Riverpod UI Providers
///
/// 此文件提供UI状态管理相关的 Providers。
///
/// **功能域**:
/// - [ToastNotifier] - Toast消息状态管理
/// - [DialogServiceProvider] - 对话框服务Provider
///
/// **架构原则**:
/// - UI层只触发事件（调用Notifier方法）
/// - Notifier处理业务逻辑和更新状态
/// - UI通过ref.listen监听状态变化并显示Toast
///
/// **使用示例**:
/// ```dart
/// // 在Widget中监听Toast
/// ref.listen(toastNotifier, (previous, next) {
///   if (next.message != null && mounted) {
///     ToastUtils.showSuccess(next.message!, context: context);
///     ref.read(toastNotifier.notifier).clear();
///   }
/// });
///
/// // 在业务逻辑中触发Toast
/// ref.read(toastNotifier.notifier).showSuccess('操作成功');
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ui_service.dart';

// ==================== UI Service Providers ====================

/// 对话框服务Provider
///
/// 提供全局单例的对话框服务
@riverpod
DialogService dialogService(Ref ref) {
  return DialogService();
}

// ==================== Toast State Management ====================

/// Toast类型枚举
enum ToastType {
  /// 成功提示（绿色）
  success,

  /// 错误提示（红色）
  error,

  /// 警告提示（橙色）
  warning,

  /// 信息提示（蓝色）
  info,
}

/// Toast状态数据类
///
/// 封装Toast消息和类型，便于UI层根据类型选择显示样式
class ToastState {
  /// 消息内容
  final String? message;

  /// Toast类型
  final ToastType? type;

  /// 持续时间（可选）
  final Duration? duration;

  const ToastState({
    this.message,
    this.type,
    this.duration,
  });

  /// 创建空状态
  const ToastState.empty()
      : message = null,
        type = null,
        duration = null;

  /// 判断是否有消息
  bool get hasMessage => message != null && message!.isNotEmpty;
}

/// Toast状态管理器
///
/// **职责**:
/// - 管理Toast消息状态
/// - 提供显示各类Toast的接口
/// - 自动触发状态更新通知UI层
///
/// **架构原则**:
/// - Notifier只管理状态，不直接显示Toast
/// - UI层通过ref.listen监听状态变化并显示
/// - 显示后立即清除状态，避免重复显示
@riverpod
class ToastNotifier extends _$ToastNotifier {
  @override
  ToastState build() {
    return const ToastState.empty();
  }

  /// 显示成功提示（绿色）
  ///
  /// [message] 消息内容
  /// [duration] 持续时间（可选，默认使用ToastUtils默认值）
  void showSuccess(String message, {Duration? duration}) {
    state = ToastState(
      message: message,
      type: ToastType.success,
      duration: duration,
    );
  }

  /// 显示错误提示（红色）
  ///
  /// [message] 消息内容
  /// [duration] 持续时间（可选）
  void showError(String message, {Duration? duration}) {
    state = ToastState(
      message: message,
      type: ToastType.error,
      duration: duration,
    );
  }

  /// 显示警告提示（橙色）
  ///
  /// [message] 消息内容
  /// [duration] 持续时间（可选）
  void showWarning(String message, {Duration? duration}) {
    state = ToastState(
      message: message,
      type: ToastType.warning,
      duration: duration,
    );
  }

  /// 显示信息提示（蓝色）
  ///
  /// [message] 消息内容
  /// [duration] 持续时间（可选）
  void showInfo(String message, {Duration? duration}) {
    state = ToastState(
      message: message,
      type: ToastType.info,
      duration: duration,
    );
  }

  /// 清除Toast消息
  ///
  /// 通常在UI层显示Toast后调用，避免重复显示
  void clear() {
    state = const ToastState.empty();
  }
}

// ==================== Dialog State Management ====================

/// 对话框状态数据类
///
/// 封装各类对话框的状态数据
class DialogState {
  /// 是否显示加载对话框
  final bool isLoading;

  /// 加载对话框消息
  final String? loadingMessage;

  /// 是否显示AI伴读确认对话框
  final bool isAICompanionConfirm;

  /// AI伴读响应数据（当isAICompanionConfirm=true时有效）
  final dynamic aiCompanionResponse;

  const DialogState({
    this.isLoading = false,
    this.loadingMessage,
    this.isAICompanionConfirm = false,
    this.aiCompanionResponse,
  });

  /// 创建初始状态
  const DialogState.initial()
      : isLoading = false,
        loadingMessage = null,
        isAICompanionConfirm = false,
        aiCompanionResponse = null;

  /// 复制并更新部分字段
  DialogState copyWith({
    bool? isLoading,
    String? loadingMessage,
    bool? isAICompanionConfirm,
    dynamic aiCompanionResponse,
  }) {
    return DialogState(
      isLoading: isLoading ?? this.isLoading,
      loadingMessage: loadingMessage ?? this.loadingMessage,
      isAICompanionConfirm: isAICompanionConfirm ?? this.isAICompanionConfirm,
      aiCompanionResponse: aiCompanionResponse ?? this.aiCompanionResponse,
    );
  }
}

/// 对话框状态管理器
///
/// **职责**:
/// - 管理对话框显示状态
/// - 提供显示各类对话框的接口
/// - UI层通过ref.listen监听状态变化并显示对话框
///
/// **架构原则**:
/// - Notifier只管理状态，不直接显示对话框
/// - UI层通过ref.listen监听状态变化并显示
/// - 用户操作后通过Notifier方法更新状态
@riverpod
class DialogNotifier extends _$DialogNotifier {
  @override
  DialogState build() {
    return const DialogState.initial();
  }

  /// 显示加载对话框
  ///
  /// [message] 加载提示消息
  void showLoading(String message) {
    state = state.copyWith(
      isLoading: true,
      loadingMessage: message,
    );
  }

  /// 隐藏加载对话框
  void hideLoading() {
    state = state.copyWith(
      isLoading: false,
      loadingMessage: null,
    );
  }

  /// 显示AI伴读确认对话框
  ///
  /// [response] AI伴读响应数据
  void showAICompanionConfirm(dynamic response) {
    state = state.copyWith(
      isAICompanionConfirm: true,
      aiCompanionResponse: response,
    );
  }

  /// 隐藏AI伴读确认对话框
  void hideAICompanionConfirm() {
    state = state.copyWith(
      isAICompanionConfirm: false,
      aiCompanionResponse: null,
    );
  }

  /// 清除所有对话框状态
  void clear() {
    state = const DialogState.initial();
  }
}
