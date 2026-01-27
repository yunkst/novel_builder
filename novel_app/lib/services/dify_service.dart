import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../models/ai_companion_response.dart';
import 'dify_sse_parser.dart';
import 'stream_state_manager.dart';
import 'logger_service.dart';

class DifyService {
  // 获取流式响应token
  Future<String> _getFlowToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('dify_flow_token');
    if (token == null || token.isEmpty) {
      throw Exception('请先在设置中配置 Flow Token (流式响应)');
    }
    return token;
  }

  // 获取结构化响应token
  // 用于 runWorkflowBlocking 方法
  Future<String> _getStructToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('dify_struct_token');
    if (token == null || token.isEmpty) {
      // 如果struct_token不存在，尝试使用flow_token作为降级
      final flowToken = prefs.getString('dify_flow_token');
      if (flowToken != null && flowToken.isNotEmpty) {
        LoggerService.instance.w(
          '⚠️ Struct Token未配置，使用Flow Token作为降级',
          category: LogCategory.ai,
          tags: ['warning', 'dify'],
        );
        return flowToken;
      }
      throw Exception('请先在设置中配置 Struct Token (结构化响应)');
    }
    return token;
  }

  /// @deprecated 请使用 [runWorkflowStreaming] 代替
  ///
  /// 此方法将在未来版本中移除。
  /// 迁移示例：
  /// ```dart
  /// // 旧方式
  /// await difyService.generateCloseUpStreaming(
  ///   selectedParagraph: '...',
  ///   userInput: '...',
  ///   onChunk: (chunk) { ... },
  /// );
  ///
  /// // 新方式
  /// await difyService.runWorkflowStreaming(
  ///   inputs: {
  ///     'cmd': '特写',
  ///     'choice_content': '...',
  ///     'user_input': '...',
  ///     // ...
  ///   },
  ///   onData: (chunk) { ... },
  ///   enableDebugLog: true,  // 可选：启用详细日志
  /// );
  /// ```
  @Deprecated(
      'Use runWorkflowStreaming() instead. See documentation for migration guide.')
  Future<void> generateCloseUpStreaming({
    required String selectedParagraph,
    required String userInput,
    required String currentChapterContent,
    required List<String> historyChaptersContent,
    String backgroundSetting = '',
    String? roles, // 新增角色参数
    required Function(String chunk) onChunk,
    Function()? onComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = await _getFlowToken();
    final aiWriterSetting = prefs.getString('ai_writer_prompt') ?? '';

    if (difyUrl == null || difyUrl.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL');
    }

    // 创建状态管理器
    late final StreamStateManager stateManager;
    stateManager = StreamStateManager(
      onTextChunk: onChunk,
      onCompleted: (String completeContent) {
        LoggerService.instance.i(
          '🎯 === 特写生成完成 ===',
          category: LogCategory.ai,
          tags: ['success', 'dify'],
        );
        LoggerService.instance.d(
          '完整内容长度: ${completeContent.length}',
          category: LogCategory.ai,
          tags: ['stats', 'dify'],
        );
        LoggerService.instance.d(
          '完整内容预览: "${completeContent.substring(0, completeContent.length > 100 ? 100 : completeContent.length)}..."',
          category: LogCategory.ai,
          tags: ['stats', 'preview', 'dify'],
        );

        // 在完成时将完整内容通过特殊标记传递，确保UI显示完整内容
        if (completeContent.isNotEmpty) {
          onChunk('<<COMPLETE_CONTENT>>$completeContent'); // 使用特殊标记标识完整内容
        }

        onComplete?.call();
        stateManager.dispose();
      },
      onError: (error) {
        LoggerService.instance.e(
          '❌ === 特写生成错误 ===',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        LoggerService.instance.e(
          '错误: $error',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        stateManager.dispose();
        throw Exception('特写生成失败: $error');
      },
    );

    try {
      stateManager.startStreaming();

      final url = Uri.parse('$difyUrl/workflows/run');
      final requestBody = {
        'inputs': {
          'user_input': userInput,
          'cmd': '特写',
          'ai_writer_setting': aiWriterSetting,
          'history_chapters_content': historyChaptersContent.join('\n\n'),
          'current_chapter_content': currentChapterContent,
          'choice_content': selectedParagraph,
          'background_setting': backgroundSetting,
          'roles': roles ?? '无特定角色出场',
        },
        'response_mode': 'streaming',
        'user': 'novel-builder-app',
      };

      LoggerService.instance.i(
        '🚀 === Dify 特写 API 请求 ===',
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
        '==========================',
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

        // 使用新的SSE解析器
        final inputStream = streamedResponse.stream.transform(utf8.decoder);
        final eventStream = DifySSEParser.parseStream(inputStream);
        final textStream = DifySSEParser.extractTextStream(eventStream);

        // 使用更安全的流处理方式，避免时序问题
        final completer = Completer<bool>();
        bool textStreamDone = false;
        bool textStreamError = false;

        // 监听文本流
        final textSubscription = textStream.listen(
          (textChunk) {
            LoggerService.instance.d(
              '🔥 === onChunk回调 ===',
              category: LogCategory.ai,
              tags: ['stream', 'chunk', 'dify'],
            );
            LoggerService.instance.d(
              '文本块: "$textChunk"',
              category: LogCategory.ai,
              tags: ['stream', 'chunk', 'dify'],
            );
            LoggerService.instance.i(
              '当前状态: ${stateManager.currentState}',
              category: LogCategory.ai,
              tags: ['info', 'dify'],
            );
            stateManager.handleTextChunk(textChunk);
            LoggerService.instance.i(
              '✅ stateManager.handleTextChunk 完成',
              category: LogCategory.ai,
              tags: ['success', 'dify'],
            );
            LoggerService.instance.d(
              '========================',
              category: LogCategory.ai,
              tags: ['debug', 'separator', 'dify'],
            );
          },
          onDone: () {
            LoggerService.instance.i(
              '📝 文本流结束',
              category: LogCategory.ai,
              tags: ['stream', 'end', 'dify'],
            );
            textStreamDone = true;

            // 添加短暂延迟，确保最后的文本块被处理
            Future.delayed(const Duration(milliseconds: 100), () {
              if (completer.isCompleted) return;
              LoggerService.instance.i(
                '⏰ 文本流结束后的延迟检查',
                category: LogCategory.ai,
                tags: ['stream', 'end', 'dify'],
              );
              if (!textStreamError) {
                completer.complete(true);
              }
            });
          },
          onError: (error) {
            LoggerService.instance.e(
              '❌ 文本流错误: $error',
              category: LogCategory.ai,
              tags: ['error', 'dify'],
            );
            textStreamError = true;
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        // 监听工作流完成事件，作为备用完成机制
        DifySSEParser.waitForCompletion(eventStream).then((workflowCompleted) {
          LoggerService.instance.i(
            '✅ 工作流完成事件: $workflowCompleted',
            category: LogCategory.ai,
            tags: ['success', 'dify'],
          );
          LoggerService.instance.i(
            '📊 完成时总字符数: ${stateManager.currentState.characterCount}',
            category: LogCategory.ai,
            tags: ['success', 'dify'],
          );

          // 如果文本流已经结束，不重复处理
          if (textStreamDone || completer.isCompleted) return;

          // 工作流完成时，给文本流一些时间处理最后的数据
          Future.delayed(const Duration(milliseconds: 200), () {
            if (completer.isCompleted) return;
            LoggerService.instance.i(
              '⏰ 工作流完成后的延迟检查',
              category: LogCategory.ai,
              tags: ['success', 'dify'],
            );
            completer.complete(workflowCompleted);
          });
        }).catchError((error) {
          LoggerService.instance.e(
            '❌ 等待工作流完成时出错: $error',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        });

        try {
          // 等待流处理完成
          final isCompleted = await completer.future
              .timeout(const Duration(minutes: 10), // 10分钟超时
                  onTimeout: () {
            LoggerService.instance.w(
              '⏰ 流处理超时',
              category: LogCategory.ai,
              tags: ['timeout', 'dify'],
            );
            return textStreamDone && !textStreamError;
          });

          LoggerService.instance.i(
            '🎯 === 流处理最终结果 ===',
            category: LogCategory.ai,
            tags: ['info', 'dify'],
          );
          LoggerService.instance.i(
            '完成状态: $isCompleted',
            category: LogCategory.ai,
            tags: ['success', 'dify'],
          );
          LoggerService.instance.i(
            '最终字符数: ${stateManager.currentState.characterCount}',
            category: LogCategory.ai,
            tags: ['info', 'dify'],
          );

          if (isCompleted) {
            stateManager.complete();
          } else {
            stateManager.handleError('流处理未正确完成');
          }
        } catch (e) {
          LoggerService.instance.e(
            '❌ === 流处理异常 ===',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          LoggerService.instance.e(
            '异常: $e',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          stateManager.handleError('流处理异常: $e');
        } finally {
          // 确保取消订阅
          await textSubscription.cancel();
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        LoggerService.instance.e(
          '❌ === API 错误响应 ===',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        LoggerService.instance.i(
          '状态码: ${streamedResponse.statusCode}',
          category: LogCategory.ai,
          tags: ['api', 'response', 'dify'],
        );
        LoggerService.instance.i(
          '响应体: $errorBody',
          category: LogCategory.ai,
          tags: ['api', 'response', 'dify'],
        );

        String errorMessage = '未知错误';
        try {
          final errorData = jsonDecode(errorBody);
          errorMessage = errorData['message'] ?? errorData['error'] ?? '未知错误';
          final errorCode = errorData['code'] ?? '';
          errorMessage = '错误码: $errorCode\n错误信息: $errorMessage';
        } catch (e) {
          errorMessage = errorBody;
        }

        stateManager.handleError(
            'API请求失败 (${streamedResponse.statusCode}): $errorMessage');
      }
    } catch (e) {
      LoggerService.instance.e(
        '❌ === 特写生成异常 ===',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      LoggerService.instance.e(
        '异常: $e',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      stateManager.handleError('网络或解析异常: $e');
    }
  }

  // 通用的流式工作流执行方法
  ///
  /// [inputs] Dify工作流输入参数
  /// [onData] 文本块回调
  /// [onError] 错误回调
  /// [onDone] 完成回调
  /// [enableDebugLog] 是否启用详细调试日志（使用StreamStateManager，默认false）
  Future<void> runWorkflowStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) async {
    // 如果启用调试日志，使用 StreamStateManager
    if (enableDebugLog) {
      await _runWorkflowStreamingWithManager(
        inputs: inputs,
        onData: onData,
        onError: onError,
        onDone: onDone,
      );
    } else {
      // 使用简单实现（默认）
      await _runWorkflowStreamingSimple(
        inputs: inputs,
        onData: onData,
        onError: onError,
        onDone: onDone,
      );
    }
  }

  // 简单实现（默认）
  Future<void> _runWorkflowStreamingSimple({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = await _getFlowToken();

    if (difyUrl == null || difyUrl.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL');
    }

    final url = Uri.parse('$difyUrl/workflows/run');

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
                  // 调用完成回调
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
                    onDone(); // 即使出错也要结束生成状态
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

        try {
          final errorData = jsonDecode(errorBody);
          final errorMessage =
              errorData['message'] ?? errorData['error'] ?? '未知错误';
          final errorCode = errorData['code'] ?? '';
          final fullError =
              'Dify API 请求失败 (${streamedResponse.statusCode})\n错误码: $errorCode\n错误信息: $errorMessage';
          if (onError != null) {
            onError(fullError);
          } else {
            throw Exception(fullError);
          }
        } catch (e) {
          final fullError =
              'Dify API 流式请求失败 (${streamedResponse.statusCode}): $errorBody';
          if (onError != null) {
            onError(fullError);
          } else {
            throw Exception(fullError);
          }
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

  // 使用 StreamStateManager 的实现（调试模式）
  Future<void> _runWorkflowStreamingWithManager({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = await _getFlowToken();

    if (difyUrl == null || difyUrl.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL');
    }

    final url = Uri.parse('$difyUrl/workflows/run');
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

  // 通用的阻塞式工作流执行方法
  Future<Map<String, dynamic>?> runWorkflowBlocking({
    required Map<String, dynamic> inputs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = await _getStructToken();

    if (difyUrl == null || difyUrl.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL');
    }

    final url = Uri.parse('$difyUrl/workflows/run');

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

      String errorMessage = '未知错误';
      try {
        final errorData = jsonDecode(errorBody);
        errorMessage = errorData['message'] ?? errorData['error'] ?? '未知错误';
        final errorCode = errorData['code'] ?? '';
        errorMessage = '错误码: $errorCode\n错误信息: $errorMessage';
      } catch (e) {
        errorMessage = errorBody;
      }

      throw Exception('Dify API 请求失败 (${response.statusCode}): $errorMessage');
    }
  }

  // AI生成角色专用方法
  Future<List<Character>> generateCharacters({
    required String userInput,
    required String novelUrl,
    required String backgroundSetting,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final aiWriterSetting = prefs.getString('ai_writer_prompt') ?? '';

    final inputs = {
      'user_input': userInput,
      'cmd': '生成',
      'ai_writer_setting': aiWriterSetting,
      'background_setting': backgroundSetting,
    };

    LoggerService.instance.i(
      '=== 开始AI生成角色 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.i(
      '用户输入: $userInput',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.i(
      '小说背景: $backgroundSetting',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.i(
      '作家设定: $aiWriterSetting',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    final outputs = await runWorkflowBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成失败：未收到有效响应');
    }

    // 获取content字段
    final content = outputs['content'];

    try {
      // 解析JSON数据

      LoggerService.instance.i(
        '=== JSON解析成功 ===',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );

      // 获取roles数组
      final List<dynamic> charactersData = content['roles'] ?? [];
      LoggerService.instance.d(
        '=== 角色数组长度: ${charactersData.length} ===',
        category: LogCategory.ai,
        tags: ['stats', 'dify'],
      );
      final List<Character> characters = [];

      for (var characterData in charactersData) {
        try {
          final character = Character(
            novelUrl: novelUrl,
            name: characterData['name']?.toString() ?? '未知角色',
            gender: characterData['gender']?.toString(),
            age: characterData['age'] is String
                ? int.tryParse(characterData['age']) ?? 0
                : characterData['age']?.toInt(),
            occupation: characterData['occupation']?.toString(),
            personality: characterData['personality']?.toString(),
            bodyType: characterData['bodyType']?.toString(),
            clothingStyle: characterData['clothingStyle']?.toString(),
            appearanceFeatures: characterData['appearanceFeatures']?.toString(),
            backgroundStory: characterData['backgroundStory']?.toString(),
          );
          characters.add(character);
        } catch (e) {
          LoggerService.instance.e(
            '解析角色数据失败: $e, 数据: $characterData',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          // 跳过无效的角色数据，继续处理其他角色
          continue;
        }
      }

      LoggerService.instance.i(
        '成功解析 ${characters.length} 个角色',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );
      return characters;
    } catch (e) {
      LoggerService.instance.e(
        '解析角色列表失败: $e, 原始数据: $content',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      throw Exception('角色数据解析失败: $e');
    }
  }

  /// 从大纲生成角色
  Future<List<Character>> generateCharactersFromOutline({
    required String outline,
    required String userInput,
    required String novelUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final aiWriterSetting = prefs.getString('ai_writer_prompt') ?? '';

    final inputs = {
      'outline': outline,
      'user_input': userInput,
      'cmd': '大纲生成角色',
      'ai_writer_setting': aiWriterSetting,
    };

    LoggerService.instance.i(
      '=== 开始从大纲生成角色 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.i(
      '用户输入: $userInput',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.d(
      '大纲长度: ${outline.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.i(
      '作家设定: $aiWriterSetting',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    final outputs = await runWorkflowBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成失败：未收到有效响应');
    }

    // 获取content字段
    final content = outputs['content'];

    try {
      // 解析JSON数据
      LoggerService.instance.i(
        '=== JSON解析成功 ===',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );

      // 获取roles数组
      final List<dynamic> charactersData = content['roles'] ?? [];
      LoggerService.instance.d(
        '=== 角色数组长度: ${charactersData.length} ===',
        category: LogCategory.ai,
        tags: ['stats', 'dify'],
      );
      final List<Character> characters = [];

      for (var characterData in charactersData) {
        try {
          final character = Character(
            novelUrl: novelUrl,
            name: characterData['name']?.toString() ?? '未知角色',
            gender: characterData['gender']?.toString(),
            age: characterData['age'] is String
                ? int.tryParse(characterData['age']) ?? 0
                : characterData['age']?.toInt(),
            occupation: characterData['occupation']?.toString(),
            personality: characterData['personality']?.toString(),
            bodyType: characterData['bodyType']?.toString(),
            clothingStyle: characterData['clothingStyle']?.toString(),
            appearanceFeatures: characterData['appearanceFeatures']?.toString(),
            backgroundStory: characterData['backgroundStory']?.toString(),
          );
          characters.add(character);
        } catch (e) {
          LoggerService.instance.e(
            '解析角色数据失败: $e, 数据: $characterData',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          // 跳过无效的角色数据，继续处理其他角色
          continue;
        }
      }

      LoggerService.instance.i(
        '成功解析 ${characters.length} 个角色',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );
      return characters;
    } catch (e) {
      LoggerService.instance.e(
        '解析角色列表失败: $e, 原始数据: $content',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      throw Exception('角色数据解析失败: $e');
    }
  }

  // 更新角色卡专用方法
  Future<List<Character>> updateCharacterCards({
    required String chaptersContent,
    required String roles,
    required String novelUrl,
    String backgroundSetting = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final aiWriterSetting = prefs.getString('ai_writer_prompt') ?? '';

    final inputs = {
      'chapters_content': chaptersContent,
      'roles': roles,
      'cmd': 'update_characters', // 使用新的命令类型
      'ai_writer_setting': aiWriterSetting,
      'background_setting': backgroundSetting,
    };

    LoggerService.instance.i(
      '=== 开始AI更新角色卡 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.d(
      '章节内容长度: ${chaptersContent.length} 字符',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.i(
      '现有角色信息: $roles',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.i(
      '小说背景: $backgroundSetting',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.i(
      '作家设定: $aiWriterSetting',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    final outputs = await runWorkflowBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('角色更新失败：未收到有效响应');
    }

    // 获取content字段
    final content = outputs['content'];

    try {
      // 解析JSON数据
      LoggerService.instance.i(
        '=== JSON解析成功 ===',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );

      // 获取roles数组
      final List<dynamic> charactersData = content['roles'] ?? [];
      LoggerService.instance.d(
        '=== 更新后角色数组长度: ${charactersData.length} ===',
        category: LogCategory.ai,
        tags: ['stats', 'dify'],
      );
      final List<Character> characters = [];

      for (var characterData in charactersData) {
        try {
          final character = Character(
            novelUrl: novelUrl,
            name: characterData['name']?.toString() ?? '未知角色',
            gender: characterData['gender']?.toString(),
            age: characterData['age'] is String
                ? int.tryParse(characterData['age']) ?? 0
                : characterData['age']?.toInt(),
            occupation: characterData['occupation']?.toString(),
            personality: characterData['personality']?.toString(),
            bodyType: characterData['bodyType']?.toString(),
            clothingStyle: characterData['clothingStyle']?.toString(),
            appearanceFeatures: characterData['appearanceFeatures']?.toString(),
            backgroundStory: characterData['backgroundStory']?.toString(),
          );
          characters.add(character);
          LoggerService.instance.i(
            '成功解析角色: ${character.name}',
            category: LogCategory.ai,
            tags: ['success', 'dify'],
          );
        } catch (e) {
          LoggerService.instance.e(
            '解析角色数据失败: $e, 数据: $characterData',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          // 跳过无效的角色数据，继续处理其他角色
          continue;
        }
      }

      LoggerService.instance.i(
        '成功更新 ${characters.length} 个角色',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );
      return characters;
    } catch (e) {
      LoggerService.instance.e(
        '解析更新角色列表失败: $e, 原始数据: $content',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      throw Exception('角色更新数据解析失败: $e');
    }
  }

  /// 从章节内容提取角色
  Future<List<Character>> extractCharacter({
    required String chapterContent,
    required String roles,
    required String novelUrl,
  }) async {
    final inputs = {
      'chapters_content': chapterContent,
      'roles': roles,
      'cmd': '提取角色',
    };

    LoggerService.instance.i(
      '=== 开始从章节提取角色 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.d(
      '章节内容长度: ${chapterContent.length} 字符',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.i(
      '角色名: $roles',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    final outputs = await runWorkflowBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('角色提取失败：未收到有效响应');
    }

    // 获取content字段
    final content = outputs['content'];

    try {
      // 解析JSON数据
      LoggerService.instance.i(
        '=== JSON解析成功 ===',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );

      // 获取roles数组
      final List<dynamic> charactersData = content['roles'] ?? [];
      LoggerService.instance.d(
        '=== 提取角色数组长度: ${charactersData.length} ===',
        category: LogCategory.ai,
        tags: ['stats', 'dify'],
      );
      final List<Character> characters = [];

      for (var characterData in charactersData) {
        try {
          final character = Character(
            novelUrl: novelUrl,
            name: characterData['name']?.toString() ?? '未知角色',
            gender: characterData['gender']?.toString(),
            age: characterData['age'] is String
                ? int.tryParse(characterData['age']) ?? 0
                : characterData['age']?.toInt(),
            occupation: characterData['occupation']?.toString(),
            personality: characterData['personality']?.toString(),
            bodyType: characterData['bodyType']?.toString(),
            clothingStyle: characterData['clothingStyle']?.toString(),
            appearanceFeatures: characterData['appearanceFeatures']?.toString(),
            backgroundStory: characterData['backgroundStory']?.toString(),
          );
          characters.add(character);
        } catch (e) {
          LoggerService.instance.e(
            '解析角色数据失败: $e, 数据: $characterData',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          continue;
        }
      }

      LoggerService.instance.i(
        '成功提取 ${characters.length} 个角色',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );
      return characters;
    } catch (e) {
      LoggerService.instance.e(
        '解析提取角色列表失败: $e, 原始数据: $content',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      throw Exception('角色提取数据解析失败: $e');
    }
  }

  /// 生成角色卡提示词
  Future<Map<String, String>> generateCharacterPrompts({
    required String characterDescription,
  }) async {
    final inputs = {
      'roles': characterDescription,
      'cmd': '角色卡提示词描写',
    };

    LoggerService.instance.i(
      '=== 开始AI生成角色卡提示词 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.i(
      '角色描述: $characterDescription',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    final outputs = await runWorkflowBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成提示词失败：未收到有效响应');
    }

    try {
      // 获取content字段
      final content = outputs['content'];

      if (content == null) {
        throw Exception('返回数据缺少content字段');
      }

      // 解析face_prompts和body_prompts
      final facePrompts = content['face_prompts']?.toString() ?? '';
      final bodyPrompts = content['body_prompts']?.toString() ?? '';

      LoggerService.instance.i(
        '=== 面部提示词: $facePrompts ===',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      LoggerService.instance.i(
        '=== 身材提示词: $bodyPrompts ===',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );

      return {
        'face_prompts': facePrompts,
        'body_prompts': bodyPrompts,
      };
    } catch (e) {
      LoggerService.instance.e(
        '解析角色卡提示词失败: $e, 原始数据: $outputs',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      throw Exception('角色卡提示词解析失败: $e');
    }
  }

  /// 格式化场景描写输入参数
  Map<String, dynamic> _formatSceneDescriptionInput({
    required String chapterContent,
    required List<Character> characters,
  }) {
    // 使用Character.formatForAI方法生成AI友好的角色信息格式
    final rolesText = Character.formatForAI(characters);

    final inputs = {
      'current_chapter_content': chapterContent,
      'roles': rolesText,
      'cmd': '场景描写',
    };

    LoggerService.instance.i(
      '=== 格式化场景描写输入参数 ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.d(
      '章节内容长度: ${chapterContent.length} 字符',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.d(
      '角色数量: ${characters.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.i(
      '角色信息格式化结果:\n$rolesText',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    return inputs;
  }

  /// @deprecated 请使用 [runWorkflowStreaming] 代替
  ///
  /// 此方法将在未来版本中移除。
  /// 迁移示例：
  /// ```dart
  /// // 旧方式
  /// await difyService.generateSceneDescriptionStream(
  ///   chapterContent: '...',
  ///   characters: [...],
  ///   onChunk: (chunk) { ... },
  /// );
  ///
  /// // 新方式
  /// await difyService.runWorkflowStreaming(
  ///   inputs: {
  ///     'cmd': '场景描写',
  ///     'chapter_content': '...',
  ///     // ...
  ///   },
  ///   onData: (chunk) { ... },
  ///   enableDebugLog: true,  // 可选：启用详细日志
  /// );
  /// ```
  @Deprecated(
      'Use runWorkflowStreaming() instead. See documentation for migration guide.')
  Future<void> generateSceneDescriptionStream({
    required String chapterContent,
    required List<Character> characters,
    required Function(String) onChunk, // 文本块回调
    required Function(String) onCompleted, // 完成回调，传递完整内容
    required Function(String) onError, // 错误回调
  }) async {
    // 格式化输入参数
    final inputs = _formatSceneDescriptionInput(
      chapterContent: chapterContent,
      characters: characters,
    );

    LoggerService.instance.i(
      '🚀 === 开始场景描写流式生成 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.d(
      '章节内容长度: ${chapterContent.length} 字符',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.d(
      '角色数量: ${characters.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.i(
      '输入参数: ${jsonEncode(inputs)}',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    // 创建状态管理器
    late final StreamStateManager stateManager;
    stateManager = StreamStateManager(
      onTextChunk: onChunk,
      onCompleted: (String completeContent) {
        LoggerService.instance.i(
          '🎯 === 场景描写生成完成 ===',
          category: LogCategory.ai,
          tags: ['success', 'dify'],
        );
        LoggerService.instance.d(
          '完整内容长度: ${completeContent.length}',
          category: LogCategory.ai,
          tags: ['stats', 'dify'],
        );
        LoggerService.instance.d(
          '完整内容预览: "${completeContent.substring(0, completeContent.length > 100 ? 100 : completeContent.length)}..."',
          category: LogCategory.ai,
          tags: ['stats', 'preview', 'dify'],
        );

        // 在完成时将完整内容通过特殊标记传递，确保UI显示完整内容
        if (completeContent.isNotEmpty) {
          onChunk('<<COMPLETE_CONTENT>>$completeContent'); // 使用特殊标记标识完整内容
        }

        onCompleted(completeContent);
        stateManager.dispose();
      },
      onError: (error) {
        LoggerService.instance.e(
          '❌ === 场景描写生成错误 ===',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        LoggerService.instance.e(
          '错误: $error',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        stateManager.dispose();
        throw Exception('场景描写生成失败: $error');
      },
    );

    try {
      stateManager.startStreaming();

      final prefs = await SharedPreferences.getInstance();
      final difyUrl = prefs.getString('dify_url');
      final difyToken = await _getFlowToken();

      if (difyUrl == null || difyUrl.isEmpty) {
        throw Exception('请先在设置中配置 Dify URL');
      }

      final url = Uri.parse('$difyUrl/workflows/run');

      final requestBody = {
        'inputs': inputs,
        'response_mode': 'streaming',
        'user': 'novel-builder-app',
      };

      LoggerService.instance.i(
        '🌐 === 场景描写 API 请求 ===',
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
        '==========================',
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
            LoggerService.instance.d(
              '🔥 === 场景描写文本块 ===',
              category: LogCategory.ai,
              tags: ['stream', 'chunk', 'dify'],
            );
            LoggerService.instance.i(
              '内容: "$textChunk"',
              category: LogCategory.ai,
              tags: ['info', 'dify'],
            );
            stateManager.handleTextChunk(textChunk);
            LoggerService.instance.i(
              '✅ 文本块处理完成',
              category: LogCategory.ai,
              tags: ['success', 'dify'],
            );
          },
          onDone: () {
            LoggerService.instance.i(
              '📝 场景描写文本流结束',
              category: LogCategory.ai,
              tags: ['stream', 'end', 'dify'],
            );
            textStreamDone = true;

            // 短暂延迟确保最后的文本块被处理
            Future.delayed(const Duration(milliseconds: 100), () {
              if (completer.isCompleted) return;
              if (!textStreamError) {
                completer.complete(true);
              }
            });
          },
          onError: (error) {
            LoggerService.instance.e(
              '❌ 场景描写文本流错误: $error',
              category: LogCategory.ai,
              tags: ['error', 'dify'],
            );
            textStreamError = true;
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        // 监听工作流完成事件
        DifySSEParser.waitForCompletion(eventStream).then((workflowCompleted) {
          LoggerService.instance.i(
            '✅ 场景描写工作流完成: $workflowCompleted',
            category: LogCategory.ai,
            tags: ['success', 'dify'],
          );
          LoggerService.instance.i(
            '📊 完成时总字符数: ${stateManager.currentState.characterCount}',
            category: LogCategory.ai,
            tags: ['success', 'dify'],
          );

          if (textStreamDone || completer.isCompleted) return;

          // 给文本流一些时间处理最后的数据
          Future.delayed(const Duration(milliseconds: 200), () {
            if (completer.isCompleted) return;
            completer.complete(workflowCompleted);
          });
        }).catchError((error) {
          LoggerService.instance.e(
            '❌ 场景描写工作流完成错误: $error',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        });

        try {
          // 等待流处理完成
          final isCompleted = await completer.future
              .timeout(const Duration(seconds: 15), // 15秒超时
                  onTimeout: () {
            LoggerService.instance.w(
              '⏰ 场景描写流处理超时',
              category: LogCategory.ai,
              tags: ['timeout', 'dify'],
            );
            return textStreamDone && !textStreamError;
          });

          LoggerService.instance.i(
            '🎯 === 场景描写流处理结果 ===',
            category: LogCategory.ai,
            tags: ['info', 'dify'],
          );
          LoggerService.instance.i(
            '完成状态: $isCompleted',
            category: LogCategory.ai,
            tags: ['success', 'dify'],
          );
          LoggerService.instance.i(
            '最终字符数: ${stateManager.currentState.characterCount}',
            category: LogCategory.ai,
            tags: ['info', 'dify'],
          );

          if (isCompleted) {
            stateManager.complete();
          } else {
            stateManager.handleError('场景描写流处理未正确完成');
          }
        } catch (e) {
          LoggerService.instance.e(
            '❌ === 场景描写流处理异常 ===',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          LoggerService.instance.e(
            '异常: $e',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          stateManager.handleError('场景描写流处理异常: $e');
        } finally {
          await textSubscription.cancel();
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        LoggerService.instance.e(
          '❌ === 场景描写 API 错误 ===',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        LoggerService.instance.i(
          '状态码: ${streamedResponse.statusCode}',
          category: LogCategory.ai,
          tags: ['api', 'response', 'dify'],
        );
        LoggerService.instance.i(
          '响应体: $errorBody',
          category: LogCategory.ai,
          tags: ['api', 'response', 'dify'],
        );

        String errorMessage = '未知错误';
        try {
          final errorData = jsonDecode(errorBody);
          errorMessage = errorData['message'] ?? errorData['error'] ?? '未知错误';
          final errorCode = errorData['code'] ?? '';
          errorMessage = '错误码: $errorCode\n错误信息: $errorMessage';
        } catch (e) {
          errorMessage = errorBody;
        }

        stateManager.handleError(
            '场景描写API请求失败 (${streamedResponse.statusCode}): $errorMessage');
      }
    } catch (e) {
      LoggerService.instance.e(
        '❌ === 场景描写生成异常 ===',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      LoggerService.instance.e(
        '异常: $e',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      stateManager.handleError('场景描写网络或解析异常: $e');
    }
  }

  /// 生成沉浸体验剧本
  ///
  /// [chapterContent] 章节内容
  /// [characters] 角色对象列表（包含完整角色信息）
  /// [userInput] 用户要求
  /// [userChoiceRole] 用户选择的角色名
  /// [existingPlay] 现有剧本（用于重新生成）
  /// [existingRoleStrategy] 现有角色策略（用于重新生成，List&lt;Map&lt;String, dynamic&gt;&gt;类型）
  Future<Map<String, dynamic>?> generateImmersiveScript({
    required String chapterContent,
    required List<Character> characters,
    required String userInput,
    required String userChoiceRole,
    String? existingPlay,
    List<Map<String, dynamic>>? existingRoleStrategy,
  }) async {
    // 使用 Character.formatForAI() 格式化角色信息
    final formattedRoles = Character.formatForAI(characters);

    final Map<String, dynamic> inputs = {
      'cmd': '生成剧本',
      'chapters_content': chapterContent,     // 参数名修改: chapter_content -> chapters_content
      'roles': formattedRoles,                // 使用格式化后的完整信息
      'user_input': userInput,
      'user_choice_role': userChoiceRole,
    };

    // 如果是重新生成，添加现有数据
    if (existingPlay != null) {
      inputs['play'] = existingPlay;
    }
    if (existingRoleStrategy != null) {
      inputs['role_strategy'] = existingRoleStrategy;
    }

    LoggerService.instance.i(
      '=== 开始生成沉浸体验剧本 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.d(
      '章节内容长度: ${chapterContent.length} 字符',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.d(
      '参与角色数量: ${characters.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.i(
      '格式化后角色信息:\n$formattedRoles',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.i(
      '用户要求: $userInput',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    LoggerService.instance.i(
      '用户角色: $userChoiceRole',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );
    if (existingPlay != null) {
      LoggerService.instance.d(
        '现有剧本长度: ${existingPlay.length} 字符',
        category: LogCategory.ai,
        tags: ['stats', 'dify'],
      );
    }
    if (existingRoleStrategy != null) {
      LoggerService.instance.d(
        '现有角色策略数量: ${existingRoleStrategy.length}',
        category: LogCategory.ai,
        tags: ['stats', 'dify'],
      );
    }

    final outputs = await runWorkflowBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成失败：未收到有效响应');
    }

    // 检查是否有 content 字段包裹（Dify 返回的嵌套结构）
    final content = outputs['content'] as Map<String, dynamic>?;
    if (content != null) {
      // Dify 返回的是 {content: {play, role_strategy}} 格式
      final play = content['play'] as String?;
      final roleStrategyRaw = content['role_strategy'];

      if (play == null || roleStrategyRaw == null) {
        LoggerService.instance.e(
          '❌ content字段解析失败: play=$play, role_strategy=$roleStrategyRaw',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        LoggerService.instance.i(
          '完整content数据: $content',
          category: LogCategory.ai,
          tags: ['info', 'dify'],
        );
        throw Exception('返回数据格式错误：content字段缺少play或role_strategy');
      }

      // 解析 role_strategy（支持字符串和数组两种格式）
      final roleStrategy = _parseRoleStrategy(roleStrategyRaw);

      // 返回扁平化的数据结构，与现有代码兼容
      return {
        'play': play,
        'role_strategy': roleStrategy,
      };
    }

    // 兼容非嵌套结构（直接返回 play 和 role_strategy）
    final play = outputs['play'] as String?;
    final roleStrategyRaw = outputs['role_strategy'];

    if (play == null || roleStrategyRaw == null) {
      LoggerService.instance.e(
        '❌ 扁平结构解析失败: play=$play, role_strategy=$roleStrategyRaw',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      LoggerService.instance.i(
        '完整outputs数据: $outputs',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      throw Exception('返回数据格式错误：缺少play或role_strategy字段');
    }

    // 解析 role_strategy（支持字符串和数组两种格式）
    final roleStrategy = _parseRoleStrategy(roleStrategyRaw);

    return {
      'play': play,
      'role_strategy': roleStrategy,
    };
  }

  /// 解析 role_strategy（支持字符串和数组两种格式）
  ///
  /// Dify可能返回：
  /// 1. 字符串格式: "[{\"name\": \"...\", \"strategy\": \"...\"}]"
  /// 2. 数组格式: [{"name": "...", "strategy": "..."}]
  List<dynamic> _parseRoleStrategy(dynamic roleStrategyRaw) {
    if (roleStrategyRaw is List) {
      // 已经是数组，直接返回
      return roleStrategyRaw;
    }

    if (roleStrategyRaw is String) {
      // 是字符串，需要解析JSON
      try {
        final decoded = jsonDecode(roleStrategyRaw);
        if (decoded is List) {
          return decoded;
        } else {
          LoggerService.instance.e(
            '❌ role_strategy字符串解析后不是数组: $decoded',
            category: LogCategory.ai,
            tags: ['error', 'dify'],
          );
          throw Exception('role_strategy格式错误：解析后不是数组');
        }
      } catch (e) {
        LoggerService.instance.e(
          '❌ role_strategy字符串解析失败: $e',
          category: LogCategory.ai,
          tags: ['error', 'dify'],
        );
        LoggerService.instance.i(
          '原始字符串: $roleStrategyRaw',
          category: LogCategory.ai,
          tags: ['info', 'dify'],
        );
        throw Exception('role_strategy字符串解析失败: $e');
      }
    }

    LoggerService.instance.e(
      '❌ role_strategy类型错误: ${roleStrategyRaw.runtimeType}',
      category: LogCategory.ai,
      tags: ['error', 'dify'],
    );
    throw Exception('role_strategy格式错误：不支持的类型 ${roleStrategyRaw.runtimeType}');
  }

  // ============================================================================
  // AI伴读功能
  // ============================================================================

  /// AI伴读功能
  ///
  /// 分析章节内容，返回：
  /// - 角色信息更新
  /// - 背景设定追加
  /// - 本章总结
  /// - 人物关系更新
  Future<AICompanionResponse?> generateAICompanion({
    required String chaptersContent,
    required String backgroundSetting,
    required List<Character> characters,
    required List<CharacterRelationship> relationships,
  }) async {
    // 格式化角色信息为JSON字符串
    final rolesJson = _formatCharactersForAI(characters);

    // 格式化关系信息为JSON字符串
    final relationsJson = _formatRelationshipsForAI(relationships, characters);

    final inputs = {
      'cmd': 'AI伴读',
      'chapters_content': chaptersContent,
      'background_setting': backgroundSetting,
      'roles': rolesJson,
      'relations': relationsJson,
    };

    LoggerService.instance.i(
      '=== 开始AI伴读分析 ===',
      category: LogCategory.ai,
      tags: ['api', 'request', 'dify'],
    );
    LoggerService.instance.d(
      '章节内容长度: ${chaptersContent.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.d(
      '背景设定长度: ${backgroundSetting.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.d(
      '角色数量: ${characters.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );
    LoggerService.instance.d(
      '关系数量: ${relationships.length}',
      category: LogCategory.ai,
      tags: ['stats', 'dify'],
    );

    final outputs = await runWorkflowBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI伴读失败：未收到有效响应');
    }

    try {
      // 使用AICompanionResponse解析
      final response = AICompanionResponse.fromOutputs(outputs);

      LoggerService.instance.i(
        '=== AI伴读解析成功 ===',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );
      LoggerService.instance.i(
        '角色更新: ${response.roles.length}',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      LoggerService.instance.i(
        '背景设定新增: ${response.background.length > 50 ? response.background.substring(0, 50) : response.background}',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      LoggerService.instance.i(
        '本章总结: ${response.summery.length > 50 ? response.summery.substring(0, 50) : response.summery}',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      LoggerService.instance.i(
        '关系更新: ${response.relations.length}',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );

      return response;
    } catch (e) {
      LoggerService.instance.e(
        '❌ AI伴读数据解析失败: $e',
        category: LogCategory.ai,
        tags: ['error', 'dify'],
      );
      LoggerService.instance.i(
        '原始outputs: $outputs',
        category: LogCategory.ai,
        tags: ['info', 'dify'],
      );
      throw Exception('AI伴读数据解析失败: $e');
    }
  }

  /// 格式化角色信息为AI友好的JSON字符串
  String _formatCharactersForAI(List<Character> characters) {
    if (characters.isEmpty) {
      return jsonEncode([]);
    }

    final List<Map<String, dynamic>> charactersData = characters.map((c) {
      return {
        'name': c.name,
        if (c.gender != null) 'gender': c.gender,
        if (c.age != null) 'age': c.age,
        if (c.occupation != null) 'occupation': c.occupation,
        if (c.personality != null) 'personality': c.personality,
        if (c.bodyType != null) 'bodyType': c.bodyType,
        if (c.clothingStyle != null) 'clothingStyle': c.clothingStyle,
        if (c.appearanceFeatures != null) 'appearanceFeatures': c.appearanceFeatures,
        if (c.backgroundStory != null) 'backgroundStory': c.backgroundStory,
      };
    }).toList();

    return jsonEncode(charactersData);
  }

  /// 格式化关系信息为AI友好的文本格式
  ///
  /// 输出格式：角色A → 关系类型 → 角色B
  /// 例如：
  ///   张三 → 师徒 → 李四
  ///   王五 → 恋人 → 赵六
  String _formatRelationshipsForAI(
    List<CharacterRelationship> relationships,
    List<Character> characters,
  ) {
    if (relationships.isEmpty) {
      return '';
    }

    // 创建角色ID到名称的映射
    final Map<int, String> characterIdToName = {
      for (var c in characters) if (c.id != null) c.id!: c.name,
    };

    // 格式化为 "角色A → 关系类型 → 角色B"
    final relations = relationships.map((r) {
      final sourceName = characterIdToName[r.sourceCharacterId] ?? '未知角色';
      final targetName = characterIdToName[r.targetCharacterId] ?? '未知角色';
      return '$sourceName → ${r.relationshipType} → $targetName';
    }).join('\n');

    return relations;
  }
}
