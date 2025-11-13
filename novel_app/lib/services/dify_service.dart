import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dify_sse_parser.dart';
import 'stream_state_manager.dart';

class DifyService {
  Future<String> generateCloseUp({
    required String selectedParagraph,
    required String userInput,
    required String currentChapterContent,
    required List<String> historyChaptersContent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = prefs.getString('dify_token');

    if (difyUrl == null ||
        difyUrl.isEmpty ||
        difyToken == null ||
        difyToken.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL 和 Token');
    }

    final url = Uri.parse('$difyUrl/workflows/run');

    final body = jsonEncode({
      'inputs': {
        'user_input': userInput,
        'cmd': '特写',
        'history_chapters_content': historyChaptersContent.join('\n\n'),
        'current_chapter_content': currentChapterContent,
        'choice_content': selectedParagraph,
      },
      'response_mode': 'blocking',
      'user': 'novel-builder-app',
    });

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

      final workflowData = data['data'];
      if (workflowData != null && workflowData['status'] == 'succeeded') {
        final outputs = workflowData['outputs'];
        if (outputs != null) {
          if (outputs.values.isNotEmpty) {
            return outputs.values.first.toString();
          } else {
            return 'Workflow executed successfully, but returned no output.';
          }
        }
      } else {
        final error = workflowData?['error'] ?? 'Unknown workflow error';
        throw Exception('Workflow execution failed: $error');
      }
      return 'No valid output from workflow.';
    } else {
      throw Exception(
          'Dify API 请求失败: ${response.statusCode}\n${response.body}');
    }
  }

