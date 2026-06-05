import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../models/ai_companion_response.dart';
import 'dify_sse_parser.dart';
import 'stream_state_manager.dart';
import 'logger_service.dart';
import 'preferences_service.dart';
import 'dify/dify_config_service.dart';
import 'dify/dify_workflow_service.dart';
import 'dify/dify_character_service.dart';
import 'dify/dify_creative_service.dart';
import 'dify/dify_formatter.dart';

/// Dify AI服务 - 门面类
///
/// 此类作为统一入口，委托给各个专用服务：
/// - [DifyConfigService]: 配置管理
/// - [DifyWorkflowService]: 工作流调用
/// - [DifyCharacterService]: 角色相关操作
/// - [DifyCreativeService]: 创作相关操作
///
/// 推荐直接使用各专用服务以获得更好的类型安全和可测试性。
class DifyService {
  // 子服务实例
  final DifyConfigService _config;
  late final DifyWorkflowService _workflow;
  late final DifyCharacterService _character;
  late final DifyCreativeService _creative;

  /// 构造函数 - 支持依赖注入
  ///
  /// [config] 可选的配置服务实例，用于测试和依赖注入
  DifyService({DifyConfigService? config})
      : _config = config ?? DifyConfigService() {
    _workflow = DifyWorkflowService(config: _config);
    _character = DifyCharacterService(
      config: _config,
      workflow: _workflow,
    );
    _creative = DifyCreativeService(
      config: _config,
      workflow: _workflow,
    );
  }

  /// 获取配置服务（用于测试和高级用法）
  DifyConfigService get config => _config;

  /// 获取工作流服务（用于高级用法）
  DifyWorkflowService get workflow => _workflow;

  /// 获取角色服务（用于高级用法）
  DifyCharacterService get character => _character;

  /// 获取创作服务（用于高级用法）
  DifyCreativeService get creative => _creative;

  // ============================================================================
  // 配置管理方法（委托给 DifyConfigService）
  // ============================================================================

  /// 获取流式响应token
  Future<String> _getFlowToken() => _config.getFlowToken();

  /// 获取结构化响应token
  // ignore: unused_element
  Future<String> _getStructToken() => _config.getStructToken();

  // ============================================================================
  // 工作流方法（委托给 DifyWorkflowService）
  // ============================================================================

