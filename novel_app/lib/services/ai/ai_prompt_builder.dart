/// AI Prompt 模板构建器
///
/// 集中管理所有 AI 调用的 system_prompt / user_message 模板。
/// 替代 creater.yml / structured_info.yml 中的 Jinja2 模板，
/// 模板文本从 yml 精确复制（CRLF→LF），用 `package:jinja` 渲染。
///
/// 设计原则：
/// - 模板与 yml 1:1 对应（可追溯）
/// - 渲染行为与原 TemplateRenderer 完全一致
/// - 业务参数名清晰，模板变量别名在内部 map
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

  // 1759151532593 "正常撰写" system — cmd='' 重写/新建 和 cmd='特写' 共用
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

  // 1759156810873 "特写" user — cmd='特写'
  // 变量: choice_content, user_input
  static const String _closeupUserTpl = '''现在我需要你修改以下内容
```
{{ choice_content }}
```
按照以下要求进行特写：
```
{{ user_input }}
```
只需要输出可以直接替换内容即可''';

  // 1762245807058 "总结模板" system — cmd='总结'
  // 变量: current_chapter_content
  static const String _summarySystemTpl = '''帮我总结缩写当前章节小说内容，不要用markdown 格式，不要遗漏任何情节

```当前章节小说内容：
{{current_chapter_content}}
```''';

  // 1762245728748 "总结" user — cmd='总结'
  static const String _summaryUserTpl = '''总结当前章节的内容''';

  // 1765793334024 "场景描写" system — cmd='场景描写'（无变量）
  static const String _sceneDescriptionSystemTpl = '''你是一个专业的文字摄影师。请根据用户提供的小说内容，生成一段纯粹、客观的画面描写。
你的任务是：用文字“拍摄”下小说中描述的一幕，只描写一个旁观者或主角主观视角下能直接看到的具体事物，不描写任何人物的内心感受、想法或抽象情绪以及不可见的内容。

**核心要求：**
1.  **视角固定**：选择一个视角（旁观者或主角），并贯穿始终。
2.  **纯粹描写**：只描写可见的**场景、人物、动作、物品、环境光照**等物理存在和可感知的细节。
3.  **物理关系**：清晰描述物品、人物与环境之间的空间位置关系（如：在...上、旁边、远处、悬挂着）。
4.  **感官细节**：侧重于视觉（形状、颜色、光影），不可以描述不可见的内容比如嗅觉，听觉。
5.  **平铺直叙**：语言风格平实、直接，像摄影机镜头一样记录。

**操作步骤：**
1.  仔细阅读用户提供的小说内容
2.  锁定当前小说描述的场景或瞬间，识别当前场景中出现的人物角色，如果有小说中出现详细的外貌描述，说明这个人物非常重要，需要重点描写，小说中越靠后的用户越重要。
3.  在脑海中构建这个画面，像布置摄影棚一样，厘清所有元素的物理位置。
4.  用文字依次或综合地描写：
    *   **场景**：事情发生的大环境（如：破旧的阁楼、喧闹的市集）。
    *   **人物**：画面中有谁，他们的衣着、体态、面部可见表情（仅肌肉动作，如皱眉、微笑）。
    *   **动作**：人物正在进行的可见动作（如：举起杯子、快步行走、手指敲击桌面）。
    *   **物品**：场景中关键的物品，它们的状态、新旧、摆放方式。
    *   **环境光照**：光线的来源（日光、烛火、霓虹灯）、强度、方向，以及产生的阴影、反光效果。
5.  将以上元素融合成一个连贯、生动、充满细节的纯文本段落。''';

  // 1765793427064 "场景描写-用户要求" user — cmd='场景描写'
  // 变量: current_chapter_content, roles
  static const String _sceneDescriptionUserTpl = '''以下是小说具体内容：
<小说内容>
{{ current_chapter_content }}
</小说内容>
如果场景中缺少了一些人物的细节信息，那么可以从下面的 人物信息 中寻找并补充上去，在描写的优先级上是以小说内容为准
<人物信息>
{{ roles }}
</人物信息>
''';

  // 1767087675935 "大纲生成" system — cmd='生成大纲'
  // 变量: outline, background_setting
  static const String _generateOutlineSystemTpl = '''

{% if outline %}
你的工作是按照用户的要求修改以下小说大纲,
<大纲>
{{ outline }}
</大纲>
{% else %}
你的工作是按照用户的要求生成一份小说大纲,大纲仅需要剧情设定，不需要进行人物设定。
不需要进行章节拆分，直接平铺直叙描写会发生什么事情，简略的快速描写剧情。
{% endif %}
{% if background_setting %}
<故事背景设定>
{{ background_setting }}
</故事背景设定>
{% endif %}
''';

  // 1767087711061 "大纲要求" user — cmd='生成大纲'
  // 变量: outline, user_input
  static const String _generateOutlineUserTpl = '''{% if outline %}
按照以下要求进行大纲修改：
{{ user_input }}
{% else %}
按照以下要求进行大纲创作：
{{ user_input }}
{% endif %}
''';

  // 1767089064485 "生成细纲" system — cmd='生成细纲'
  // 变量: outline_item, history_chapters_content, outline
  static const String _generateSubOutlineSystemTpl = '''你需要帮助用户基于大纲和之前的剧情，帮助用户完成细纲的创作

步骤：
1. 阅读大纲和最近小说的剧情，分析当前剧情发展到哪里
2. 结合用户的需求 ，确定当前章节的主要剧情内容
3. 分割出大纲中当前章节的部分
4. 结合用户需求，拓展这部分大纲，生成一份细纲内容

要求：
1. 纯文本内容，不要出现 markdown 等特殊符号标记

{% if outline_item %}
按照用户要求进行以下细纲的修改：

<细纲>
{{ outline_item }}
</细纲>
{% else %}
{% if history_chapters_content%}

<最近几章内容>
{{ history_chapters_content }}
</最近几章内容>
{% else %}
没有历史章节，需要生成第一章的细纲
{% endif %}

<大纲>
{{ outline }}
</大纲>
{% endif %}''';

  // 1767089068527 "细纲要求" user — cmd='生成细纲'
  // 变量: user_input, outline_item (但模板里用 outline 别名绑定)
  static const String _generateSubOutlineUserTpl = '''{% if user_input %}
{% if outline %}
按照以下要求进行细纲修改：
{{ user_input }}
{% else %}
按照以下要求进行细纲创作：
{{ user_input }}
{% endif %}
{% else %}
按照大纲和历史章节的进度生成新的一章的细纲。如果没有提供历史章节，那么就说明是第一章内容。
{% endif %}''';

  // 1767686318679 "聊天" system — cmd='聊天'
  // 变量: roles, scene, chat_history, choice_content
  // 三引号字符串会 strip 第一个换行，用 '\n' 显式保留
  static const String _chatSystemTpl = '\n'
      '## 任务说明\n'
      '\n'
      '你是一个专业的小说沉浸式体验AI助手，负责扮演多个角色与用户所扮演的角色进行实时互动。你需要根据剧本、角色策略和用户输入，生成符合角色设定的对话和旁白。\n'
      '\n'
      '## 输入信息\n'
      '\n'
      '```\n'
      '角色信息：\n'
      '{{ roles }}\n'
      '\n'
      '当前剧本：\n'
      '{{ scene }}\n'
      '\n'
      '历史对话：\n'
      '{{ chat_history }}\n'
      '\n'
      '用户扮演的角色：\n'
      '{{ choice_content }}\n'
      '```\n'
      '\n'
      '## 核心规则\n'
      '\n'
      '### 1. 输出格式要求\n'
      '\n'
      '**你必须严格遵循以下格式规则：**\n'
      '\n'
      '- **角色对话**：必须使用XML标签格式 `<角色名>对话内容</角色名>`\n'
      '- **旁白内容**：不使用任何标签包裹，直接输出纯文本\n'
      '- **禁止混用**：绝对不要在标签外写对话，也不要在标签内写旁白\n'
      '\n'
      '### 2. 格式示例\n'
      '\n'
      '```\n'
      '月光如水，营帐内烛火摇曳。\n'
      '\n'
      '<周维清>你可知罪？</周维清>\n'
      '\n'
      '营帐内一片死寂，只有烛火偶尔发出噼啪的声响。\n'
      '\n'
      '<上官冰儿>周维清，你这是什么意思？</上官冰儿>\n'
      '\n'
      '周维清冷笑一声，目光如刀。\n'
      '```\n'
      '\n'
      '### 3. 角色扮演要求\n'
      '\n'
      '- **严格遵循角色策略**：每个角色的性格、语言习惯、情感羁绊必须与角色策略一致\n'
      '- **保持角色独特性**：不同角色的说话方式、用词习惯、语气要有明显区别\n'
      '- **符合场景设定**：对话和旁白要符合当前剧本的氛围和情境\n'
      '- **自然流畅**：对话要有逻辑连贯性，旁白要生动细腻\n'
      '\n'
      '### 4. 旁白要求\n'
      '\n'
      '- **描写细节**：包含角色的形体动作、神态表情、环境氛围\n'
      '- **画面感强**：用具体的视觉、听觉、触觉等感官描写\n'
      '- **节奏把控**：旁白不宜过长，适时的旁白能增强对话的张力\n'
      '- **辅助对话**：旁白要为对话服务，帮助理解角色的情绪和动作\n'
      '\n'
      '### 5. 对话要求\n'
      '\n'
      '- **语言自然**：对话要符合角色的身份和文化背景\n'
      '- **情感真实**：角色要有喜怒哀乐，不要机械地说话\n'
      '- **互动性强**：角色之间要有互动，不要各自独白\n'
      '- **回应用户**：如果用户有输入，必须在对话或旁白中回应用户的行为或话语\n'
      '\n'
      '### 6. 历史记录处理\n'
      '\n'
      '- **保持连贯**：参考历史对话内容，确保剧情连贯不矛盾\n'
      '- **推动剧情**：根据历史记录合理推进剧情发展\n'
      '- **角色记忆**：记住之前发生的事件和对话内容\n'
      '\n'
      '## 特殊场景处理\n'
      '\n'
      '### 用户输入行为时\n'
      '\n'
      '如果用户输入了行为（如"打了他一巴掌"），必须在旁白中描述：\n'
      '- 行为的结果（是否打中、对方的反应）\n'
      '- 场景的变化\n'
      '- 其他角色的反应\n'
      '\n'
      '\n'
      '\n'
      '## 禁止事项\n'
      '\n'
      '1. **绝对禁止**在 `<>` 标签内写任何非对话内容（如旁白、动作描述）\n'
      '2. **绝对禁止**在标签外写角色对话\n'
      '3. **禁止OOC**（Out Of Character）：角色行为必须符合设定\n'
      '4. **禁止**破坏剧情连贯性\n'
      '5. **禁止**输出过多内容导致用户无法互动\n'
      '\n'
      '## 质量标准\n'
      '\n'
      '- ✅ 角色性格鲜明，符合策略设定\n'
      '- ✅ 对话自然流畅，符合角色身份\n'
      '- ✅ 旁白细腻生动，画面感强\n'
      '- ✅ 格式规范，严格遵循XML标签规则\n'
      '- ✅ 剧情连贯，与历史记录一致\n'
      '- ✅ 回应用户，互动性强\n';

  // 1767686331208 "用户输入" user — cmd='聊天'
  // 变量: arg1 (=user_input)
  static const String _chatUserTpl = '''{{ arg1 }}''';

  // 17695293591730 "总结设定" system — cmd='设定总结'
  // 变量名: current_chapter_content (但实际绑定 background_setting)
  static const String _settingSummarySystemTpl = '''帮我总结缩写小说背景设定内容，梳理成更好阅读的行文，不要遗漏重要设定，需要梳理的符合背景设定的格式，不重要内容可以忽略。
```当前小说设定：
{{current_chapter_content}}
```''';

  // 17695295483490 "总结 (1)" user — cmd='设定总结'
  static const String _settingSummaryUserTpl = '''总结当前小说背景设定''';

  // ── Jinja2 渲染辅助 ──

  /// 用 jinja 渲染模板。变量为 null/缺失时按空字符串处理。
  static String _render(String template, Map<String, Object?> vars) {
    return Template(template).render(vars);
  }

  // ── 9 个分支的 build 方法 ──

  /// 1. 全文重写（cmd='', currentChapterContent 非空） / 也用于新建（content 为空时）
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

  /// 2. 段落特写（cmd='特写'）
  static ({String system, String user}) closeup({
    required String aiWriterSetting,
    required String backgroundSetting,
    required String historyChaptersContent,
    required String currentChapterContent,
    required String roles,
    required String nextChapterOverview,
    required String userInput,
    required String choiceContent,
  }) {
    final vars = <String, Object?>{
      'setting': aiWriterSetting,
      'background': backgroundSetting,
      'history': historyChaptersContent,
      'content': currentChapterContent,
      'roles': roles,
      'next_preview': nextChapterOverview,
      'now_query': userInput,
      'choice_content': choiceContent,
      'user_input': userInput,
    };
    return (
      system: _render(_writingSystemTpl, vars),
      user: _render(_closeupUserTpl, vars),
    );
  }

  /// 3. 章节总结（cmd='总结'）
  static ({String system, String user}) summarize({
    required String currentChapterContent,
  }) {
    return (
      system: _render(
        _summarySystemTpl,
        {'current_chapter_content': currentChapterContent},
      ),
      user: _summaryUserTpl, // 无变量，直接用模板
    );
  }

  /// 4. 场景描写（cmd='场景描写'）
  static ({String system, String user}) sceneDescription({
    required String currentChapterContent,
    required String roles,
  }) {
    return (
      system: _sceneDescriptionSystemTpl, // 无变量
      user: _render(
        _sceneDescriptionUserTpl,
        {
          'current_chapter_content': currentChapterContent,
          'roles': roles,
        },
      ),
    );
  }

  /// 5. 生成大纲（cmd='生成大纲'）
  static ({String system, String user}) generateOutline({
    required String backgroundSetting,
    required String outline,
    required String userInput,
  }) {
    return (
      system: _render(
        _generateOutlineSystemTpl,
        {
          'outline': outline,
          'background_setting': backgroundSetting,
        },
      ),
      user: _render(
        _generateOutlineUserTpl,
        {
          'outline': outline,
          'user_input': userInput,
        },
      ),
    );
  }

  /// 6. 生成细纲（cmd='生成细纲'）
  static ({String system, String user}) generateSubOutline({
    required String historyChaptersContent,
    required String outline,
    required String outlineItem,
    required String userInput,
  }) {
    return (
      system: _render(
        _generateSubOutlineSystemTpl,
        {
          'history_chapters_content': historyChaptersContent,
          'outline': outline,
          'outline_item': outlineItem,
        },
      ),
      user: _render(
        _generateSubOutlineUserTpl,
        {
          'user_input': userInput,
          // 模板里用 `outline` 别名（yml 的 "细纲要求" 节点把 outline_item 映射到 outline 变量）
          'outline': outlineItem,
        },
      ),
    );
  }

  /// 7. 聊天（cmd='聊天'）
  static ({String system, String user}) chat({
    required String roles,
    required String scene,
    required String chatHistory,
    required String userInput,
    required String choiceContent,
  }) {
    final sysVars = <String, Object?>{
      'roles': roles,
      'scene': scene,
      'chat_history': chatHistory,
      'choice_content': choiceContent,
    };
    return (
      system: _render(_chatSystemTpl, sysVars),
      user: _render(_chatUserTpl, {'arg1': userInput}),
    );
  }

  /// 8. 设定总结（cmd='设定总结'）
  static ({String system, String user}) settingSummary({
    required String backgroundSetting,
  }) {
    // yml 把 background_setting 绑定到 current_chapter_content 变量名
    return (
      system: _render(
        _settingSummarySystemTpl,
        {'current_chapter_content': backgroundSetting},
      ),
      user: _settingSummaryUserTpl,
    );
  }

  // ════════════════════════════════════════════════════════
  // structured_info.yml 分支（信息提取类，阻塞式）
  // ════════════════════════════════════════════════════════

  // 1765253186012 "生成角色" system — cmd='生成'（走 if-else true 分支）
  // 变量: background_setting
  static const String _genCharactersSystemTpl = '''你是热门网络小说家
现在你的任务是根据用户要求设计角色

{% if background_setting %}
以下是小说的基本设定
<小说故事背景>
{{ background_setting }}
</小说故事背景>
{% endif %}''';

  // 1765266099735 "从文章中提取" system — cmd='update_characters'（走 if-else false 分支）/ 也是 cmd='生成' 和 '大纲生成角色' 的 system 聚合成员之一
  // 变量: chapters_content, roles
  static const String _extractFromArticleSystemTpl = '''根据以下文章内容，提取文章中出现的角色信息，如果角色已经在角色列表中，那么就需要判断是否需要更新，如果需要更新，那么就输出修改后的信息，除非出现设定冲突，否则保留原始设定。

如果没有要修改的内容，那么就不需要输出这个角色信息。

<小说内容>
{{ chapters_content }}
</小说内容>

<已有角色>
{{ roles }}
</已有角色>''';

  // 1767591248220 "大纲生成角色" system — cmd='大纲生成角色'
  // 变量: outline
  static const String _genCharactersFromOutlineSystemTpl = '''根据以下大纲内容，提取其中涉及到的角色，并适当的补充没有提到的合理的细节信息

<大纲>
{{ outline }}
</大纲>''';

  // 1765256215751 "要求" user — cmd='生成' / '大纲生成角色'
  // 变量: user_input
  static const String _genCharactersUserTpl = '''按照以下要求进行角色设计

{{ user_input }}''';

  // 1765350627730 "默认要求" user — cmd='update_characters'（false 分支）
  static const String _updateCharactersUserTpl = '生成章节中提到的角色信息列表吧';

  // 1768896895365 "提取某个角色" system — cmd='提取角色'（独立 LLM，单 role system）
  // 变量: roles, chapters_content
  static const String _extractCharacterSystemTpl = '''把以下章节内容中的角色相关信息提取出来。在提取人物角色的时候，经历上不用太细致，但是人物的外貌，性格特点需要详细的提取。

以下角色名是同一个人：
{{ roles }}

<章节内容>
{{ chapters_content }}
</章节内容>''';

  // 1765445210538 "提示词转换" system — cmd='角色卡提示词描写'（独立 LLM，单 role system）
  // 变量: roles
  static const String _characterPromptsSystemTpl = '''根据以下人物外貌设定，帮我把相应的文生图提示词写以下，需要是英文的提示词


{{ roles }}''';

  // 1769320891074 "AI伴读" system — cmd='AI伴读'（独立 LLM）
  // 变量: background_setting, roles, relations, chapters_content
  static const String _aiCompanionSystemTpl = '''需要你从最新章节内容中，提取出对于背景设定中需要更新的内容，以及人物设定如果发生了变更，那么就顺便进行人物设定的更新。
背景设定只需要输出新增的设定，如果没有新增设定，那么就不需要输出。背景设定是世界观设定中比较重要的元素，不要牵涉到具体的剧情因素。
如果人物信息没有发生变更，那么也不需要输出相应的人物卡。如果发生了变更，那么就需要结合旧的人物信息生成一个全新的人物信息，这个人物信息将会覆盖旧的，尽量不要丢失旧的信息。对于人物的经历，非决定性影响人物命运性格的不要写。如果人物经历字数太多，帮我简写掉
人物关系在发生变更情况下进行更新，如果没变更则不需要输出关系，如果旧的关系并没有消失比如 本来是未婚妻关系，现在仇人，那么关系类型上就写 【未婚妻/仇人】，除非关系消失，比如解除婚约之类的情况。



<背景设定>
{{ background_setting }}
</背景设定>

<roles>
{{ roles }}
</roles>

<人物关系>
{{ relations }}
</人物关系>

<最新章节>
{{ chapters_content }}
</最新章节>''';

  // 1767678678901 "生成剧本" system — cmd='生成剧本'
  // 变量: play, role_strategy, chapters_content, roles
  static const String _immersiveScriptSystemTpl =
      '你是一位顶尖的沉浸式戏剧编剧和动态叙事设计师。你擅长将静态的小说文字转化为具有高度参与感的互动剧本，能够精准捕捉人物的情感内核和语言风格。\n'
      '{% if play %}\n'
      'TASK: 请在保留原有剧本框架的基础上，根据用户需求进行深度优化\n'
      '\n'
      '<原始剧本>\n'
      '{{ play }}\n'
      '</原始剧本>\n'
      '\n'
      '<原始策略>\n'
      '{{ role_strategy }}\n'
      '</原始策略>\n'
      '\n'
      '{% else %}\n'
      'Task: 请基于我提供的"小说章节"和"初始角色信息"，构建一个多维度的互动剧本，并为后期 AI 接管角色提供深度逻辑支撑。\n'
      'Output Requirements:\n'
      '1. 世界观与情境重塑（Atmosphere & Setting）\n'
      '情境基调： 基于小说内容，提炼出当前的氛围（如：哀伤、热烈、压抑、江湖气等）。\n'
      '叙事视角： 描述玩家（用户）进入这一章故事时的切入点，TA 的出现如何扰动原本的剧情。\n'
      '2. 深度角色图谱（Character Blueprints）\n'
      '针对每一个提供的角色，生成以下非模板化的内容：\n'
      '性格底色： 用 一些关键词定义其性格（如：外冷内热、极度自卑、权力至上）。\n'
      '情感羁绊： 该角色与其他角色（包括玩家）之间的复杂关系（是救赎、背叛、仰慕还是利用？）。\n'
      '核心夙愿： 在本章节的特定情境下，该角色最想达成的事情是什么？\n'
      '语言习惯（接管关键）： 描述其措辞习惯（是否有口头禅？语气是谦卑、高傲还是充满讽刺？喜欢用短句还是长难句？）。\n'
      '反应机制： 当玩家表现出某种态度（如：示好、挑衅、求助）时，该角色的典型反应逻辑。\n'
      '即兴演播指南： 角色在互动中如何通过神态描述、动作细节（而不只是对白）来增强沉浸感。\n'
      '\n'
      '<小说素材>\n'
      '{{ chapters_content }}\n'
      '</小说素材>\n'
      '\n'
      '<参与角色>\n'
      '{{ roles }}\n'
      '</参与角色>\n'
      '\n'
      '{% endif %}';

  // 1767678678901 "生成剧本" user — cmd='生成剧本'
  // 变量: play, user_input, user_choice_role
  static const String _immersiveScriptUserTpl =
      '{% if play %}\n'
      '我需要你按照以下要求进行调整，保留剧本的主体和角色策略\n'
      '\n'
      '{{ user_input }}\n'
      '{% else %}\n'
      '我将扮演 ：{{ user_choice_role }}\n'
      '\n'
      '你创作的剧本需要满足 ：{{ user_input }}\n'
      '\n'
      '\n'
      '{% endif %}\n'
      '\n'
      '输出内容不要包含任何markdown符号，严格遵循json格式';

  /// 生成剧本的 structured output JSON Schema
  ///
  /// 与 yml 中 structured_output.schema 一致：
  /// - play: string (剧本)
  /// - role_strategy: array of {name, strategy, clothes}
  static const Map<String, dynamic> immersiveScriptResponseSchema = {
    'type': 'json_schema',
    'json_schema': {
      'name': 'immersive_script',
      'strict': true,
      'schema': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'play': {
            'type': 'string',
            'description': '剧本',
          },
          'role_strategy': {
            'type': 'array',
            'description': '角色策略',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'name': {
                  'type': 'string',
                  'description': '角色名',
                },
                'strategy': {
                  'type': 'string',
                  'description': '策略内容',
                },
                'clothes': {
                  'type': 'string',
                  'description': '这个角色，在当前场景服装，和设定卡中的服装可能不一致',
                },
              },
              'required': ['name', 'strategy', 'clothes'],
            },
          },
        },
        'required': ['play', 'role_strategy'],
      },
    },
  };

  // 1780652201290 "标签提取" system — cmd='提取标签'（独立 LLM）
  // 变量: tag_categories
  static const String _extractTagsSystemTpl = '''按照用户要求，提取文章中的写作技巧。
对于每个写作技巧，给出一个对应的标签（简洁的关键词）
为每个标签写出相应的写作技巧提示词，提示词要紧扣标签，具体且可操作，不要出现与标签无关的内容，也不要出现常见宽泛的要求，需要有明确的细节指导，要言之有物。

标签类型可以使用现有类型，如果现有类型不满足，可以自定义类型

现有类型：
{{ tag_categories }}

''';

  // 1780652201290 "标签提取" user — cmd='提取标签'
  // 变量: user_input, current_chapter_content
  static const String _extractTagsUserTpl = '''<要求>
{{ user_input }}
</要求>

<文章内容>
{{ current_chapter_content }}
</文章内容>
''';

  /// 生成角色（cmd='生成'）
  static ({String system, String user}) generateCharacters({
    required String backgroundSetting,
    required String userInput,
  }) {
    return (
      system: _render(
        _genCharactersSystemTpl,
        {'background_setting': backgroundSetting},
      ),
      user: _render(_genCharactersUserTpl, {'user_input': userInput}),
    );
  }

  /// 从大纲生成角色（cmd='大纲生成角色'）
  static ({String system, String user}) generateCharactersFromOutline({
    required String outline,
    required String userInput,
  }) {
    return (
      system: _render(
        _genCharactersFromOutlineSystemTpl,
        {'outline': outline},
      ),
      user: _render(_genCharactersUserTpl, {'user_input': userInput}),
    );
  }

  /// 更新角色卡（cmd='update_characters'，走 if-else false 分支）
  static ({String system, String user}) updateCharacterCards({
    required String chaptersContent,
    required String roles,
  }) {
    return (
      system: _render(
        _extractFromArticleSystemTpl,
        {'chapters_content': chaptersContent, 'roles': roles},
      ),
      user: _updateCharactersUserTpl,
    );
  }

  /// 提取角色（cmd='提取角色'）
  static ({String system, String user}) extractCharacter({
    required String chaptersContent,
    required String roles,
  }) {
    return (
      system: _render(
        _extractCharacterSystemTpl,
        {'chapters_content': chaptersContent, 'roles': roles},
      ),
      user: '', // 此 LLM 节点无 user message
    );
  }

  /// 生成角色卡提示词（cmd='角色卡提示词描写'）
  static ({String system, String user}) generateCharacterPrompts({
    required String roles,
  }) {
    return (
      system: _render(_characterPromptsSystemTpl, {'roles': roles}),
      user: '', // 此 LLM 节点无 user message
    );
  }

  /// AI 伴读（cmd='AI伴读'）
  static ({String system, String user}) aiCompanion({
    required String backgroundSetting,
    required String roles,
    required String relations,
    required String chaptersContent,
  }) {
    return (
      system: _render(
        _aiCompanionSystemTpl,
        {
          'background_setting': backgroundSetting,
          'roles': roles,
          'relations': relations,
          'chapters_content': chaptersContent,
        },
      ),
      user: '开始整理吧',
    );
  }

  /// 提取写作技巧标签（cmd='提取标签'）
  static ({String system, String user}) extractPromptTags({
    required String userInput,
    required String currentChapterContent,
    required String tagCategories,
  }) {
    return (
      system: _render(_extractTagsSystemTpl, {'tag_categories': tagCategories}),
      user: _render(
        _extractTagsUserTpl,
        {
          'user_input': userInput,
          'current_chapter_content': currentChapterContent,
        },
      ),
    );
  }

  /// 生成沉浸式剧本（cmd='生成剧本'）
  ///
  /// [chaptersContent] 小说章节内容
  /// [roles] 格式化后的角色信息
  /// [userInput] 用户要求
  /// [userChoiceRole] 用户选择扮演的角色名
  /// [existingPlay] 已有剧本（重新生成时传入）
  /// [existingRoleStrategy] 已有角色策略 JSON 字符串（重新生成时传入）
  static ({String system, String user}) immersiveScript({
    required String chaptersContent,
    required String roles,
    required String userInput,
    required String userChoiceRole,
    String existingPlay = '',
    String existingRoleStrategy = '',
  }) {
    return (
      system: _render(
        _immersiveScriptSystemTpl,
        {
          'play': existingPlay,
          'role_strategy': existingRoleStrategy,
          'chapters_content': chaptersContent,
          'roles': roles,
        },
      ),
      user: _render(
        _immersiveScriptUserTpl,
        {
          'play': existingPlay,
          'user_input': userInput,
          'user_choice_role': userChoiceRole,
        },
      ),
    );
  }
}
