import 'package:flutter/material.dart';

/// 加载状态管理 Mixin
///
/// 为 State 提供统一的加载状态管理，简化异步操作的 UI 状态处理。
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> with LoadingStateMixin {
///   Future<void> _loadData() async {
///     await withLoading(() async {
///       // 执行异步操作
///       final data = await fetchData();
///       setState(() => _data = data);
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: buildLoadingBody(
///         child: _data != null ? ContentWidget(data: _data) : null,
///       ),
///     );
///   }
/// }
/// ```
///
/// 功能特性：
/// - 自动管理加载状态和错误状态
/// - 统一的错误处理机制
/// - 简化的构建方法
/// - 可自定义加载和错误 UI
mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  /// 是否正在加载
  bool _isLoading = false;

  /// 错误消息
  String? _errorMessage;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 是否有错误
  bool get hasError => _errorMessage != null;

  /// 错误消息
  String? get errorMessage => _errorMessage;

  /// 在加载状态下执行异步操作
  ///
  /// 自动管理加载状态和错误状态。操作开始时设置加载状态，
  /// 操作完成后清除加载状态，发生异常时记录错误消息。
  ///
  /// [action] 要执行的异步操作
  /// [showError] 是否在错误时显示 Toast 提示（默认 true）
  /// [errorPrefix] 错误消息前缀（默认 "操作失败"）
  Future<void> withLoading(
    Future<void> Function() action, {
    bool showError = true,
    String errorPrefix = '操作失败',
  }) async {
    if (_isLoading) {
      debugPrint('⚠️ [LoadingStateMixin] 已有加载操作在进行中');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await action();
    } catch (e, stackTrace) {
      final errorMsg = '$errorPrefix: $e';
      setState(() {
        _errorMessage = errorMsg;
      });
      debugPrint('❌ [LoadingStateMixin] $errorMsg\n$stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 在加载状态下执行异步操作并返回结果
  ///
  /// 自动管理加载状态和错误状态。操作开始时设置加载状态，
  /// 操作完成后清除加载状态并返回结果，发生异常时记录错误消息。
  ///
  /// [R] 返回值类型
  /// [action] 要执行的异步操作
  /// [showError] 是否在错误时显示 Toast 提示（默认 true）
  /// [errorPrefix] 错误消息前缀（默认 "操作失败"）
  ///
  /// 返回操作结果，发生异常时返回 null
  Future<R?> withLoadingForResult<R>({
    required Future<R?> Function() action,
    bool showError = true,
    String errorPrefix = '操作失败',
  }) async {
    if (_isLoading) {
      debugPrint('⚠️ [LoadingStateMixin] 已有加载操作在进行中');
      return null;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      return await action();
    } catch (e, stackTrace) {
      final errorMsg = '$errorPrefix: $e';
      setState(() {
        _errorMessage = errorMsg;
      });
      debugPrint('❌ [LoadingStateMixin] $errorMsg\n$stackTrace');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 清除错误状态
  void clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  /// 构建加载状态下的 UI
  ///
  /// [child] 非加载状态下的内容组件
  /// [loadingWidget] 自定义加载指示器（默认为 CircularProgressIndicator）
  /// [errorWidget] 自定义错误显示组件
  /// [showErrorInUI] 是否在 UI 中显示错误（默认 true）
  ///
  /// 返回根据状态构建的 Widget
  Widget buildLoadingBody({
    Widget? child,
    Widget? loadingWidget,
    Widget? errorWidget,
    bool showErrorInUI = true,
  }) {
    if (_isLoading) {
      return loadingWidget ??
          const Center(
            child: CircularProgressIndicator(),
          );
    }

    if (_errorMessage != null && showErrorInUI) {
      return errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: clearError,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
    }

    return child ?? const SizedBox.shrink();
  }

  /// 构建带错误遮罩的 UI
  ///
  /// 在正常内容上方显示错误提示（如有），不影响用户操作。
  ///
  /// [child] 正常内容组件
  /// [errorBanner] 自定义错误横幅组件
  Widget buildWithErrorOverlay({
    required Widget child,
    Widget? errorBanner,
  }) {
    if (_errorMessage == null) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: errorBanner ??
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.withValues(alpha: 0.9),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: clearError,
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }
}
