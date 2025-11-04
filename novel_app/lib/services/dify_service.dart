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
      onCompleted: () {
        debugPrint('🎯 === 特写生成完成 ===');
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

        // 同时监听文本流和完成事件
        final completer = Completer<bool>();

        // 监听文本流
        textStream.listen(
          (textChunk) {
            debugPrint('🔥 === onChunk回调 ===');
            debugPrint('文本块: "$textChunk"');
            debugPrint('当前状态: ${stateManager.currentState}');
            stateManager.handleTextChunk(textChunk);
            debugPrint('✅ stateManager.handleTextChunk 完成');
            debugPrint('========================');
          },
          onDone: () {
            debugPrint('📝 文本流结束，但不一定表示工作流完成');
          },
          onError: (error) {
            debugPrint('❌ 文本流错误: $error');
          },
        );

        // 监听工作流完成事件（不终止文本流）
        DifySSEParser.waitForCompletion(eventStream).then((isCompleted) {
          debugPrint('✅ 工作流完成监听完成，成功: $isCompleted');
          debugPrint('📊 完成时总字符数: ${stateManager.currentState.characterCount}');
          completer.complete(isCompleted);
        }).catchError((error) {
          debugPrint('❌ 等待工作流完成时出错: $error');
          completer.complete(false);
        });

        // 等待工作流完成
        final isCompleted = await completer.future;
        if (isCompleted) {
          stateManager.complete();
        } else {
          stateManager.handleError('工作流执行失败');
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

  
  // 处理解析后的事件数据
  void _processEventData(
    Map<String, dynamic> data,
    String? eventType,
    Function(String chunk) onChunk,
    Function()? onComplete,
    Function() onDataReceived,
  ) {
    // 1. 检查是否是工作流完成事件
    if (_isWorkflowFinishedEvent(data)) {
      debugPrint('✅ 检测到工作流完成事件');
      if (onComplete != null) {
        onComplete();
      }
      return;
    }

    // 2. 检查是否是错误事件
    if (_isWorkflowErrorEvent(data)) {
      debugPrint('❌ 检测到工作流错误事件');
      if (onComplete != null) {
        onComplete();
      }
      return;
    }

    // 3. 尝试提取文本内容 - 支持多种可能的格式
    final textContent = _extractTextContent(data);
    if (textContent != null && textContent.isNotEmpty) {
      debugPrint('✅ 成功提取文本内容: "$textContent"');
      onDataReceived();
      onChunk(textContent);
    } else {
      debugPrint('⚠️ 事件中未找到有效文本内容');
      debugPrint('事件类型: $eventType');
      debugPrint('数据结构: ${data.keys}');
    }
  }

  // 检查是否是工作流完成事件
  bool _isWorkflowFinishedEvent(Map<String, dynamic> data) {
    // 检查多种可能的完成事件标识
    return data['event'] == 'workflow_finished' ||
        data['event'] == 'finished' ||
        data['status'] == 'succeeded' ||
        data['status'] == 'finished' ||
        data['type'] == 'end';
  }

  // 检查是否是工作流错误事件
  bool _isWorkflowErrorEvent(Map<String, dynamic> data) {
    return data['event'] == 'workflow_error' ||
        data['event'] == 'error' ||
        data['status'] == 'failed' ||
        data['status'] == 'error';
  }

  // 提取文本内容 - 精确识别AI生成内容，过滤SSE事件信号
  String? _extractTextContent(Map<String, dynamic> data) {
    debugPrint('🔍 === 开始提取AI生成内容 ===');

    // 首先检查是否是事件信号，如果是则跳过
    if (_isEventSignal(data)) {
      debugPrint('⚠️ 检测到事件信号，跳过文本提取');
      return null;
    }

    // 方式1: data.data.text (标准的Dify流式文本格式)
    if (data['data'] != null) {
      final dataField = data['data'];
      if (dataField is Map) {
        final text = dataField['text'];
        if (text != null && _isValidAIText(text.toString())) {
          debugPrint('✅ 方式1成功 - data.data.text: "$text"');
          return text.toString();
        }
      } else if (dataField is String && _isValidAIText(dataField)) {
        debugPrint('✅ 方式1成功 - data直接是文本: "$dataField"');
        return dataField;
      }
    }

    // 方式2: 直接的text字段 (非事件格式)
    if (data['text'] != null) {
      final text = data['text'].toString();
      if (_isValidAIText(text)) {
        debugPrint('✅ 方式2成功 - 直接text字段: "$text"');
        return text;
      }
    }

    // 方式3: content字段 (纯文本内容)
    if (data['content'] != null) {
      final content = data['content'].toString();
      if (_isValidAIText(content)) {
        debugPrint('✅ 方式3成功 - content字段: "$content"');
        return content;
      }
    }

    // 方式4: answer字段 (对话响应格式)
    if (data['answer'] != null) {
      final answer = data['answer'].toString();
      if (_isValidAIText(answer)) {
        debugPrint('✅ 方式4成功 - answer字段: "$answer"');
        return answer;
      }
    }

    // 方式5: 流式响应字段 (delta, chunk等)
    for (String fieldName in ['delta', 'chunk']) {
      if (data[fieldName] != null) {
        final fieldData = data[fieldName];
        String? text;

        if (fieldData is Map) {
          text = fieldData['text']?.toString() ??
                 fieldData['content']?.toString();
        } else if (fieldData is String) {
          text = fieldData;
        }

        if (text != null && _isValidAIText(text)) {
          debugPrint('✅ 方式5成功 - $fieldName字段: "$text"');
          return text;
        }
      }
    }

    // 方式6: outputs字段 (最终结果，但只提取有意义的文本)
    if (data['outputs'] != null) {
      final outputs = data['outputs'];
      if (outputs is Map) {
        for (final entry in outputs.entries) {
          final value = entry.value?.toString();
          if (value != null && _isValidAIText(value) && value.length > 10) {
            debugPrint('✅ 方式6成功 - outputs.${entry.key}: "$value"');
            return value;
          }
        }
      }
    }

    debugPrint('❌ 没有找到有效的AI生成内容');
    return null;
  }

  // 检查是否是事件信号而非文本内容
  bool _isEventSignal(Map<String, dynamic> data) {
    // 检查包含事件类型标识的字段
    final eventIndicators = [
      'event', 'status', 'type', 'workflow_run_id', 'task_id',
      'created_at', 'finished_at', 'elapsed_time', 'total_tokens'
    ];

    // 如果数据主要是事件元数据，则认为是事件信号
    int eventFieldCount = 0;
    int totalFields = data.keys.length;

    for (final key in data.keys) {
      if (eventIndicators.contains(key) ||
          key.endsWith('_id') ||
          key.endsWith('_time') ||
          key.startsWith('workflow_')) {
        eventFieldCount++;
      }
    }

    // 如果超过一半的字段是事件相关，则认为是事件信号
    final isEvent = (eventFieldCount > totalFields / 2) ||
                   (data['event'] != null && data['text'] == null);

    if (isEvent) {
      debugPrint('🚫 识别为事件信号: eventFieldCount=$eventFieldCount, totalFields=$totalFields');
    }

    return isEvent;
  }

  // 验证是否是有效的AI生成文本
  bool _isValidAIText(String text) {
    if (text.isEmpty) return false;

    // 过滤明显的事件信号或元数据
    final invalidPatterns = [
      RegExp(r'^[a-z_]+$'), // 纯小写字母加下划线（事件类型）
      RegExp(r'^\d+$'), // 纯数字
      RegExp(r'^[a-f0-9-]{36}$'), // UUID格式
      RegExp(r'^workflow_'), // workflow相关字段
      RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'), // 时间戳
      RegExp(r'^\{\s*\}$'), // 空JSON对象
      RegExp(r'^\[\s*\]$'), // 空JSON数组
    ];

    for (final pattern in invalidPatterns) {
      if (pattern.hasMatch(text.trim())) {
        debugPrint('🚫 文本匹配无效模式: "$text"');
        return false;
      }
    }

    // 检查最小长度（排除过短的可能是标识符的内容）
    if (text.trim().length < 2) {
      debugPrint('🚫 文本过短: "$text"');
      return false;
    }

    // 检查是否包含有意义的内容（至少包含一个中文字符或足够多的英文单词）
    final hasChineseChars = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    final hasEnglishWords = RegExp(r'\b[a-zA-Z]{3,}\b').hasMatch(text);

    if (!hasChineseChars && !hasEnglishWords && text.trim().length < 10) {
      debugPrint('🚫 文本缺少有意义内容: "$text"');
      return false;
    }

    debugPrint('✅ 文本验证通过: "$text"');
    return true;
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
