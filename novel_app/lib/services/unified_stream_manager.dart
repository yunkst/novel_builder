import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stream_config.dart';
import 'stream_state_manager.dart';
import 'dify_sse_parser.dart';

/// 统一流式管理器
/// 封装所有Dify流式API调用，提供标准化的流式内容处理接口
/// 实现Flutter最佳实践的内存管理和生命周期控制
class UnifiedStreamManager {
  static final UnifiedStreamManager _instance = UnifiedStreamManager._internal();
  factory UnifiedStreamManager() => _instance;
  UnifiedStreamManager._internal();

  // 活跃的流订阅管理
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, StreamStateManager> _activeStateManagers = {};
  bool _isDisposed = false;
  int _streamCounter = 0;

  /// 执行流式内容生成
  ///
  /// [config] 流式配置
  /// [onChunk] 文本块回调函数
  /// [onComplete] 完成回调函数，传递完整内容
  /// [onError] 错误回调函数
  /// [streamId] 可选的流ID，用于管理特定流的取消操作
  ///
  /// 返回流ID，可用于后续的取消操作
  Future<String?> executeStream({
    required StreamConfig config,
    required Function(String) onChunk,
    required Function(String) onComplete,
    required Function(String) onError,
    String? streamId,
  }) async {
    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('⚠️ UnifiedStreamManager已释放，无法执行新的流');
      onError('服务已释放');
      return null;
    }

    // 生成唯一的流ID
    final currentStreamId = streamId ?? 'stream_${++_streamCounter}_${DateTime.now().millisecondsSinceEpoch}';

    // 取消现有的同名流
    await cancelStream(currentStreamId);

    debugPrint('🚀 === 统一流式管理器开始执行 ===');
    debugPrint('流ID: $currentStreamId');
    debugPrint('配置类型: ${config.type}');
    debugPrint('实时显示: ${config.showRealTime}');
    debugPrint('自动滚动: ${config.autoScroll}');

    // 获取Dify配置
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = await _getFlowToken();

    if (difyUrl == null || difyUrl.isEmpty) {
      onError('请先在设置中配置 Dify URL');
      return null;
    }

    // 创建专用的状态管理器
    late final StreamStateManager stateManager;
    stateManager = StreamStateManager(
      onTextChunk: (textChunk) {
        if (_isDisposed) return; // 防止在已释放状态下回调

        debugPrint('🔥 === 收到文本块 ===');
        debugPrint('流ID: $currentStreamId');
        debugPrint('内容: "$textChunk"');
        debugPrint('当前状态: ${stateManager.currentState}');

        // 根据配置决定是否实时显示
        if (config.showRealTime) {
          onChunk(textChunk);
        }

        debugPrint('✅ 文本块处理完成');
      },
      onCompleted: (String completeContent) {
        if (_isDisposed) return; // 防止在已释放状态下回调

        debugPrint('🎯 === 流式生成完成 ===');
        debugPrint('流ID: $currentStreamId');
        debugPrint('完整内容长度: ${completeContent.length}');
        debugPrint('完整内容预览: "${completeContent.substring(0, completeContent.length > 100 ? 100 : completeContent.length)}..."');

        // 在完成时将完整内容通过特殊标记传递，确保UI显示完整内容
        if (completeContent.isNotEmpty) {
          onChunk('<<COMPLETE_CONTENT>>$completeContent'); // 使用特殊标记标识完整内容
        }

        onComplete(completeContent);
        _cleanupStream(currentStreamId);
      },
      onError: (error) {
        if (_isDisposed) return; // 防止在已释放状态下回调

        debugPrint('❌ === 流式生成错误 ===');
        debugPrint('流ID: $currentStreamId');
        debugPrint('错误: $error');
        onError('流式生成失败: $error');
        _cleanupStream(currentStreamId);
      },
    );

    // 保存状态管理器
    _activeStateManagers[currentStreamId] = stateManager;

