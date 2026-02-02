import 'dart:convert';
import '../../models/character.dart';
import '../../models/character_relationship.dart';
import '../../models/ai_companion_response.dart';
import '../../services/logger_service.dart';
import 'dify_config_service.dart';
import 'dify_workflow_service.dart';
import 'dify_formatter.dart';

/// Dify创作服务
///
/// 负责处理创作相关的AI操作，包括：
/// - 生成沉浸体验剧本
/// - AI伴读分析
/// - 场景描写输入格式化
class DifyCreativeService {
  // ignore: unused_field
  final DifyConfigService _config;
  final DifyWorkflowService _workflow;

  DifyCreativeService({
    required DifyConfigService config,
    required DifyWorkflowService workflow,
  })  : _config = config,
        _workflow = workflow;

  /// 生成沉浸体验剧本
  ///
  /// [chapterContent] 章节内容
  /// [characters] 角色对象列表（包含完整角色信息）
  /// [userInput] 用户要求
  /// [userChoiceRole] 用户选择的角色名
  /// [existingPlay] 现有剧本（用于重新生成）
  /// [existingRoleStrategy] 现有角色策略（用于重新生成）
  Future<Map<String, dynamic>?> generateImmersiveScript({
    required String chapterContent,
    required List<Character> characters,
    required String userInput,
    required String userChoiceRole,
    String? existingPlay,
    List<Map<String, dynamic>>? existingRoleStrategy,
  }) async {
    // 使用 DifyFormatter 格式化角色信息
    final formattedRoles = DifyFormatter.formatCharacters(characters);

    final Map<String, dynamic> inputs = {
      'cmd': '生成剧本',
      'chapters_content': chapterContent,
      'roles': formattedRoles,
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

    _logImmersiveScriptRequest(
      chapterContent: chapterContent,
      characters: characters,
      formattedRoles: formattedRoles,
      userInput: userInput,
      userChoiceRole: userChoiceRole,
      existingPlay: existingPlay,
      existingRoleStrategy: existingRoleStrategy,
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

    return _parseImmersiveScriptOutput(outputs);
  }

  /// AI伴读分析
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
    final rolesJson = DifyFormatter.formatCharactersForAI(characters);

    // 格式化关系信息
    final relationsJson = DifyFormatter.formatRelationships(
      relationships,
      characters,
    );

    final inputs = {
      'cmd': 'AI伴读',
      'chapters_content': chaptersContent,
      'background_setting': backgroundSetting,
      'roles': rolesJson,
      'relations': relationsJson,
    };

    _logAICompanionRequest(
      chaptersContent: chaptersContent,
      backgroundSetting: backgroundSetting,
      characters: characters,
      relationships: relationships,
    );

    final outputs = await _workflow.executeBlocking(inputs: inputs);

    LoggerService.instance.i(
      '=== Dify API 返回数据: $outputs ===',
      category: LogCategory.ai,
      tags: ['info', 'dify'],
    );

    if (outputs == null || outputs.isEmpty) {
      throw Exception('AI伴读失败：未收到有效响应');
    }

    try {
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

  /// 格式化场景描写输入参数
  Map<String, dynamic> formatSceneDescriptionInput({
    required String chapterContent,
    required List<Character> characters,
  }) {
    // 使用 DifyFormatter 格式化角色信息
    final rolesText = DifyFormatter.formatCharacters(characters);

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

  /// 解析沉浸体验剧本输出
  Map<String, dynamic>? _parseImmersiveScriptOutput(
    Map<String, dynamic> outputs,
  ) {
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

  /// 记录沉浸体验剧本请求日志
  void _logImmersiveScriptRequest({
    required String chapterContent,
    required List<Character> characters,
    required String formattedRoles,
    required String userInput,
    required String userChoiceRole,
    String? existingPlay,
    List<Map<String, dynamic>>? existingRoleStrategy,
  }) {
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
  }

  /// 记录AI伴读请求日志
  void _logAICompanionRequest({
    required String chaptersContent,
    required String backgroundSetting,
    required List<Character> characters,
    required List<CharacterRelationship> relationships,
  }) {
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
  }
}
