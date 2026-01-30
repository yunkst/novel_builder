import 'package:flutter/material.dart';
import '../services/dify_service.dart';
import '../services/logger_service.dart';
import '../utils/toast_utils.dart';

/// Dify流式交互的Mixin
///
/// 使用方式：`class _MyScreenState extends State<MyScreen> with DifyStreamingMixin`
///
/// 提供统一的流式调用接口，消除UI层90%的重复代码。
///
/// 功能特性：
/// - 统一的状态管理（isStreaming, isCancelled, fullContent）
/// - 统一的流式调用方法（callDifyStreaming）
/// - 统一的取消功能（cancelStreaming）
/// - 自动生命周期管理（dispose时自动清理）
/// - 统一的错误处理和SnackBar提示
///
/// 使用示例：
/// ```dart
/// class _MyScreenState extends State<MyScreen> with DifyStreamingMixin {
///   Future<void> _generateContent() async {
///     await callDifyStreaming(
///       inputs: {'cmd': '生成', 'user_input': '...'},
///       onChunk: (chunk) {
///         _outputController.text += chunk;
///       },
///       startMessage: 'AI正在生成...',
///       completeMessage: '生成完成',
///     );
///   }
/// }
/// ```
mixin DifyStreamingMixin<T extends StatefulWidget> on State<T> {
  // ========== 状态管理 ==========

  bool _isStreaming = false;
  bool _isCancelled = false;
  String _fullContent = '';

  // 调试统计（可选）
  DateTime? _startTime;
  int _charCount = 0;

  /// 是否正在流式输出
  bool get isStreaming => _isStreaming;

  /// 是否已取消
  bool get isCancelled => _isCancelled;

  /// 流式输出的完整内容
  String get fullContent => _fullContent;

  // ========== 公开方法 ==========

  /// 调用Dify流式API（统一入口）
  ///
  /// [inputs] Dify工作流输入参数
  /// [onChunk] 文本块回调，每次接收到新文本时调用
  /// [onComplete] 完成回调，流式输出结束时调用（传递完整内容）
  /// [onError] 错误回调，发生错误时调用
  /// [timeout] 超时时间（默认5分钟）
  /// [showErrorSnackBar] 是否显示错误提示SnackBar（默认true）
  /// [startMessage] 开始时的提示信息（可选）
  /// [completeMessage] 完成时的提示信息（可选）
  /// [errorMessagePrefix] 错误消息前缀（默认"操作失败"）
  /// [enableDebugLog] 是否启用详细调试日志（默认false）
  Future<void> callDifyStreaming({
    required Map<String, dynamic> inputs,
    required void Function(String chunk) onChunk,
    void Function(String fullContent)? onComplete,
    void Function(String error)? onError,
    Duration timeout = const Duration(seconds: 15),
    bool showErrorSnackBar = true,
    String? startMessage,
    String? completeMessage,
    String? errorMessagePrefix,
    bool enableDebugLog = false,
  }) async {
    if (_isStreaming) {
      LoggerService.instance.w(
        '已有流式请求在进行中',
        category: LogCategory.ai,
        tags: ['dify', 'streaming', 'duplicate'],
      );
      return;
    }

    // 初始化状态
    setState(() {
      _isStreaming = true;
      _isCancelled = false;
      _fullContent = '';
    });

    // 初始化调试统计
    if (enableDebugLog) {
      _startTime = DateTime.now();
      _charCount = 0;
      debugPrint('🚀 [DifyStreamingMixin] 开始流式交互');
      debugPrint('命令: ${inputs['cmd']}');
      debugPrint('输入参数: ${inputs.keys.join(', ')}');
    }

    if (startMessage != null && mounted) {
      showStreamingProgress(message: startMessage);
    }

    try {
      final difyService = DifyService();

      // 调用DifyService的流式方法
      await difyService.runWorkflowStreaming(
        inputs: inputs,
        enableDebugLog: enableDebugLog, // 传递给 Service 层
        onData: (chunk) {
          if (!mounted || _isCancelled) return;

          // 处理特殊标记（确保最后一部分内容不丢失）
          const completeContentMarker = '<<COMPLETE_CONTENT>>';
          String processedChunk;

          if (chunk.startsWith(completeContentMarker)) {
            // 一次性设置完整内容
            processedChunk = chunk.substring(completeContentMarker.length);
            setState(() {
              _fullContent = processedChunk;
            });
          } else {
            // 正常累积内容
            processedChunk = chunk;
            setState(() {
              _fullContent += chunk;
            });
          }

          // 调试统计
          if (enableDebugLog) {
            _charCount += processedChunk.length;
            debugPrint(
                '📝 [DifyStreamingMixin] 收到数据块: ${processedChunk.length}字符 (累计: $_charCount字符)');
          }

          // 回调UI层（传递处理后的内容）
          onChunk(processedChunk);
        },
        onDone: () {
          if (!mounted || _isCancelled) return;

          setState(() {
            _isStreaming = false;
          });

          hideStreamingProgress();

          // 调试统计
          if (enableDebugLog && _startTime != null) {
            final duration = DateTime.now().difference(_startTime!);
            debugPrint('✅ [DifyStreamingMixin] 流式交互完成');
            debugPrint('总字符数: $_charCount');
            debugPrint(
                '耗时: ${duration.inMilliseconds}ms (${duration.inSeconds}s)');
          }

          if (completeMessage != null && showErrorSnackBar && mounted) {
            ToastUtils.showSuccess(completeMessage);
          }

          onComplete?.call(_fullContent);
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            _isStreaming = false;
          });

          hideStreamingProgress();

          // 调试统计
          if (enableDebugLog && _startTime != null) {
            final duration = DateTime.now().difference(_startTime!);
            debugPrint('❌ [DifyStreamingMixin] 流式交互失败');
            debugPrint('已接收字符数: $_charCount');
            debugPrint('失败前耗时: ${duration.inMilliseconds}ms');
          }

          final errorMsg = '${errorMessagePrefix ?? "操作失败"}: $error';
          if (showErrorSnackBar) {
            ToastUtils.showError(errorMsg);
          }

          onError?.call(errorMsg);
        },
      );
    } catch (e, stackTrace) {
      if (!mounted) return;

      LoggerService.instance.e(
        '流式交互异常: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dify', 'streaming', 'error'],
      );

      setState(() {
        _isStreaming = false;
      });

      hideStreamingProgress();

      // 调试统计
      if (enableDebugLog && _startTime != null) {
        debugPrint('❌ [DifyStreamingMixin] 流式交互异常: $e');
      }

      final errorMsg = '${errorMessagePrefix ?? "操作异常"}: $e';
      if (showErrorSnackBar) {
        ToastUtils.showError(errorMsg);
      }

      onError?.call(errorMsg);
    }
  }

  /// 取消流式输出
  ///
  /// [reason] 可选的取消原因
  void cancelStreaming({String? reason}) {
    if (!_isStreaming) {
      return;
    }

    setState(() {
      _isCancelled = true;
      _isStreaming = false;
    });

    hideStreamingProgress();

    if (reason != null && mounted) {
      ToastUtils.show('已取消: $reason');
    } else if (mounted) {
      ToastUtils.show('已取消生成，内容已保留');
    }

    LoggerService.instance.d(
      '流式输出已取消${reason != null ? ": $reason" : ""}',
      category: LogCategory.ai,
      tags: ['dify', 'streaming', 'cancel'],
    );
  }

  // ========== 辅助方法（可被子类重写） ==========

  /// 显示流式输出进度（可选实现）
  ///
  /// 子类可以重写此方法来自定义进度显示
  void showStreamingProgress({String? message}) {
    // 默认空实现，子类可重写
  }

  /// 隐藏流式输出进度（可选实现）
  ///
  /// 子类可以重写此方法来自定义进度隐藏
  void hideStreamingProgress() {
    // 默认空实现，子类可重写
  }

  // ========== 生命周期管理 ==========

  @override
  @mustCallSuper
  void dispose() {
    // 清理状态
    _isStreaming = false;
    _isCancelled = false;
    _fullContent = '';
    super.dispose();
  }

  // ========== 内部辅助方法 ==========
}
