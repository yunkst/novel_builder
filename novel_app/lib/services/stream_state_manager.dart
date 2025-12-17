import 'dart:async';
import 'package:flutter/foundation.dart';

/// 流式交互状态
enum StreamStatus {
  idle,       // 空闲
  connecting, // 连接中
  streaming,  // 流式传输中
  completed,  // 完成
  error,      // 错误
}

/// 流式状态数据
class StreamState {
  final StreamStatus status;
  final String content;
  final String? error;
  final DateTime? startTime;
  final DateTime? endTime;
  final int characterCount;

  StreamState({
    required this.status,
    this.content = '',
    this.error,
    this.startTime,
    this.endTime,
    this.characterCount = 0,
  });

  StreamState copyWith({
    StreamStatus? status,
    String? content,
    String? error,
    DateTime? startTime,
    DateTime? endTime,
    int? characterCount,
  }) {
    return StreamState(
      status: status ?? this.status,
      content: content ?? this.content,
      error: error ?? this.error,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      characterCount: characterCount ?? this.characterCount,
    );
  }

  @override
  String toString() {
    String durationStr = '';
    if (startTime != null && endTime != null) {
      durationStr = 'duration: ${endTime!.difference(startTime!).inSeconds}s';
    }
    return 'StreamState(status: $status, content: "${content.length} chars", error: $error, $durationStr)';
  }
}

/// 流式状态管理器 - 统一管理所有流式交互的状态
class StreamStateManager {
  final ValueNotifier<StreamState> _stateNotifier;
  final void Function(String) _onTextChunk;
  final void Function(String) _onCompleted; // 修改：传递完整内容
  final void Function(String) _onError;

  StreamStateManager({
    required void Function(String) onTextChunk,
    required void Function(String) onCompleted, // 修改：传递完整内容
    required void Function(String) onError,
  }) : _stateNotifier = ValueNotifier(StreamState(status: StreamStatus.idle)),
       _onTextChunk = onTextChunk,
       _onCompleted = onCompleted, // 修改：传递完整内容
       _onError = onError;

  /// 获取当前状态
  StreamState get currentState => _stateNotifier.value;

  /// 获取状态监听器
  ValueNotifier<StreamState> get stateNotifier => _stateNotifier;

  /// 开始流式交互
  void startStreaming() {
    debugPrint('🚀 === 开始流式交互 ===');
    _updateState(StreamState(
      status: StreamStatus.connecting,
      startTime: DateTime.now(),
    ));
  }

  /// 开始接收数据
  void startReceiving() {
    debugPrint('📡 === 开始接收数据 ===');
    _updateState(currentState.copyWith(
      status: StreamStatus.streaming,
    ));
  }

  /// 处理文本块 - 改进异步处理确保内容完整性
  void handleTextChunk(String text) {
    debugPrint('📝 === StreamStateManager.handleTextChunk ===');
    debugPrint('收到文本: "$text"');
    debugPrint('当前长度: ${currentState.characterCount}');
    debugPrint('状态: ${currentState.status}');

    final newContent = currentState.content + text;
    final newCharacterCount = newContent.length;

    debugPrint('准备更新状态: $newCharacterCount 字符');

    // 使用 microtask 确保状态更新在下一个事件循环中执行
    _updateState(currentState.copyWith(
      status: StreamStatus.streaming,
      content: newContent,
      characterCount: newCharacterCount,
    ));

    debugPrint('状态更新完成');

    // 使用 microtask 确保回调在状态更新后执行
    scheduleMicrotask(() {
      debugPrint('调用 _onTextChunk 回调...');
      try {
        _onTextChunk(text);
        debugPrint('_onTextChunk 回调完成');
      } catch (e) {
        debugPrint('❌ _onTextChunk 回调错误: $e');
      }
    });

    debugPrint('✅ StreamStateManager 文本块处理完成');
    debugPrint('最终长度: $newCharacterCount');
    debugPrint('最终状态: ${currentState.status}');
    debugPrint('================================');
  }

  /// 完成流式交互 - 传递完整内容
  void complete() {
    debugPrint('✅ === 流式交互完成 ===');
    debugPrint('总字符数: ${currentState.characterCount}');
    final startTime = currentState.startTime;
    if (startTime != null) {
      debugPrint('耗时: ${DateTime.now().difference(startTime).inMilliseconds}ms');
    }

    final completeContent = currentState.content;
    debugPrint('完整内容长度: ${completeContent.length}');

    _updateState(currentState.copyWith(
      status: StreamStatus.completed,
      endTime: DateTime.now(),
    ));

    // 调用回调，传递完整内容
    debugPrint('调用 _onCompleted 回调，传递完整内容...');
    _onCompleted(completeContent);
    debugPrint('_onCompleted 回调完成');
  }

  /// 处理错误
  void handleError(String error) {
    debugPrint('❌ === 流式交互错误 ===');
    debugPrint('错误: $error');

    _updateState(currentState.copyWith(
      status: StreamStatus.error,
      error: error,
      endTime: DateTime.now(),
    ));

    // 调用回调
    _onError(error);
  }

  /// 重置状态
  void reset() {
    debugPrint('🔄 === 重置流式状态 ===');
    _updateState(StreamState(status: StreamStatus.idle));
  }

  /// 释放资源
  void dispose() {
    debugPrint('🗑️ === 释放流式状态管理器 ===');
    _stateNotifier.dispose();
  }

  /// 更新状态（内部方法）
  void _updateState(StreamState newState) {
    debugPrint('🔄 === 状态更新 ===');
    debugPrint('旧状态: $currentState');
    debugPrint('新状态: $newState');
    debugPrint('==================');

    _stateNotifier.value = newState;
  }

  /// 获取当前状态描述
  String get statusDescription {
    final state = currentState;
    switch (state.status) {
      case StreamStatus.idle:
        return '空闲';
      case StreamStatus.connecting:
        return '连接中...';
      case StreamStatus.streaming:
        return '生成中... (${state.characterCount}字符)';
      case StreamStatus.completed:
        return '完成 (${state.characterCount}字符)';
      case StreamStatus.error:
        return '错误: ${state.error ?? "未知错误"}';
    }
  }

  /// 是否正在生成
  bool get isGenerating => currentState.status == StreamStatus.streaming;

  /// 是否已完成
  bool get isCompleted => currentState.status == StreamStatus.completed;

  /// 是否有错误
  bool get hasError => currentState.status == StreamStatus.error;

  /// 获取耗时（毫秒）
  int? get durationMs {
    final startTime = currentState.startTime;
    if (startTime == null) return null;
    final endTime = currentState.endTime;
    if (endTime == null) return null;
    return endTime.difference(startTime).inMilliseconds;
  }
}