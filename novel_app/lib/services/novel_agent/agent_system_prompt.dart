/// Agent System Prompt 构建器
///
/// 上下文驱动设计：AI 通过 select_novel 选定目标小说，
/// 后续工具隐式作用于该小说，章节操作使用 position（1-based 顺序号）。
library;

import '../../core/providers/reading_context_providers.dart';

class AgentSystemPrompt {
  AgentSystemPrompt._();

  /// 构建 Agent 的 system prompt
  ///
  /// [readingContext] 当前阅读上下文（小说名、章节名）
  /// [memories] 经验记忆列表（每个场景各自维护）
  static String build({
    required ReadingContext readingContext,
    List<String> memories = const [],
  }) {
    final buffer = StringBuffer();

    buffer.writeln('你是 Novel Builder 的小说写作助手 Agent。');
    buffer.writeln('你可以读取、修改、创建章节内容、角色信息、背景设定和大纲。');
    buffer.writeln();

    // 注入当前阅读上下文（仅供参考，不影响工具操作目标）
    if (readingContext.hasContext) {
      buffer.writeln('## 用户阅读上下文');
      buffer.writeln('用户当前正在阅读：${readingContext.novelTitle}');
      if (readingContext.chapterTitle != null) {
        buffer.writeln('章节：${readingContext.chapterTitle}');
      }
      buffer.writeln('（此信息仅供参考，工具操作目标由 select_novel 决定）');
      buffer.writeln();
    }

    buffer.writeln('## 工作原则');
    buffer.writeln('1. 选定目标：首次对话时，调用 list_novels 查看书架，'
        '然后用 select_novel 选定目标小说。切换小说时也要用 select_novel。');
    buffer.writeln('2. 先查后改：操作章节前先调用 list_chapters 查看章节列表，'
        '用 read_chapter_content 读取当前内容，确认后再修改。');
    buffer.writeln('3. 使用 position：章节操作使用 list_chapters 返回的 position '
        '（1-based 顺序号），不是 URL 或数据库 ID。');
    buffer.writeln('4. 创建新小说：用户要求"新建一本小说"时，直接调用 create_novel '
        '（只需 title，可选 description），系统会自动切换为当前工作小说。');
    buffer.writeln('5. 修改操作完成后向用户汇报。');
    buffer.writeln();

    // 注入经验记忆（编号 [N] 形式，供 patch_memory 工具用编号定位）
    if (memories.isNotEmpty) {
      buffer.writeln('## 经验记忆');
      buffer.writeln('以下是你在以往对话中记录的重要经验，请优先参考：');
      for (var i = 0; i < memories.length; i++) {
        buffer.writeln('[${i + 1}] ${memories[i]}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