  /// 通用的流式工作流执行方法
  Future<void> runWorkflowStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) =>
      _workflow.executeStreaming(
        inputs: inputs,
        onData: onData,
        onError: onError,
        onDone: onDone,
        enableDebugLog: enableDebugLog,
      );

  /// 通用的阻塞式工作流执行方法
  Future<Map<String, dynamic>?> runWorkflowBlocking({
    required Map<String, dynamic> inputs,
  }) =>
      _workflow.executeBlocking(inputs: inputs);

  // ============================================================================
  // 角色相关方法（委托给 DifyCharacterService）
  // ============================================================================

  /// AI生成角色
  Future<List<Character>> generateCharacters({
    required String userInput,
    required String novelUrl,
    required String backgroundSetting,
  }) =>
      _character.generateCharacters(
        userInput: userInput,
        novelUrl: novelUrl,
        backgroundSetting: backgroundSetting,
      );

  /// 从大纲生成角色
  Future<List<Character>> generateCharactersFromOutline({
    required String outline,
    required String userInput,
    required String novelUrl,
  }) =>
      _character.generateCharactersFromOutline(
        outline: outline,
        userInput: userInput,
        novelUrl: novelUrl,
      );

  /// 更新角色卡
  Future<List<Character>> updateCharacterCards({
    required String chaptersContent,
    required String roles,
    required String novelUrl,
    String backgroundSetting = '',
  }) =>
      _character.updateCharacterCards(
        chaptersContent: chaptersContent,
        roles: roles,
        novelUrl: novelUrl,
        backgroundSetting: backgroundSetting,
      );

  /// 从章节内容提取角色
  Future<List<Character>> extractCharacter({
    required String chapterContent,
    required String roles,
    required String novelUrl,
  }) =>
      _character.extractCharacter(
        chapterContent: chapterContent,
        roles: roles,
        novelUrl: novelUrl,
      );

  /// 生成角色卡提示词
  Future<Map<String, String>> generateCharacterPrompts({
    required String characterDescription,
  }) =>
      _character.generateCharacterPrompts(
        characterDescription: characterDescription,
      );

  // ============================================================================
  // 创作相关方法（委托给 DifyCreativeService）
  // ============================================================================

  /// 生成沉浸体验剧本
  Future<Map<String, dynamic>?> generateImmersiveScript({
    required String chapterContent,
    required List<Character> characters,
    required String userInput,
    required String userChoiceRole,
    String? existingPlay,
    List<Map<String, dynamic>>? existingRoleStrategy,
  }) =>
      _creative.generateImmersiveScript(
        chapterContent: chapterContent,
        characters: characters,
        userInput: userInput,
        userChoiceRole: userChoiceRole,
        existingPlay: existingPlay,
        existingRoleStrategy: existingRoleStrategy,
      );

  /// AI伴读功能
  Future<AICompanionResponse?> generateAICompanion({
    required String chaptersContent,
    required String backgroundSetting,
    required List<Character> characters,
    required List<CharacterRelationship> relationships,
  }) =>
      _creative.generateAICompanion(
        chaptersContent: chaptersContent,
        backgroundSetting: backgroundSetting,
        characters: characters,
        relationships: relationships,
      );

  /// AI 提取写作技巧标签
  Future<List<ExtractedPromptTag>> extractPromptTags({
    required String userInput,
    required String chapterContent,
    required String tagCategories,
  }) =>
      _creative.extractPromptTags(
        userInput: userInput,
        chapterContent: chapterContent,
        tagCategories: tagCategories,
      );

  /// 格式化场景描写输入参数
  Map<String, dynamic> _formatSceneDescriptionInput({
    required String chapterContent,
    required List<Character> characters,
  }) =>
      _creative.formatSceneDescriptionInput(
        chapterContent: chapterContent,
        characters: characters,
      );

  // ============================================================================
  // 已弃用的方法（保留向后兼容）
  // ============================================================================

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
  ///   },
  ///   onData: (chunk) { ... },
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
    String? roles,
    required Function(String chunk) onChunk,
    Function()? onComplete,
  }) async {
    final difyUrl = await PreferencesService.instance.getString('dify_url');
    final difyToken = await _getFlowToken();
    final aiWriterSetting = await PreferencesService.instance
        .getString('ai_writer_prompt', defaultValue: '');

    if (difyUrl.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL');
    }

    // 创建状态管理器
    late final StreamStateManager stateManager;
    stateManager = StreamStateManager(
      onTextChunk: onChunk,
      onCompleted: (String completeContent) {
        LoggerService.instance.i(
          '✅ 特写生成完成: ${completeContent.length} 字符',
          category: LogCategory.ai,
          tags: ['success', 'dify'],
        );

        if (completeContent.isNotEmpty) {
          onChunk('<<COMPLETE_CONTENT>>$completeContent');
        }

        onComplete?.call();
        stateManager.dispose();
      },
      onError: (error) {
        LoggerService.instance.e(
          '❌ 特写生成错误: $error',
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

      final cmd =
          (requestBody['inputs'] as Map<String, dynamic>)['cmd'] as String?;
      LoggerService.instance.i(
        '🚀 Dify API请求: ${cmd ?? 'unknown'}',
        category: LogCategory.ai,
        tags: ['api', 'request', 'dify'],
      );

      final request = http.Request('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $difyToken',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        stateManager.startReceiving();

        final inputStream = streamedResponse.stream.transform(utf8.decoder);
        final eventStream = DifySSEParser.parseStream(inputStream);
        final textStream = DifySSEParser.extractTextStream(eventStream);

        final completer = Completer<bool>();
        bool textStreamDone = false;
        bool textStreamError = false;

        int chunkCount = 0;
        int totalChars = 0;

        final textSubscription = textStream.listen(
          (textChunk) {
            chunkCount++;
            totalChars += textChunk.length;

            if (chunkCount % 10 == 0) {
              LoggerService.instance.d(
                '📊 流式处理进度: $chunkCount chunks, $totalChars chars',
                category: LogCategory.ai,
                tags: ['stream', 'progress', 'dify'],
              );
            }

            stateManager.handleTextChunk(textChunk);
          },
          onDone: () {
            LoggerService.instance.i(
              '✅ AI生成完成: $chunkCount chunks, $totalChars chars',
              category: LogCategory.ai,
              tags: ['stream', 'complete', 'dify'],
            );
            textStreamDone = true;

            Future.delayed(const Duration(milliseconds: 100), () {
              if (completer.isCompleted) return;
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

          if (textStreamDone || completer.isCompleted) return;

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
          final isCompleted = await completer.future
              .timeout(const Duration(minutes: 10), onTimeout: () {
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
  ///     'current_chapter_content': '...',
  ///     'roles': '...',
  ///   },
  ///   onData: (chunk) { ... },
  /// );
  /// ```
  @Deprecated(
      'Use runWorkflowStreaming() instead. See documentation for migration guide.')
  Future<void> generateSceneDescriptionStream({
    required String chapterContent,
    required List<Character> characters,
    required Function(String) onChunk,
    required Function(String) onCompleted,
    required Function(String) onError,
  }) async {
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

        if (completeContent.isNotEmpty) {
          onChunk('<<COMPLETE_CONTENT>>$completeContent');
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

      final difyUrl = await PreferencesService.instance.getString('dify_url');
      final difyToken = await _getFlowToken();

      if (difyUrl.isEmpty) {
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

        final inputStream = streamedResponse.stream.transform(utf8.decoder);
        final eventStream = DifySSEParser.parseStream(inputStream);
        final textStream = DifySSEParser.extractTextStream(eventStream);

        final completer = Completer<bool>();
        bool textStreamDone = false;
        bool textStreamError = false;

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
          final isCompleted = await completer.future
              .timeout(const Duration(seconds: 15), onTimeout: () {
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

  // ============================================================================
  // 私有辅助方法（保持向后兼容）
  // ============================================================================

  /// 格式化角色信息为AI友好的JSON字符串
  // ignore: unused_element
  String _formatCharactersForAI(List<Character> characters) {
    return DifyFormatter.formatCharactersForAI(characters);
  }

  /// 格式化关系信息为AI友好的文本格式
  // ignore: unused_element
  String _formatRelationshipsForAI(
    List<CharacterRelationship> relationships,
    List<Character> characters,
  ) {
    return DifyFormatter.formatRelationships(relationships, characters);
  }
}
