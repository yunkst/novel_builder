/// AI Prompt 模板构建器
///
/// 集中管理新建章节的 system_prompt / user_message 模板。
library;

import 'package:jinja/jinja.dart';

/// AI 调用的模型参数（golden 测试确认的值）
class AiModelParams {
  final String model;
  final int maxTokens;
  final double temperature;

  const AiModelParams({
    this.model = '',
    this.maxTokens = 8192,
    this.temperature = 0.7,
  });
}

class AiPromptBuilder {
  AiPromptBuilder._();

  // ── 静态模板（从 creater.yml 精确复制，CRLF→LF）──

  // 1759151532593 "正常撰写" system — cmd='' 重写/新建
  // 变量: setting, background, history, content, roles, next_preview
  static const String _writingSystemTpl = '''```你的设定：
{{ setting }}

在编写内容的时候，不要出现  markdown 或者 xml 标记，就是纯文本内容，在你输出的内容的最后，不要写什么伏笔或者总结，直接突兀结束就可以。
```
{% if background %}
```故事设定：
{{ background }}
```
{% endif %}
{% if history %}
```前几章内容
{{ history }}
```
{% endif %}

{% if content %}
```当前章节内容
{{ content }}
```
{% endif %}
{% if roles %}
```
以下是出场人物设定：
{{ roles }}
```
{% endif %}
{% if next_preview %}
```下一章剧情梗概，以下内容是提示你当前章节之后会发生的事情，你现在写的这章剧情不要包含这部分内容，也就是说，你的输出中不要出现这里的剧情和情节
{{ next_preview }}
```
{% endif %}''';

  // 1759156843442 "用户要求" user — cmd='' 重写/新建
  // 变量: now_query (=user_input), content (=current_chapter_content)
  static const String _writingUserTpl = '''{% if content %}
 按照我的要求进行调整，除非要求你进行删除或修改，否则你不要删减小说内容：
 {{ now_query }}
{% else %}
  按照我的要求，创建这一章小说内容，你需要结合前文续写。
  {{ now_query }}
{% endif %}''';

  // ── Jinja2 渲染辅助 ──

  /// 用 jinja 渲染模板。变量为 null/缺失时按空字符串处理。
  static String _render(String template, Map<String, Object?> vars) {
    return Template(template).render(vars);
  }

  // ── 新建章节 build 方法 ──

  /// 新建章节（cmd='', currentChapterContent 为空）
  static ({String system, String user}) fullRewrite({
    required String aiWriterSetting,
    required String backgroundSetting,
    required String historyChaptersContent,
    required String currentChapterContent,
    required String roles,
    required String nextChapterOverview,
    required String userInput,
  }) {
    final vars = <String, Object?>{
      'setting': aiWriterSetting,
      'background': backgroundSetting,
      'history': historyChaptersContent,
      'content': currentChapterContent,
      'roles': roles,
      'next_preview': nextChapterOverview,
      'now_query': userInput,
    };
    return (
      system: _render(_writingSystemTpl, vars),
      user: _render(_writingUserTpl, vars),
    );
  }

  // ── 生成细纲模板 ──

  // cmd='生成细纲' system — 基于大纲和前文生成章节细纲
  // 变量: history, outline, outline_item
  static const String _subOutlineSystemTpl = '''你需要帮助用户基于大纲和之前的剧情，帮助用户完成细纲的创作

步骤：
1. 阅读大纲和最近小说的剧情，分析当前剧情发展到哪里
2. 结合用户的需求 ，确定当前章节的主要剧情内容
3. 分割出大纲中当前章节的部分
4. 结合用户需求，拓展这部分大纲，生成一份细纲内容

要求：
1. 纯文本内容，不要出现 markdown 等特殊符号标记

{% if history %}
前几章内容：
{{ history }}
{% else %}
没有历史章节，需要生成第一章的细纲
{% endif %}

{% if outline %}
<大纲>
{{ outline }}
</大纲>
{% endif %}

{% if outline_item %}
<已有细纲>
{{ outline_item }}
</已有细纲>
{% endif %}''';

  // cmd='生成细纲' user
  // 变量: user_input
  static const String _subOutlineUserTpl = '''

按照以下要求进行细纲创作：
{{ user_input }}
''';

  /// 生成章节细纲（cmd='生成细纲'）
  static ({String system, String user}) subOutlineDraft({
    required String historyChaptersContent,
    required String outline,
    required String outlineItem,
    required String userInput,
  }) {
    final vars = <String, Object?>{
      'history': historyChaptersContent,
      'outline': outline,
      'outline_item': outlineItem,
      'user_input': userInput,
    };
    return (
      system: _render(_subOutlineSystemTpl, vars),
      user: _render(_subOutlineUserTpl, vars),
    );
  }
}