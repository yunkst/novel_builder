/// 写作 Service
///
/// 强类型 Dart 方法，替代 creater.yml 的 9 个 cmd 分支。
/// 每个方法对应一个 UI 写作功能，UI 和 Agent 共用同一方法。
///
/// 设计原则：
/// - prompt 组装委托给 AiPromptBuilder（单一职责）
/// - LLM 调用委托给 LlmProvider（已存在）
/// - 默认参数（model=deepseek-v4-pro, max_tokens=8192, temperature=0.7）来自 AiModelParams
library;

import '../dsl_engine/llm_provider.dart';
import 'ai_prompt_builder.dart';

class WritingService {
  final LlmProvider _provider;
  final String? _defaultModel;
  final AiModelParams _params;

  WritingService({
    required LlmProvider provider,
    String? defaultModel,
    AiModelParams? params,
  })  : _provider = provider,
        _defaultModel = defaultModel,
        _params = params ?? const AiModelParams();

  // ── 9 个流式写作方法 ──

  /// 全文重写（cmd='', currentChapterContent 非空）
  Stream<String> fullRewrite({
    required String aiWriterSetting,
    required String backgroundSetting,
    required String historyChaptersContent,
    required String currentChapterContent,
    required String roles,
    required String nextChapterOverview,
    required String userInput,
  }) {
    final prompt = AiPromptBuilder.fullRewrite(
      aiWriterSetting: aiWriterSetting,
      backgroundSetting: backgroundSetting,
      historyChaptersContent: historyChaptersContent,
      currentChapterContent: currentChapterContent,
      roles: roles,
      nextChapterOverview: nextChapterOverview,
      userInput: userInput,
    );
    return _stream(prompt);
  }

  /// 新建章节（cmd='', currentChapterContent 为空）
  /// 实际与 fullRewrite 共用同模板，差异只在 currentChapterContent 为空
  Stream<String> createChapter({
    required String aiWriterSetting,
    required String backgroundSetting,
    required String historyChaptersContent,
    required String roles,
    required String nextChapterOverview,
    required String userInput,
  }) =>
      fullRewrite(
        aiWriterSetting: aiWriterSetting,
        backgroundSetting: backgroundSetting,
        historyChaptersContent: historyChaptersContent,
        currentChapterContent: '',
        roles: roles,
        nextChapterOverview: nextChapterOverview,
        userInput: userInput,
      );

  /// 段落特写（cmd='特写'）
  Stream<String> closeup({
    required String aiWriterSetting,
    required String backgroundSetting,
    required String historyChaptersContent,
    required String currentChapterContent,
    required String roles,
    required String nextChapterOverview,
    required String userInput,
    required String choiceContent,
  }) {
    final prompt = AiPromptBuilder.closeup(
      aiWriterSetting: aiWriterSetting,
      backgroundSetting: backgroundSetting,
      historyChaptersContent: historyChaptersContent,
      currentChapterContent: currentChapterContent,
      roles: roles,
      nextChapterOverview: nextChapterOverview,
      userInput: userInput,
      choiceContent: choiceContent,
    );
    return _stream(prompt);
  }

  /// 章节总结（cmd='总结'）
  Stream<String> summarize({required String currentChapterContent}) {
    final prompt = AiPromptBuilder.summarize(
      currentChapterContent: currentChapterContent,
    );
    return _stream(prompt);
  }

  /// 场景描写（cmd='场景描写'）
  Stream<String> sceneDescription({
    required String currentChapterContent,
    required String roles,
  }) {
    final prompt = AiPromptBuilder.sceneDescription(
      currentChapterContent: currentChapterContent,
      roles: roles,
    );
    return _stream(prompt);
  }

  /// 生成大纲（cmd='生成大纲'）
  Stream<String> generateOutline({
    required String backgroundSetting,
    required String outline,
    required String userInput,
  }) {
    final prompt = AiPromptBuilder.generateOutline(
      backgroundSetting: backgroundSetting,
      outline: outline,
      userInput: userInput,
    );
    return _stream(prompt);
  }

  /// 生成细纲（cmd='生成细纲'）
  Stream<String> generateSubOutline({
    required String historyChaptersContent,
    required String outline,
    required String outlineItem,
    required String userInput,
  }) {
    final prompt = AiPromptBuilder.generateSubOutline(
      historyChaptersContent: historyChaptersContent,
      outline: outline,
      outlineItem: outlineItem,
      userInput: userInput,
    );
    return _stream(prompt);
  }

  /// 角色聊天（cmd='聊天'）
  Stream<String> chat({
    required String roles,
    required String scene,
    required String chatHistory,
    required String userInput,
    required String choiceContent,
  }) {
    final prompt = AiPromptBuilder.chat(
      roles: roles,
      scene: scene,
      chatHistory: chatHistory,
      userInput: userInput,
      choiceContent: choiceContent,
    );
    return _stream(prompt);
  }

  /// 背景设定总结（cmd='设定总结'）
  Stream<String> settingSummary({required String backgroundSetting}) {
    final prompt = AiPromptBuilder.settingSummary(
      backgroundSetting: backgroundSetting,
    );
    return _stream(prompt);
  }

  // ── 内部：统一流式调用 ──

  Stream<String> _stream(({String system, String user}) prompt) {
    return _provider.chatStream(
      messages: [
        ChatMessage(role: 'system', content: prompt.system),
        ChatMessage(role: 'user', content: prompt.user),
      ],
      model: _defaultModel ?? _params.model,
      maxTokens: _params.maxTokens,
      temperature: _params.temperature,
    );
  }
}
