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

  // ── 8 个阻塞信息提取方法 ──

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

  /// 生成沉浸式剧本（cmd='生成剧本'）
  ///
  /// 带 structured output（JSON Schema），确保 LLM 返回
  /// `{play: string, role_strategy: [{name, strategy, clothes}]}` 格式。
  ///
  /// [existingRoleStrategy] 已有角色策略，传 List<Map> 时会自动 JSON encode。
  Future<String> immersiveScript({
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
    return _blockingWithSchema(
      prompt,
      responseFormat: AiPromptBuilder.immersiveScriptResponseSchema,
    );
  }

  // ── 内部：统一阻塞调用 ──

  Future<String> _blocking(({String system, String user}) prompt) async {
    return _blockingWithSchema(prompt, responseFormat: null);
  }

  /// 带 response_format 的阻塞调用（structured output）
  ///
  /// [responseFormat] 非 null 时传入 OpenAI 兼容的 response_format 字段，
  /// 用于强制 LLM 返回 JSON Schema 约束的结构化输出（如生成剧本）。
  Future<String> _blockingWithSchema(
    ({String system, String user}) prompt, {
    required Map<String, dynamic>? responseFormat,
  }) async {
    final messages = <ChatMessage>[];
    if (prompt.system.isNotEmpty) {
      messages.add(ChatMessage(role: 'system', content: prompt.system));
    }
    if (prompt.user.isNotEmpty) {
      messages.add(ChatMessage(role: 'user', content: prompt.user));
    }
    final response = await _provider.chatRaw(
      messages: messages,
      model: _defaultModel,
      maxTokens: _maxTokens,
      responseFormat: responseFormat,
    );
    return response;
  }
}
