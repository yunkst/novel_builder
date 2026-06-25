/// 信息提取 Service
///
/// 强类型 Dart 方法，替代 structured_info.yml 的阻塞式分支。
/// 每个方法对应一个信息提取功能（角色生成、伴读、标签提取等）。
///
/// 设计原则同 WritingService：prompt 组装委托 AiPromptBuilder，LLM 调用委托 LlmProvider。
/// 注：structured_info.yml 用的是 `deepseek-v4-flash`，与 creater.yml 的 `deepseek-v4-pro` 不同。
library;

import 'dart:convert';

import '../dsl_engine/llm_provider.dart';
import 'ai_prompt_builder.dart';
import '../../utils/json_utils.dart';

class InfoExtractionService {
  final LlmProvider _provider;
  final String? _defaultModel;
  final int _maxTokens;

  InfoExtractionService({
    required LlmProvider provider,
    String? defaultModel,
    int maxTokens = 8192,
  })  : _provider = provider,
        _defaultModel = defaultModel,
        _maxTokens = maxTokens;

  // ── 7 个纯文本信息提取方法（返回 LLM 原始文本） ──

  /// 生成角色（cmd='生成'）
  Future<String> generateCharacters({
    required String backgroundSetting,
    required String userInput,
  }) {
    final prompt = AiPromptBuilder.generateCharacters(
      backgroundSetting: backgroundSetting,
      userInput: userInput,
    );
    return _blocking(prompt);
  }

  /// 从大纲生成角色（cmd='大纲生成角色'）
  Future<String> generateCharactersFromOutline({
    required String outline,
    required String userInput,
  }) {
    final prompt = AiPromptBuilder.generateCharactersFromOutline(
      outline: outline,
      userInput: userInput,
    );
    return _blocking(prompt);
  }

  /// 更新角色卡（cmd='update_characters'）
  Future<String> updateCharacterCards({
    required String chaptersContent,
    required String roles,
  }) {
    final prompt = AiPromptBuilder.updateCharacterCards(
      chaptersContent: chaptersContent,
      roles: roles,
    );
    return _blocking(prompt);
  }

  /// 提取角色（cmd='提取角色'）
  Future<String> extractCharacter({
    required String chaptersContent,
    required String roles,
  }) {
    final prompt = AiPromptBuilder.extractCharacter(
      chaptersContent: chaptersContent,
      roles: roles,
    );
    return _blocking(prompt);
  }

  /// 生成角色卡提示词（cmd='角色卡提示词描写'）
  Future<String> generateCharacterPrompts({
    required String roles,
  }) {
    final prompt = AiPromptBuilder.generateCharacterPrompts(roles: roles);
    return _blocking(prompt);
  }

  /// AI 伴读（cmd='AI伴读'）
  Future<String> aiCompanion({
    required String backgroundSetting,
    required String roles,
    required String relations,
    required String chaptersContent,
  }) {
    final prompt = AiPromptBuilder.aiCompanion(
      backgroundSetting: backgroundSetting,
      roles: roles,
      relations: relations,
      chaptersContent: chaptersContent,
    );
    return _blocking(prompt);
  }

  /// 提取写作技巧标签（cmd='提取标签'）
  Future<String> extractPromptTags({
    required String userInput,
    required String currentChapterContent,
    required String tagCategories,
  }) {
    final prompt = AiPromptBuilder.extractPromptTags(
      userInput: userInput,
      currentChapterContent: currentChapterContent,
      tagCategories: tagCategories,
    );
    return _blocking(prompt);
  }

  // ── 3 个结构化输出方法（返回解析后的 Map） ──

  /// 生成沉浸式剧本（cmd='生成剧本'）
  ///
  /// 带 structured output（JSON Schema），确保 LLM 返回
  /// `{play: string, role_strategy: [{name, strategy, clothes}]}` 格式。
  ///
  /// [existingRoleStrategy] 已有角色策略，传 List<Map> 时会自动 JSON encode。
  Future<Map<String, dynamic>> immersiveScript({
    required String chaptersContent,
    required String roles,
    required String userInput,
    required String userChoiceRole,
    String existingPlay = '',
    Object? existingRoleStrategy,
  }) {
    final prompt = AiPromptBuilder.immersiveScript(
      chaptersContent: chaptersContent,
      roles: roles,
      userInput: userInput,
      userChoiceRole: userChoiceRole,
      existingPlay: existingPlay,
      existingRoleStrategy: existingRoleStrategy is String
          ? existingRoleStrategy
          : existingRoleStrategy != null
              ? jsonEncode(existingRoleStrategy)
              : '',
    );
    return _blockingStructured(
      prompt,
      responseFormat: AiPromptBuilder.immersiveScriptResponseSchema,
    );
  }

  /// 标签自省（cmd='标签自省'）
  ///
  /// 分析用户修改意见，诊断 tag 体系问题（reason_adjust / prompt_clarify / missing_tag）
  Future<Map<String, dynamic>> tagIntrospection({
    required String usedTags,
    required String generatedContent,
    required String userFeedback,
  }) {
    final prompt = AiPromptBuilder.tagIntrospection(
      usedTags: usedTags,
      generatedContent: generatedContent,
      userFeedback: userFeedback,
    );
    return _blockingStructured(
      prompt,
      responseFormat: AiPromptBuilder.tagIntrospectionResponseSchema,
    );
  }

  /// 标签匹配（cmd='标签匹配'）
  ///
  /// 根据当前创作场景，从可用标签中筛选出适合本次使用的标签
  Future<Map<String, dynamic>> tagMatch({
    required String sceneDescription,
    required String availableTags,
  }) {
    final prompt = AiPromptBuilder.tagMatch(
      sceneDescription: sceneDescription,
      availableTags: availableTags,
    );
    return _blockingStructured(
      prompt,
      responseFormat: AiPromptBuilder.tagMatchResponseSchema,
    );
  }

  // ── 内部调用方法 ──

  /// 将 prompt record 转为 ChatMessage 列表
  List<ChatMessage> _buildMessages(({String system, String user}) prompt) {
    return [
      if (prompt.system.isNotEmpty)
        ChatMessage(role: 'system', content: prompt.system),
      if (prompt.user.isNotEmpty)
        ChatMessage(role: 'user', content: prompt.user),
    ];
  }

  /// 纯文本阻塞调用（无 structured output）
  Future<String> _blocking(({String system, String user}) prompt) {
    return _provider.chatRaw(
      messages: _buildMessages(prompt),
      model: _defaultModel,
      maxTokens: _maxTokens,
    );
  }

  /// 带 response_format 的结构化阻塞调用
  ///
  /// 使用 `_provider.chat()` 拿到完整 `LlmResponse`，
  /// 对 `content` 调用 [safeJsonDecode] 解码为 `Map<String, dynamic>`。
  ///
  /// [responseFormat] 传入 OpenAI 兼容的 response_format 字段，
  /// 用于强制 LLM 返回 JSON Schema 约束的结构化输出。
  Future<Map<String, dynamic>> _blockingStructured(
    ({String system, String user}) prompt, {
    required Map<String, dynamic> responseFormat,
  }) async {
    final response = await _provider.chat(
      messages: _buildMessages(prompt),
      model: _defaultModel,
      maxTokens: _maxTokens,
      responseFormat: responseFormat,
    );

    if (response.content.isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = safeJsonDecode(response.content);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    // structured output 模式下 LLM 应返回 JSON object，否则是 schema 约束失败
    throw FormatException(
      '结构化输出期望 JSON object，实际类型: ${decoded.runtimeType}',
    );
  }
}
