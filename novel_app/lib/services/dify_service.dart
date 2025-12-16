import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/character.dart';
import 'dify_sse_parser.dart';
import 'stream_state_manager.dart';


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
  // TODO: 为未来功能预留，当前未使用
  Future<String> _getStructToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('dify_struct_token');
    if (token == null || token.isEmpty) {
      // 如果struct_token不存在，尝试使用flow_token作为降级
      final flowToken = prefs.getString('dify_flow_token');
      if (flowToken != null && flowToken.isNotEmpty) {
        debugPrint('⚠️ Struct Token未配置，使用Flow Token作为降级');
        return flowToken;
      }
      throw Exception('请先在设置中配置 Struct Token (结构化响应)');
    }
    return token;
  }
  
  // 流式生成特写内容 - 使用新的SSE解析器
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
          'roles': roles ?? '无特定角色出场',
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

    debugPrint('=== Dify API 非流式请求 ===');
    debugPrint('URL: $url');
    debugPrint('Request Body: ${jsonEncode(requestBody)}');
    debugPrint('========================');

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

      debugPrint('=== Dify API 非流式响应 ===');
      debugPrint('Response: $data');
      debugPrint('==========================');

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
      debugPrint('=== Dify API 错误响应 ===');
      debugPrint('状态码: ${response.statusCode}');
      debugPrint('响应体: $errorBody');
      debugPrint('========================');

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

    debugPrint('=== 开始AI生成角色 ===');
    debugPrint('用户输入: $userInput');
    debugPrint('小说背景: $backgroundSetting');
    debugPrint('作家设定: $aiWriterSetting');

    final outputs = await runWorkflowBlocking(inputs: inputs);

    debugPrint('=== Dify API 返回数据: $outputs ===');

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成失败：未收到有效响应');
    }

    // 获取content字段
    final content = outputs['content'];

    try {
      // 解析JSON数据

      debugPrint('=== JSON解析成功 ===');

      // 获取roles数组
      final List<dynamic> charactersData = content['roles'] ?? [];
      debugPrint('=== 角色数组长度: ${charactersData.length} ===');
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
          debugPrint('解析角色数据失败: $e, 数据: $characterData');
          // 跳过无效的角色数据，继续处理其他角色
          continue;
        }
      }

      debugPrint('成功解析 ${characters.length} 个角色');
      return characters;

    } catch (e) {
      debugPrint('解析角色列表失败: $e, 原始数据: $content');
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

    debugPrint('=== 开始AI更新角色卡 ===');
    debugPrint('章节内容长度: ${chaptersContent.length} 字符');
    debugPrint('现有角色信息: $roles');
    debugPrint('小说背景: $backgroundSetting');
    debugPrint('作家设定: $aiWriterSetting');

    final outputs = await runWorkflowBlocking(inputs: inputs);

    debugPrint('=== Dify API 返回数据: $outputs ===');

    if (outputs == null || outputs.isEmpty) {
      throw Exception('角色更新失败：未收到有效响应');
    }

    // 获取content字段
    final content = outputs['content'];

    try {
      // 解析JSON数据
      debugPrint('=== JSON解析成功 ===');

      // 获取roles数组
      final List<dynamic> charactersData = content['roles'] ?? [];
      debugPrint('=== 更新后角色数组长度: ${charactersData.length} ===');
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
          debugPrint('成功解析角色: ${character.name}');
        } catch (e) {
          debugPrint('解析角色数据失败: $e, 数据: $characterData');
          // 跳过无效的角色数据，继续处理其他角色
          continue;
        }
      }

      debugPrint('成功更新 ${characters.length} 个角色');
      return characters;

    } catch (e) {
      debugPrint('解析更新角色列表失败: $e, 原始数据: $content');
      throw Exception('角色更新数据解析失败: $e');
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

    debugPrint('=== 开始AI生成角色卡提示词 ===');
    debugPrint('角色描述: $characterDescription');

    final outputs = await runWorkflowBlocking(inputs: inputs);

    debugPrint('=== Dify API 返回数据: $outputs ===');

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

      debugPrint('=== 面部提示词: $facePrompts ===');
      debugPrint('=== 身材提示词: $bodyPrompts ===');

      return {
        'face_prompts': facePrompts,
        'body_prompts': bodyPrompts,
      };

    } catch (e) {
      debugPrint('解析角色卡提示词失败: $e, 原始数据: $outputs');
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

    debugPrint('=== 格式化场景描写输入参数 ===');
    debugPrint('章节内容长度: ${chapterContent.length} 字符');
    debugPrint('角色数量: ${characters.length}');
    debugPrint('角色信息格式化结果:\n$rolesText');

    return inputs;
  }

  
  /// 场景描写流式生成
  Future<void> generateSceneDescriptionStream({
    required String chapterContent,
    required List<Character> characters,
    required Function(String) onChunk,        // 文本块回调
    required Function(String) onCompleted,    // 完成回调，传递完整内容
    required Function(String) onError,        // 错误回调
  }) async {
    // 格式化输入参数
    final inputs = _formatSceneDescriptionInput(
      chapterContent: chapterContent,
      characters: characters,
    );

    debugPrint('🚀 === 开始场景描写流式生成 ===');
    debugPrint('章节内容长度: ${chapterContent.length} 字符');
    debugPrint('角色数量: ${characters.length}');
    debugPrint('输入参数: ${jsonEncode(inputs)}');

    // 创建状态管理器
    late final StreamStateManager stateManager;
    stateManager = StreamStateManager(
      onTextChunk: onChunk,
      onCompleted: (String completeContent) {
        debugPrint('🎯 === 场景描写生成完成 ===');
        debugPrint('完整内容长度: ${completeContent.length}');
        debugPrint('完整内容预览: "${completeContent.substring(0, completeContent.length > 100 ? 100 : completeContent.length)}..."');

        // 在完成时将完整内容通过特殊标记传递，确保UI显示完整内容
        if (completeContent.isNotEmpty) {
          onChunk('<<COMPLETE_CONTENT>>$completeContent'); // 使用特殊标记标识完整内容
        }

        onCompleted(completeContent);
        stateManager.dispose();
      },
      onError: (error) {
        debugPrint('❌ === 场景描写生成错误 ===');
        debugPrint('错误: $error');
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

      debugPrint('🌐 === 场景描写 API 请求 ===');
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
            debugPrint('🔥 === 场景描写文本块 ===');
            debugPrint('内容: "$textChunk"');
            stateManager.handleTextChunk(textChunk);
            debugPrint('✅ 文本块处理完成');
          },
          onDone: () {
            debugPrint('📝 场景描写文本流结束');
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
            debugPrint('❌ 场景描写文本流错误: $error');
            textStreamError = true;
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        // 监听工作流完成事件
        DifySSEParser.waitForCompletion(eventStream).then((workflowCompleted) {
          debugPrint('✅ 场景描写工作流完成: $workflowCompleted');
          debugPrint('📊 完成时总字符数: ${stateManager.currentState.characterCount}');

          if (textStreamDone || completer.isCompleted) return;

          // 给文本流一些时间处理最后的数据
          Future.delayed(const Duration(milliseconds: 200), () {
            if (completer.isCompleted) return;
            completer.complete(workflowCompleted);
          });
        }).catchError((error) {
          debugPrint('❌ 场景描写工作流完成错误: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        });

        try {
          // 等待流处理完成
          final isCompleted = await completer.future.timeout(
            const Duration(minutes: 5), // 5分钟超时
            onTimeout: () {
              debugPrint('⏰ 场景描写流处理超时');
              return textStreamDone && !textStreamError;
            }
          );

          debugPrint('🎯 === 场景描写流处理结果 ===');
          debugPrint('完成状态: $isCompleted');
          debugPrint('最终字符数: ${stateManager.currentState.characterCount}');

          if (isCompleted) {
            stateManager.complete();
          } else {
            stateManager.handleError('场景描写流处理未正确完成');
          }
        } catch (e) {
          debugPrint('❌ === 场景描写流处理异常 ===');
          debugPrint('异常: $e');
          stateManager.handleError('场景描写流处理异常: $e');
        } finally {
          await textSubscription.cancel();
        }
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        debugPrint('❌ === 场景描写 API 错误 ===');
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

        stateManager.handleError('场景描写API请求失败 (${streamedResponse.statusCode}): $errorMessage');
      }
    } catch (e) {
      debugPrint('❌ === 场景描写生成异常 ===');
      debugPrint('异常: $e');
      stateManager.handleError('场景描写网络或解析异常: $e');
    }
  }
}