  // 流式生成特写内容 - 使用新的SSE解析器
  Future<void> generateCloseUpStreaming({
    required String selectedParagraph,
    required String userInput,
    required String currentChapterContent,
    required List<String> historyChaptersContent,
    String backgroundSetting = '',
    required Function(String chunk) onChunk,
    Function()? onComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = prefs.getString('dify_token');
    final aiWriterSetting = prefs.getString('ai_writer_prompt') ?? '';

    if (difyUrl == null ||
        difyUrl.isEmpty ||
        difyToken == null ||
        difyToken.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL 和 Token');
    }

      // 创建状态管理器
    late final StreamStateManager stateManager;
    stateManager = StreamStateManager(
      onTextChunk: onChunk,
      onCompleted: (String completeContent) {
        debugPrint('🎯 === 特写生成完成 ===');
        debugPrint('完整内容长度: ${completeContent.length}');
        debugPrint('完整内容预览: "${completeContent.substring(0, completeContent.length > 100 ? 100 : completeContent.length)}..."');

        // 在完成时将完整内容通过特殊标记传递，确保UI显示完整内容
        if (completeContent.isNotEmpty) {
          onChunk('<<COMPLETE_CONTENT>>$completeContent'); // 使用特殊标记标识完整内容
        }

        onComplete?.call();
        stateManager.dispose();
      },
      onError: (error) {
        debugPrint('❌ === 特写生成错误 ===');
        debugPrint('错误: $error');
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
        },
        'response_mode': 'streaming',
        'user': 'novel-builder-app',
      };

      debugPrint('🚀 === Dify 特写 API 请求 ===');
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
            debugPrint('🔥 === onChunk回调 ===');
            debugPrint('文本块: "$textChunk"');
            debugPrint('当前状态: ${stateManager.currentState}');
            stateManager.handleTextChunk(textChunk);
            debugPrint('✅ stateManager.handleTextChunk 完成');
            debugPrint('========================');
          },
          onDone: () {
            debugPrint('📝 文本流结束');
            textStreamDone = true;

            // 添加短暂延迟，确保最后的文本块被处理
            Future.delayed(const Duration(milliseconds: 100), () {
              if (completer.isCompleted) return;
              debugPrint('⏰ 文本流结束后的延迟检查');
              if (!textStreamError) {
                completer.complete(true);
              }
            });
          },
          onError: (error) {
            debugPrint('❌ 文本流错误: $error');
            textStreamError = true;
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        // 监听工作流完成事件，作为备用完成机制
        DifySSEParser.waitForCompletion(eventStream).then((workflowCompleted) {
          debugPrint('✅ 工作流完成事件: $workflowCompleted');
          debugPrint('📊 完成时总字符数: ${stateManager.currentState.characterCount}');

          // 如果文本流已经结束，不重复处理
          if (textStreamDone || completer.isCompleted) return;

          // 工作流完成时，给文本流一些时间处理最后的数据
          Future.delayed(const Duration(milliseconds: 200), () {
            if (completer.isCompleted) return;
            debugPrint('⏰ 工作流完成后的延迟检查');
            completer.complete(workflowCompleted);
          });
        }).catchError((error) {
          debugPrint('❌ 等待工作流完成时出错: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        });

        try {
          // 等待流处理完成
          final isCompleted = await completer.future.timeout(
            const Duration(minutes: 10), // 10分钟超时
            onTimeout: () {
              debugPrint('⏰ 流处理超时');
              return textStreamDone && !textStreamError;
            }
          );

          debugPrint('🎯 === 流处理最终结果 ===');
          debugPrint('完成状态: $isCompleted');
          debugPrint('最终字符数: ${stateManager.currentState.characterCount}');

          if (isCompleted) {
            stateManager.complete();
          } else {
            stateManager.handleError('流处理未正确完成');
          }
        } catch (e) {
          debugPrint('❌ === 流处理异常 ===');
          debugPrint('异常: $e');
          stateManager.handleError('流处理异常: $e');
        } finally {
          // 确保取消订阅
          await textSubscription.cancel();
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        debugPrint('❌ === API 错误响应 ===');
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

        stateManager.handleError('API请求失败 (${streamedResponse.statusCode}): $errorMessage');
      }
    } catch (e) {
      debugPrint('❌ === 特写生成异常 ===');
      debugPrint('异常: $e');
      stateManager.handleError('网络或解析异常: $e');
    }
  }

  
  
  // 通用的流式工作流执行方法
  Future<void> runWorkflowStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    final difyToken = prefs.getString('dify_token');

    if (difyUrl == null ||
        difyUrl.isEmpty ||
        difyToken == null ||
        difyToken.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL 和 Token');
    }

    final url = Uri.parse('$difyUrl/workflows/run');

    final requestBody = {
      'inputs': inputs,
      'response_mode': 'streaming',
      'user': 'novel-builder-app',
    };

    debugPrint('=== Dify API 请求信息 ===');
    debugPrint('URL: $url');
    debugPrint('Request Body: ${jsonEncode(requestBody)}');
    debugPrint('======================');

    final body = jsonEncode(requestBody);

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer $difyToken',
      'Content-Type': 'application/json',
    });
    request.body = body;

    try {
      final streamedResponse = await request.send();

      debugPrint('Response Status Code: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        bool doneCalled = false;
        bool hasReceivedData = false;

        await for (var chunk
            in streamedResponse.stream.transform(utf8.decoder)) {
          debugPrint('收到流式数据块: $chunk');

          // 解析 SSE 格式的数据
          final lines = chunk.split('\n');
          for (var line in lines) {
            debugPrint('处理行: $line');

            if (line.startsWith('data: ')) {
              final dataStr = line.substring(6);
              if (dataStr.trim().isEmpty) continue;

              try {
                final data = jsonDecode(dataStr);
                debugPrint('解析的数据: $data');

                // 处理文本块事件
                if (data['event'] == 'text_chunk' && data['data'] != null) {
                  final text = data['data']['text'];
                  debugPrint('提取的文本: $text');
                  if (text != null && text.isNotEmpty) {
                    hasReceivedData = true;
                    debugPrint('调用onData: "$text"');
                    onData(text);
                  }
                }
                // 处理工作流完成事件
                else if (data['event'] == 'workflow_finished') {
                  debugPrint('工作流完成事件: ${data['data']}');
                  // 调用完成回调
                  if (onDone != null && !doneCalled) {
                    doneCalled = true;
                    debugPrint('调用onDone');
                    onDone();
                  }
                }
                // 处理工作流错误事件
                else if (data['event'] == 'workflow_error') {
                  debugPrint('工作流错误事件: ${data['data']}');
                  if (onDone != null && !doneCalled) {
                    doneCalled = true;
                    debugPrint('错误时调用onDone');
                    onDone(); // 即使出错也要结束生成状态
                  }
                }
                // 处理其他事件类型，用于调试
                else {
                  debugPrint('未处理的事件类型: ${data['event']}');
                  debugPrint('事件数据: ${data['data']}');
                }
              } catch (e) {
                debugPrint('解析错误: $e, 数据: $dataStr');
                // 忽略解析错误，继续处理下一行
                continue;
              }
            }
          }
        }

        // 流结束，如果还没有调用过 onDone，这里调用一次作为后备
        debugPrint('流式传输结束，hasReceivedData: $hasReceivedData');
        if (onDone != null && !doneCalled) {
          debugPrint('流结束后调用 onDone（后备方案）');
          doneCalled = true;
          onDone();
        }
      } else {
        // 读取错误响应内容
        final errorBody = await streamedResponse.stream.bytesToString();
        debugPrint('Error Response Body: $errorBody');

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
}
