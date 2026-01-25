import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/logging/logger_service.dart';
import '../core/logging/log_categories.dart';

/// 流式交互状态
enum StreamStatus {
  idle, // 空闲
  connecting, // 连接中
  streaming, // 流式传输中
  completed, // 完成
  error, // 错误
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
  })  : _stateNotifier = ValueNotifier(StreamState(status: StreamStatus.idle)),
        _onTextChunk = onTextChunk,
        _onCompleted = onCompleted, // 修改：传递完整内容
        _onError = onError;

  /// 获取当前状态
  StreamState get currentState => _stateNotifier.value;

  /// 获取状态监听器
  ValueNotifier<StreamState> get stateNotifier => _stateNotifier;

  /// 开始流式交互
  void startStreaming() {
    LoggerService.instance.i(
      '开始流式交互',
      category: LogCategory.stream,
      tags: ['start'],
    );
    _updateState(StreamState(
      status: StreamStatus.connecting,
      startTime: DateTime.now(),
    ));
  }

  /// 开始接收数据
  void startReceiving() {
    LoggerService.instance.i(
      '开始接收数据',
      category: LogCategory.stream,
      tags: ['receiving'],
    );
    _updateState(currentState.copyWith(
      status: StreamStatus.streaming,
    ));
  }

  /// 处理文本块 - 改进异步处理确保内容完整性
  void handleTextChunk(String text) {
    LoggerService.instance.d(
      'StreamStateManager.handleTextChunk',
      category: LogCategory.stream,
      tags: ['chunk', 'start'],
    );
    LoggerService.instance.d(
      '收到文本: "$text"',
      category: LogCategory.stream,
      tags: ['chunk', 'text'],
    );
    LoggerService.instance.d(
      '当前长度: ${currentState.characterCount}, 状态: ${currentState.status}',
      category: LogCategory.stream,
      tags: ['chunk', 'state'],
    );

    final newContent = currentState.content + text;
    final newCharacterCount = newContent.length;

    LoggerService.instance.d(
      '准备更新状态: $newCharacterCount 字符',
      category: LogCategory.stream,
      tags: ['chunk', 'update'],
    );

    // 使用 microtask 确保状态更新在下一个事件循环中执行
    _updateState(currentState.copyWith(
      status: StreamStatus.streaming,
      content: newContent,
      characterCount: newCharacterCount,
    ));

    LoggerService.instance.d(
      '状态更新完成',
      category: LogCategory.stream,
      tags: ['chunk', 'updated'],
    );

    // 使用 microtask 确保回调在状态更新后执行
    scheduleMicrotask(() {
      LoggerService.instance.d(
        '调用 _onTextChunk 回调...',
        category: LogCategory.stream,
        tags: ['chunk', 'callback'],
      );
      try {
        _onTextChunk(text);
        LoggerService.instance.d(
          '_onTextChunk 回调完成',
          category: LogCategory.stream,
          tags: ['chunk', 'callback'],
        );
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          '_onTextChunk 回调错误: $e',
          stackTrace: stackTrace.toString(),
          category: LogCategory.stream,
          tags: ['chunk', 'error'],
        );
      }
    });

    LoggerService.instance.d(
      'StreamStateManager 文本块处理完成, 最终长度: $newCharacterCount, 最终状态: ${currentState.status}',
      category: LogCategory.stream,
      tags: ['chunk', 'complete'],
    );
  }

  /// 完成流式交互 - 传递完整内容
  void complete() {
    LoggerService.instance.i(
      '流式交互完成, 总字符数: ${currentState.characterCount}',
      category: LogCategory.stream,
      tags: ['complete', 'start'],
    );
    final startTime = currentState.startTime;
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      LoggerService.instance.i(
        '耗时: ${duration}ms',
        category: LogCategory.stream,
        tags: ['complete', 'duration'],
      );
    }

    final completeContent = currentState.content;
    LoggerService.instance.i(
      '完整内容长度: ${completeContent.length}',
      category: LogCategory.stream,
      tags: ['complete', 'content'],
    );

    _updateState(currentState.copyWith(
      status: StreamStatus.completed,
      endTime: DateTime.now(),
    ));

    // 调用回调，传递完整内容
    LoggerService.instance.d(
      '调用 _onCompleted 回调，传递完整内容...',
      category: LogCategory.stream,
      tags: ['complete', 'callback'],
    );
    _onCompleted(completeContent);
    LoggerService.instance.i(
      '_onCompleted 回调完成',
      category: LogCategory.stream,
      tags: ['complete', 'callback'],
    );
  }

  /// 处理错误
  void handleError(String error) {
    LoggerService.instance.e(
      '流式交互错误: $error',
      category: LogCategory.stream,
      tags: ['error'],
    );

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
    LoggerService.instance.i(
      '重置流式状态',
      category: LogCategory.stream,
      tags: ['reset'],
    );
    _updateState(StreamState(status: StreamStatus.idle));
  }

  /// 释放资源
  void dispose() {
    LoggerService.instance.i(
      '释放流式状态管理器',
      category: LogCategory.stream,
      tags: ['dispose'],
    );
    _stateNotifier.dispose();
  }

  /// 更新状态（内部方法）
  void _updateState(StreamState newState) {
    LoggerService.instance.d(
      '状态更新: 旧状态=$currentState, 新状态=$newState',
      category: LogCategory.stream,
      tags: ['state', 'update'],
    );

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
