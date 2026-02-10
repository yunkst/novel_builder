import '../../models/character.dart';
import '../../services/logger_service.dart';
import 'dify_config_service.dart';
import 'dify_workflow_service.dart';

/// Dify角色服务
///
/// 负责处理与角色相关的AI生成操作，包括：
/// - 生成新角色
/// - 从大纲生成角色
/// - 更新角色卡
/// - 从章节提取角色
/// - 生成角色提示词
class DifyCharacterService {
  final DifyConfigService _config;
  final DifyWorkflowService _workflow;

  DifyCharacterService({
    required DifyConfigService config,
    required DifyWorkflowService workflow,
  })  : _config = config,
        _workflow = workflow;

  /// AI生成角色
  Future<List<Character>> generateCharacters({
    required String userInput,
    required String novelUrl,
    required String backgroundSetting,
  }) async {
    final aiWriterSetting = await _config.getAiWriterSetting();

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

    final outputs = await _workflow.executeBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成失败：未收到有效响应');
    }

    return _parseCharacterList(outputs, novelUrl);
  }

  /// 从大纲生成角色
  Future<List<Character>> generateCharactersFromOutline({
    required String outline,
    required String userInput,
    required String novelUrl,
  }) async {
    final aiWriterSetting = await _config.getAiWriterSetting();

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

    final outputs = await _workflow.executeBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成失败：未收到有效响应');
    }

    return _parseCharacterList(outputs, novelUrl);
  }

  /// 更新角色卡
  Future<List<Character>> updateCharacterCards({
    required String chaptersContent,
    required String roles,
    required String novelUrl,
    String backgroundSetting = '',
  }) async {
    final aiWriterSetting = await _config.getAiWriterSetting();

    final inputs = {
      'chapters_content': chaptersContent,
      'roles': roles,
      'cmd': 'update_characters',
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

    final outputs = await _workflow.executeBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('角色更新失败：未收到有效响应');
    }

    return _parseCharacterList(outputs, novelUrl);
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

    final outputs = await _workflow.executeBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('角色提取失败：未收到有效响应');
    }

    return _parseCharacterList(outputs, novelUrl);
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

    final outputs = await _workflow.executeBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI生成提示词失败：未收到有效响应');
    }

    try {
      final content = outputs['content'];

      if (content == null) {
        throw Exception('返回数据缺少content字段');
      }

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

  /// 解析角色列表
  List<Character> _parseCharacterList(
    Map<String, dynamic> outputs,
    String novelUrl,
  ) {
    final content = outputs['content'];

    try {
      LoggerService.instance.i(
        '=== JSON解析成功 ===',
        category: LogCategory.ai,
        tags: ['success', 'dify'],
      );

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
}
