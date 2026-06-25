/// 写作 Service
///
/// 新建章节（AI 全文生成），替代 creater.yml 中 cmd='' 的分支。
/// 设计原则：prompt 组装委托 AiPromptBuilder，LLM 调用委托 LlmProvider。
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

  /// 新建章节（cmd=''，currentChapterContent 为空）
  Stream<String> createChapter({
    required String aiWriterSetting,
    required String backgroundSetting,
    required String historyChaptersContent,
    required String roles,
    required String nextChapterOverview,
    required String userInput,
  }) {
    final prompt = AiPromptBuilder.fullRewrite(
      aiWriterSetting: aiWriterSetting,
      backgroundSetting: backgroundSetting,
      historyChaptersContent: historyChaptersContent,
      currentChapterContent: '',
      roles: roles,
      nextChapterOverview: nextChapterOverview,
      userInput: userInput,
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