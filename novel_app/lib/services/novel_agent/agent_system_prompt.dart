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
  static String build({
    required ReadingContext readingContext,
    String? novelUrl,
  }) {
    final effectiveNovelUrl = novelUrl ?? readingContext.novelUrl;
    final buffer = StringBuffer();

    buffer.writeln('你是 Novel Builder 的小说写作助手 Agent。');
    buffer.writeln('你拥有直接操作小说数据库的能力，可以读取、修改、创建章节内容、角色信息、背景设定和大纲。');
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
    buffer.writeln('1. 修改章节前，先调用 read_chapter_content 了解当前内容');
    buffer.writeln('2. 修改角色前，先调用 list_characters 确认角色是否存在');
    buffer.writeln('3. 涉及写作风格/内容的修改，直接使用你的语言能力完成，不需要额外调用 AI');
    buffer.writeln('4. 操作完成后，向用户汇报你做了什么');
    buffer.writeln('5. 如果用户要求不明确，先问清楚再操作');
    buffer.writeln('6. 修改操作会触发用户确认，请告知用户即将进行的修改');
    buffer.writeln();

    buffer.writeln('## 注意事项');
    buffer.writeln('- 章节内容以空行分隔段落');
    buffer.writeln('- 角色名区分大小写');
    buffer.writeln('- 修改小说元数据时请谨慎，确保内容完整');

    return buffer.toString();
  }
}