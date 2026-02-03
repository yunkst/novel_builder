import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/stream_state_manager.dart';
import '../../services/logger_service.dart';
import 'dify_config_service.dart';

/// Dify工作流服务
///
/// 负责与Dify API的工作流交互，包括流式和阻塞式两种响应模式。
class DifyWorkflowService {
  final DifyConfigService _config;

  DifyWorkflowService({required DifyConfigService config}) : _config = config;

  /// 通用的流式工作流执行方法
  ///
  /// [inputs] Dify工作流输入参数
  /// [onData] 文本块回调
  /// [onError] 错误回调
  /// [onDone] 完成回调
  /// [enableDebugLog] 是否启用详细调试日志（使用StreamStateManager，默认false）
  Future<void> executeStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) async {
    // 如果启用调试日志，使用 StreamStateManager
    if (enableDebugLog) {
      await _executeStreamingWithManager(
        inputs: inputs,
        onData: onData,
        onError: onError,
        onDone: onDone,
      );
    } else {
      // 使用简单实现（默认）
      await _executeStreamingSimple(
        inputs: inputs,
        onData: onData,
        onError: onError,
        onDone: onDone,
      );
    }
  }

  /// 通用的阻塞式工作流执行方法
  Future<Map<String, dynamic>?> executeBlocking({
    required Map<String, dynamic> inputs,
  }) async {
    final difyUrl = await _config.getDifyUrl();
    final difyToken = await _config.getStructToken();

    final url = Uri.parse(_config.buildApiEndpoint(difyUrl, '/workflows/run'));

    final requestBody = {
      'inputs': inputs,
      'response_mode': 'blocking',
      'user': 'novel-builder-app',
    };

    LoggerService.instance.i(
      '=== Dify API 非流式请求 ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.d(
      'URL: $url',
      category: LogCategory.ai,
      tags: ['network', 'dify'],
    );
    LoggerService.instance.i(
      'Request Body: ${jsonEncode(requestBody)}',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.d(
      '========================',
      category: LogCategory.ai,
      tags: ['debug', 'separator', 'dify'],
    );

    final body = jsonEncode(requestBody);

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $difyToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      LoggerService.instance.i(
        '=== Dify API 非流式响应 ===',
        category: LogCategory.ai,
        tags: ['api', 'response', 'dify'],
      );
      LoggerService.instance.i(
        'Response: $data',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      LoggerService.instance.d(
        '==========================',
        category: LogCategory.ai,
        tags: ['debug', 'separator', 'dify'],
      );

      final workflowData = data['data'];
      if (workflowData != null && workflowData['status'] == 'succeeded') {
        final outputs = workflowData['outputs'];
        return outputs;
      } else {
        final error = workflowData?['error'] ?? 'Unknown workflow error';
        throw Exception('Workflow execution failed: $error');
      }
    } else {
      final errorBody = response.body;
      LoggerService.instance.e(
        '=== Dify API 错误响应 ===',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      LoggerService.instance.i(
        '状态码: ${response.statusCode}',
        category: LogCategory.ai,
        tags: ['api', 'response', 'dify'],
      );
      LoggerService.instance.i(
        '响应体: $errorBody',
        category: LogCategory.ai,
        tags: ['api', 'response', 'dify'],
      );
      LoggerService.instance.d(
        '========================',
        category: LogCategory.ai,
        tags: ['debug', 'separator', 'dify'],
      );

      String errorMessage = _parseErrorMessage(errorBody);
      throw Exception('Dify API 请求失败 (${response.statusCode}): $errorMessage');
    }
  }

  /// 简单流式实现（默认）
  Future<void> _executeStreamingSimple({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
  }) async {
    final difyUrl = await _config.getDifyUrl();
    final difyToken = await _config.getFlowToken();

    final url = Uri.parse(_config.buildApiEndpoint(difyUrl, '/workflows/run'));

    final requestBody = {
      'inputs': inputs,
      'response_mode': 'streaming',
      'user': 'novel-builder-app',
    };

    LoggerService.instance.i(
      '=== Dify API 请求信息 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.d(
      'URL: $url',
      category: LogCategory.ai,
      tags: ['network', 'dify'],
    );
    LoggerService.instance.i(
      'Request Body: ${jsonEncode(requestBody)}',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.d(
      '======================',
      category: LogCategory.ai,
      tags: ['debug', 'separator', 'dify'],
    );

    final body = jsonEncode(requestBody);

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer $difyToken',
      'Content-Type': 'application/json',
    });
    request.body = body;

    try {
      final streamedResponse = await request.send();

      LoggerService.instance.i(
        'Response Status Code: ${streamedResponse.statusCode}',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );

      if (streamedResponse.statusCode == 200) {
        bool doneCalled = false;
        bool hasReceivedData = false;

        await for (var chunk
            in streamedResponse.stream.transform(utf8.decoder)) {
          LoggerService.instance.i(
            '收到流式数据块: $chunk',
            category: LogCategory.ai,
            tags: ['info', 'dify'],
          );

          // 解析 SSE 格式的数据
          final lines = chunk.split('\n');
          for (var line in lines) {
            LoggerService.instance.i(
              '处理行: $line',
              category: LogCategory.ai,
              tags: ['info', 'dify'],
            );

            if (line.startsWith('data: ')) {
              final dataStr = line.substring(6);
              if (dataStr.trim().isEmpty) continue;

              try {
                final data = jsonDecode(dataStr);
                LoggerService.instance.i(
                  '解析的数据: $data',
                  category: LogCategory.ai,
                  tags: ['info', 'dify'],
                );

                // 处理文本块事件
                if (data['event'] == 'text_chunk' && data['data'] != null) {
                  final text = data['data']['text'];
                  LoggerService.instance.i(
                    '提取的文本: $text',
                    category: LogCategory.ai,
                    tags: ['info', 'dify'],
                  );
                  if (text != null && text.isNotEmpty) {
                    hasReceivedData = true;
                    LoggerService.instance.i(
                      '调用onData: "$text"',
                      category: LogCategory.ai,
                      tags: ['info', 'dify'],
                    );
                    onData(text);
                  }
                }
                // 处理工作流完成事件
                else if (data['event'] == 'workflow_finished') {
                  LoggerService.instance.i(
                    '工作流完成事件: ${data['data']}',
                    category: LogCategory.ai,
                    tags: ['success', 'dify'],
                  );
                  if (onDone != null && !doneCalled) {
                    doneCalled = true;
                    LoggerService.instance.i(
                      '调用onDone',
                      category: LogCategory.ai,
                      tags: ['info', 'dify'],
                    );
                    onDone();
                  }
                }
                // 处理工作流错误事件
                else if (data['event'] == 'workflow_error') {
                  LoggerService.instance.e(
                    '工作流错误事件: ${data['data']}',
                    category: LogCategory.ai,
                    tags: ['error', 'dify'],
                  );
                  if (onDone != null && !doneCalled) {
                    doneCalled = true;
                    LoggerService.instance.e(
                      '错误时调用onDone',
                      category: LogCategory.ai,
                      tags: ['error', 'dify'],
                    );
                    onDone();
                  }
                }
                // 处理其他事件类型，用于调试
                else {
                  LoggerService.instance.i(
                    '未处理的事件类型: ${data['event']}',
                    category: LogCategory.ai,
                    tags: ['info', 'dify'],
                  );
                  LoggerService.instance.i(
                    '事件数据: ${data['data']}',
                    category: LogCategory.ai,
                    tags: ['info', 'dify'],
                  );
                }
              } catch (e) {
                LoggerService.instance.e(
                  '解析错误: $e, 数据: $dataStr',
                  category: LogCategory.ai,
                  tags: ['error', 'dify'],
                );
                // 忽略解析错误，继续处理下一行
                continue;
              }
            }
          }
        }

        // 流结束，如果还没有调用过 onDone，这里调用一次作为后备
        LoggerService.instance.i(
          '流式传输结束，hasReceivedData: $hasReceivedData',
          category: LogCategory.ai,
          tags: ['info', 'dify'],
        );
        if (onDone != null && !doneCalled) {
          LoggerService.instance.i(
            '流结束后调用 onDone（后备方案）',
            category: LogCategory.ai,
            tags: ['stream', 'end', 'dify'],
          );
          doneCalled = true;
          onDone();
        }
      } else {
        // 读取错误响应内容
        final errorBody = await streamedResponse.stream.bytesToString();
        LoggerService.instance.i(
          'Error Response Body: $errorBody',
          category: LogCategory.ai,
          tags: ['info', 'dify'],
        );

        final fullError = _buildErrorFromResponse(
          streamedResponse.statusCode,
          errorBody,
        );
        if (onError != null) {
          onError(fullError);
        } else {
          throw Exception(fullError);
        }
      }
    } catch (e) {
      if (onError != null) {
        onError(e.toString());
      } else {
        rethrow;
      }
    }
  }

  /// 使用 StreamStateManager 的实现（调试模式）
  Future<void> _executeStreamingWithManager({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
  }) async {
    final difyUrl = await _config.getDifyUrl();
    final difyToken = await _config.getFlowToken();

    final url = Uri.parse(_config.buildApiEndpoint(difyUrl, '/workflows/run'));
    final requestBody = {
      'inputs': inputs,
      'response_mode': 'streaming',
      'user': 'novel-builder-app',
    };

    // 创建状态管理器
    late final StreamStateManager stateManager;
    stateManager = StreamStateManager(
      onTextChunk: (text) {
        onData(text); // 转发给外部回调
      },
      onCompleted: (String completeContent) {
        LoggerService.instance.i(
          '✅ === 流式交互完成（StreamStateManager） ===',
          category: LogCategory.ai,
          tags: ['success', 'dify'],
        );
        LoggerService.instance.d(
          '完整内容长度: ${completeContent.length}',
          category: LogCategory.ai,
          tags: ['stats', 'dify'],
        );
        onDone?.call();
        stateManager.dispose();
      },
      onError: (error) {
        LoggerService.instance.e(
          '❌ === 流式交互错误（StreamStateManager） ===',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        LoggerService.instance.e(
          '错误: $error',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        stateManager.dispose();
        onError?.call(error);
      },
    );

    try {
      stateManager.startStreaming();

      LoggerService.instance.i(
        '🚀 === Dify API 请求信息（启用详细日志） ===',
        category: LogCategory.ai,
        tags: ['api', 'request', 'dify'],
      );
      LoggerService.instance.d(
        'URL: $url',
        category: LogCategory.ai,
        tags: ['network', 'dify'],
      );
      LoggerService.instance.i(
        'Request Body: ${jsonEncode(requestBody)}',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      LoggerService.instance.d(
        '==========================================',
        category: LogCategory.ai,
        tags: ['debug', 'separator', 'dify'],
      );

      final request = http.Request('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $difyToken',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();

      LoggerService.instance.i(
        '📡 === 响应状态码: ${streamedResponse.statusCode} ===',
        category: LogCategory.ai,
        tags: ['api', 'response', 'dify'],
      );

      if (streamedResponse.statusCode == 200) {
        stateManager.startReceiving();

        await for (var chunk
            in streamedResponse.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
              final dataStr = line.substring(6);
              if (dataStr.trim().isEmpty) continue;

              try {
                final data = jsonDecode(dataStr);
                if (data['event'] == 'text_chunk' && data['data'] != null) {
                  final text = data['data']['text'];
                  if (text != null && text.isNotEmpty) {
                    stateManager.handleTextChunk(text);
                  }
                } else if (data['event'] == 'workflow_finished') {
                  stateManager.complete();
                } else if (data['event'] == 'workflow_error') {
                  final errorMsg = data['data']?['message'] ?? '工作流错误';
                  stateManager.handleError(errorMsg);
                }
              } catch (e) {
                LoggerService.instance.e(
                  '解析错误: $e',
                  category: LogCategory.ai,
                  tags: ['error', 'dify'],
                );
              }
            }
          }
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        stateManager.handleError(
            'API请求失败 (${streamedResponse.statusCode}): $errorBody');
      }
    } catch (e) {
      stateManager.handleError('网络或解析异常: $e');
    }
  }

  /// 解析错误消息
  String _parseErrorMessage(String errorBody) {
    try {
      final errorData = jsonDecode(errorBody);
      final errorMessage = errorData['message'] ?? errorData['error'] ?? '未知错误';
      final errorCode = errorData['code'] ?? '';
      return '错误码: $errorCode\n错误信息: $errorMessage';
    } catch (e) {
      return errorBody;
    }
  }

  /// 从响应构建错误信息
  String _buildErrorFromResponse(int statusCode, String errorBody) {
    try {
      final errorData = jsonDecode(errorBody);
      final errorMessage = errorData['message'] ?? errorData['error'] ?? '未知错误';
      final errorCode = errorData['code'] ?? '';
      return 'Dify API 请求失败 ($statusCode)\n错误码: $errorCode\n错误信息: $errorMessage';
    } catch (e) {
      return 'Dify API 流式请求失败 ($statusCode): $errorBody';
    }
  }
}