    try {
      stateManager.startStreaming();

      final url = Uri.parse('$difyUrl/workflows/run');

      final requestBody = {
        'inputs': config.inputs,
        'response_mode': 'streaming',
        'user': 'novel-builder-app',
      };

      debugPrint('🌐 === 统一流式 API 请求 ===');
      debugPrint('URL: $url');
      debugPrint('Request Body: ${jsonEncode(requestBody)}');
      debugPrint('==========================');

      final request = http.Request('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $difyToken',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();

      debugPrint('📡 === 响应状态码: ${streamedResponse.statusCode} ===');

      if (streamedResponse.statusCode == 200) {
        stateManager.startReceiving();

        // 使用SSE解析器处理流式响应
        final inputStream = streamedResponse.stream.transform(utf8.decoder);
        final eventStream = DifySSEParser.parseStream(inputStream);
        final textStream = DifySSEParser.extractTextStream(eventStream);

        // 安全的流处理机制
        final completer = Completer<bool>();
        bool textStreamDone = false;
        bool textStreamError = false;

        // 监听文本流
        final textSubscription = textStream.listen(
          (textChunk) {
            if (_isDisposed) return; // 防止在已释放状态下处理

            debugPrint('🔥 === 统一流式文本块 ===');
            debugPrint('流ID: $currentStreamId');
            debugPrint('内容: "$textChunk"');
            stateManager.handleTextChunk(textChunk);
            debugPrint('✅ 文本块处理完成');
          },
          onDone: () {
            debugPrint('📝 统一流式文本流结束');
            debugPrint('流ID: $currentStreamId');
            textStreamDone = true;

            // 短暂延迟确保最后的文本块被处理
            Future.delayed(const Duration(milliseconds: 100), () {
              if (completer.isCompleted) return;
              if (!textStreamError) {
                completer.complete(true);
              }
            });
          },
          onError: (error, stackTrace) {
            debugPrint('❌ 统一流式文本流错误: $error');
            debugPrint('流ID: $currentStreamId');
            debugPrint('Stack trace: $stackTrace');
            textStreamError = true;
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        // 保存订阅以便管理
        _activeSubscriptions[currentStreamId] = textSubscription;

        // 监听工作流完成事件
        DifySSEParser.waitForCompletion(eventStream).then((workflowCompleted) {
          if (_isDisposed) return; // 防止在已释放状态下处理

          debugPrint('✅ 统一流式工作流完成: $workflowCompleted');
          debugPrint('流ID: $currentStreamId');
          debugPrint('📊 完成时总字符数: ${stateManager.currentState.characterCount}');

          if (textStreamDone || completer.isCompleted) return;

          // 给文本流一些时间处理最后的数据
          Future.delayed(const Duration(milliseconds: 200), () {
            if (completer.isCompleted) return;
            completer.complete(workflowCompleted);
          });
        }).catchError((error, stackTrace) {
          if (_isDisposed) return; // 防止在已释放状态下处理

          debugPrint('❌ 统一流式工作流完成错误: $error');
          debugPrint('流ID: $currentStreamId');
          debugPrint('Stack trace: $stackTrace');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        });

        try {
          // 等待流处理完成
          final isCompleted = await completer.future.timeout(
            const Duration(minutes: 5), // 5分钟超时
            onTimeout: () {
              debugPrint('⏰ 统一流式流处理超时');
              debugPrint('流ID: $currentStreamId');
              return textStreamDone && !textStreamError;
            }
          );

          debugPrint('🎯 === 统一流式流处理结果 ===');
          debugPrint('流ID: $currentStreamId');
          debugPrint('完成状态: $isCompleted');
          debugPrint('最终字符数: ${stateManager.currentState.characterCount}');

          if (isCompleted) {
            stateManager.complete();
          } else {
            stateManager.handleError('统一流式流处理未正确完成');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ === 统一流式流处理异常 ===');
          debugPrint('流ID: $currentStreamId');
          debugPrint('异常: $e');
          debugPrint('Stack trace: $stackTrace');
          stateManager.handleError('统一流式流处理异常: $e');
        } finally {
          // 确保取消订阅
          await textSubscription.cancel();
          _activeSubscriptions.remove(currentStreamId);
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        debugPrint('❌ === 统一流式 API 错误 ===');
        debugPrint('状态码: ${streamedResponse.statusCode}');
        debugPrint('响应体: $errorBody');

        String errorMessage = '未知错误';
        try {
          final errorData = jsonDecode(errorBody);
          errorMessage = errorData['message'] ?? errorData['error'] ?? '未知错误';
          final errorCode = errorData['code'] ?? '';
          errorMessage = '错误码: $errorCode\n错误信息: $errorMessage';
        } catch (e) {
          errorMessage = errorBody;
        }

        stateManager.handleError('统一流式API请求失败 (${streamedResponse.statusCode}): $errorMessage');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ === 统一流式生成异常 ===');
      debugPrint('流ID: $currentStreamId');
      debugPrint('异常: $e');
      debugPrint('Stack trace: $stackTrace');
      stateManager.handleError('统一流式网络或解析异常: $e');
      _cleanupStream(currentStreamId);
      return currentStreamId; // 即使出错也返回流ID
    }

    // 正常完成时返回流ID
    return currentStreamId;
  }

  /// 取消指定的流
  ///
  /// [streamId] 要取消的流ID
  Future<void> cancelStream(String streamId) async {
    debugPrint('🛑 取消流: $streamId');

    // 取消订阅
    final subscription = _activeSubscriptions[streamId];
    if (subscription != null) {
      await subscription.cancel();
      _activeSubscriptions.remove(streamId);
      debugPrint('✅ 流订阅已取消: $streamId');
    }

    // 清理状态管理器
    final stateManager = _activeStateManagers[streamId];
    if (stateManager != null) {
      stateManager.dispose();
      _activeStateManagers.remove(streamId);
      debugPrint('✅ 状态管理器已清理: $streamId');
    }
  }

  /// 清理流相关资源
  void _cleanupStream(String streamId) {
    _activeSubscriptions.remove(streamId);
    final stateManager = _activeStateManagers.remove(streamId);
    if (stateManager != null) {
      stateManager.dispose();
    }
    debugPrint('🧹 流资源已清理: $streamId');
  }

  /// 取消所有活跃的流
  Future<void> cancelAllStreams() async {
    debugPrint('🛑 取消所有活跃流，当前数量: ${_activeSubscriptions.length}');

    final streamIds = _activeSubscriptions.keys.toList();
    for (final streamId in streamIds) {
      await cancelStream(streamId);
    }

    debugPrint('✅ 所有流已取消');
  }

  /// 检查是否有活跃的流
  bool hasActiveStreams() {
    return _activeSubscriptions.isNotEmpty;
  }

  /// 获取活跃流数量
  int get activeStreamCount => _activeSubscriptions.length;

  /// 获取所有活跃流的ID列表
  List<String> getActiveStreamIds() {
    return _activeSubscriptions.keys.toList();
  }

  /// 释放管理器资源
  /// 最佳实践：在应用生命周期结束时调用
  Future<void> dispose() async {
    if (_isDisposed) return;

    debugPrint('🧹 开始释放 UnifiedStreamManager');
    _isDisposed = true;

    // 取消所有活跃的流
    await cancelAllStreams();

    // 清理所有资源
    _activeSubscriptions.clear();
    _activeStateManagers.clear();

    debugPrint('✅ UnifiedStreamManager 已完全释放');
  }

  /// 获取流式响应token
  Future<String> _getFlowToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('dify_flow_token');
    if (token == null || token.isEmpty) {
      throw Exception('请先在设置中配置 Flow Token (流式响应)');
    }
    return token;
  }
}