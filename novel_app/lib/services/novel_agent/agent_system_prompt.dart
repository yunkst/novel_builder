/// Agent System Prompt 构建器
///
/// Phase 2: 根据阅读上下文构建 Agent 的 system prompt
library;

import '../../core/providers/reading_context_providers.dart';

class AgentSystemPrompt {
  AgentSystemPrompt._();

  /// 构建 Agent 的 system prompt
  ///
  /// [readingContext] 当前阅读上下文（小说名、章节名、URL）
  /// [novelUrl] 可选：覆盖 readingContext 中的 novelUrl
  /// [memories] 经验记忆列表（每个场景各自维护）
  static String build({
    required ReadingContext readingContext,
    String? novelUrl,
    List<String> memories = const [],
  }) {
    final effectiveNovelUrl = novelUrl ?? readingContext.novelUrl;
    final buffer = StringBuffer();

    buffer.writeln('你是 Novel Builder 的小说写作助手 Agent。');
    buffer.writeln('你可以读取、修改、创建章节内容、角色信息、背景设定和大纲。');
    buffer.writeln();

    // 注入当前上下文
    if (readingContext.hasContext) {
      buffer.writeln('## 当前阅读上下文');
      buffer.writeln('- 小说: ${readingContext.novelTitle}');
      if (effectiveNovelUrl != null) {
        buffer.writeln('- 小说URL: $effectiveNovelUrl');
      }
      if (readingContext.chapterTitle != null) {
        buffer.writeln('- 当前章节: ${readingContext.chapterTitle}');
      }
      buffer.writeln();
    }

    buffer.writeln('## 工作原则');
    buffer.writeln('1. 先查后改：操作前先调用 list/list_chapters 获取 ID');
    buffer.writeln('2. 使用工具返回的数字 ID（novelId/chapterId），不是 URL');
    buffer.writeln('3. 修改操作完成后向用户汇报');
    buffer.writeln();

    // 注入经验记忆
    if (memories.isNotEmpty) {
      buffer.writeln('## 经验记忆');
      buffer.writeln('以下是你在以往对话中记录的重要经验，请优先参考：');
      for (final m in memories) {
        buffer.writeln('- $m');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}