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
    this.model = 'deepseek-v4-pro',
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
}