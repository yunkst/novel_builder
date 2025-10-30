import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

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

  // 流式生成特写内容
  Future<void> generateCloseUpStreaming({
    required String selectedParagraph,
    required String userInput,
    required String currentChapterContent,
    required List<String> historyChaptersContent,
    String backgroundSetting = '',
    required Function(String chunk) onChunk,
    Function()? onComplete, // 新增完成回调
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

    final streamedResponse = await request.send();

    debugPrint('Response Status Code: ${streamedResponse.statusCode}');

    if (streamedResponse.statusCode == 200) {
      bool completeCalled = false;

      await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
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
                  onChunk(text);
                }
              }
              // 处理工作流完成事件
              else if (data['event'] == 'workflow_finished') {
                debugPrint('工作流完成事件: ${data['data']}');
                // 调用完成回调
                if (onComplete != null && !completeCalled) {
                  completeCalled = true;
                  onComplete();
                }
              }
            } catch (e) {
              debugPrint('解析错误: $e, 数据: $dataStr');
              // 忽略解析错误，继续处理下一行
              continue;
            }
          }
        }
      }

      // 流结束，如果还没有调用过 onComplete，这里调用一次作为后备
      debugPrint('流式传输结束');
      if (onComplete != null && !completeCalled) {
        debugPrint('流结束后调用 onComplete（后备方案）');
        onComplete();
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
        throw Exception(
            'Dify API 请求失败 (${streamedResponse.statusCode})\n错误码: $errorCode\n错误信息: $errorMessage');
      } catch (e) {
        throw Exception(
            'Dify API 流式请求失败 (${streamedResponse.statusCode}): $errorBody');
      }
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
                    onData(text);
                  }
                }
                // 处理工作流完成事件
                else if (data['event'] == 'workflow_finished') {
                  debugPrint('工作流完成事件: ${data['data']}');
                  // 调用完成回调
                  if (onDone != null && !doneCalled) {
                    doneCalled = true;
                    onDone();
                  }
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
        debugPrint('流式传输结束');
        if (onDone != null && !doneCalled) {
          debugPrint('流结束后调用 onDone（后备方案）');
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
