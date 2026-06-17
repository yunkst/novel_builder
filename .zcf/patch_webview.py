#!/usr/bin/env python3
# Apply agent memory evolution changes to webview_extract_scenario.dart

import sys

target = sys.argv[1] if len(sys.argv) > 1 else 'webview_extract_scenario.dart'

with open(target, 'r', encoding='utf-8') as f:
    content = f.read()

print("Original length:", len(content))

# 1) Add patchMemoryToolDefinition to the tools list
old_tools = '''  List<Map<String, dynamic>> get tools => [
        _getPageInfoTool,
        _executeJsTool,
        _navigateToTool,
        _getCurrentUrlTool,
        _getCachedScriptTool,
        _saveScriptTool,
        _listCachedScriptsTool,
        _inspectScriptTool,
      ];'''
new_tools = '''  List<Map<String, dynamic>> get tools => [
        _getPageInfoTool,
        _executeJsTool,
        _navigateToTool,
        _getCurrentUrlTool,
        _getCachedScriptTool,
        _saveScriptTool,
        _listCachedScriptsTool,
        _inspectScriptTool,
        patchMemoryToolDefinition,
      ];

  /// 记忆缓存（每次构建 prompt 时复用，避免重复 IO）
  List<String> _cachedMemories = const [];

  @override
  Future<List<String>> getMemories() async {
    final repo = _ref.read(agentMemoryRepositoryProvider);
    _cachedMemories = await repo.getAllByScenario(id);
    return _cachedMemories;
  }

  @override
  Future<MemoryPatchResult> patchMemory(String? oldText, String newText) async {
    final repo = _ref.read(agentMemoryRepositoryProvider);
    final all = await repo.getAllWithId(id);
    final allContents = all.map((r) => r["content"] as String).toList();

    if (allContents.isEmpty) {
      await repo.addMemory(id, newText);
      _cachedMemories = [..._cachedMemories, newText];
      return MemoryPatchResult.ok("已添加（首次插入）");
    }

    if (oldText == null || oldText.isEmpty) {
      await repo.addMemory(id, newText);
      _cachedMemories = [..._cachedMemories, newText];
      return MemoryPatchResult.ok("新记忆已添加");
    }

    if (newText.isEmpty) {
      final hit1 = all.firstWhere((r) => r["content"] == oldText, orElse: () => <String, dynamic>{});
      if (hit1.isEmpty) {
        return MemoryPatchResult.error("未找到要删除的记忆", allContents);
      }
      await repo.deleteMemory(hit1["id"] as int);
      _cachedMemories = List<String>.from(_cachedMemories)..remove(oldText);
      return MemoryPatchResult.ok("记忆已删除");
    }

    final hit2 = all.firstWhere((r) => r["content"] == oldText, orElse: () => <String, dynamic>{});
    if (hit2.isEmpty) {
      return MemoryPatchResult.error("未找到匹配的记忆内容。现有记忆：", allContents);
    }
    await repo.updateMemory(hit2["id"] as int, newText);
    final idx = _cachedMemories.indexOf(oldText);
    if (idx >= 0) {
      _cachedMemories = List<String>.from(_cachedMemories)..[idx] = newText;
    }
    return MemoryPatchResult.ok("记忆已更新");
  }'''

if old_tools not in content:
    print("ERROR: old_tools not found!")
    sys.exit(1)
content = content.replace(old_tools, new_tools)
print("Step 1 done")

# 2) Add patch_memory interception in executeTool
old_execute = "    // Headless 模式：仅 WebView 类工具（get_page_info / execute_js / navigate_to）\n    // 需要确保 Headless WebView 加载了 _currentUrl。"
new_execute = "    // patch_memory 由场景自行处理\n    if (name == 'patch_memory') {\n      return await _executePatchMemory(args);\n    }\n\n    // Headless 模式：仅 WebView 类工具（get_page_info / execute_js / navigate_to）\n    // 需要确保 Headless WebView 加载了 _currentUrl。"

if old_execute not in content:
    print("ERROR: old_execute not found!")
    sys.exit(1)
content = content.replace(old_execute, new_execute)
print("Step 2 done")

# 3) Replace buildSystemPrompt method
prompt_start_marker = "  @override\n  String buildSystemPrompt(AgentScenarioContext context) {\n    final url = context.currentUrl ?? _currentUrl;\n    return '''\n## 当前页面"
prompt_start = content.find(prompt_start_marker)
if prompt_start == -1:
    print("ERROR: buildSystemPrompt start not found!")
    sys.exit(1)
prompt_end_marker = "''';\n  }"
prompt_end = content.find(prompt_end_marker, prompt_start)
if prompt_end == -1:
    print("ERROR: buildSystemPrompt end not found!")
    sys.exit(1)
prompt_end += len(prompt_end_marker)

new_prompt = "  @override\n  String buildSystemPrompt(AgentScenarioContext context) {\n    final url = context.currentUrl ?? _currentUrl;\n    final buf = StringBuffer();\n\n    buf.writeln('## 当前页面');\n    buf.writeln('URL: \$url');\n    buf.writeln();\n\n    buf.writeln('## 工作目标');\n    buf.writeln('为当前小说网站编写可复用的 JS 提取脚本，经 execute_js 验证后 save_script 保存到本地数据库。');\n    buf.writeln('核心产出：目录提取（chapter_list_js）+ 内容提取（chapter_content_js），两段都必须测试通过。');\n    buf.writeln();\n\n    buf.writeln('## 工作流程');\n    buf.writeln('1. get_page_info → 获取 DOM 结构和页面类型');\n    buf.writeln('2. get_cached_script → 有缓存则 execute_js(run_id=...) 重跑验证，无则新生成');\n    buf.writeln('3. execute_js(script=...) 测试脚本，获取 __meta.run_id');\n    buf.writeln('4. save_script(domain, list_run_id, content_run_id) 零重传保存 → 完成');\n    buf.writeln();\n\n    buf.writeln('## run_id 机制');\n    buf.writeln('- 不要在上下文保留完整脚本 → 用 run_id 句柄引用');\n    buf.writeln('- 重跑: execute_js(run_id=<id>) → 保存: save_script(domain, list_run_id=<id>, content_run_id=<id>)');\n    buf.writeln();\n\n    buf.writeln('## JS 脚本规范');\n    buf.writeln('- 脚本是 async IIFE: (async function() { ... return JSON.stringify(result); })()');\n    buf.writeln('- 首行必须声明 const PAGE_URL = \'{{URL}}\';，禁止 window.location.href');\n    buf.writeln('- 目录返回: { \"title\": \"...\", \"chapters\": [{ \"title\": \"...\", \"url\": \"...\" }] }');\n    buf.writeln('- 内容返回: { \"title\": \"...\", \"content\": \"...\" }');\n    buf.writeln('- 翻页: 检测下一页 → 点击 → await new Promise(r => setTimeout(r, 1000)) → 继续');\n    buf.writeln('- 只使用标准 DOM API（querySelector, innerText），不依赖 jQuery/Vue/React');\n    buf.writeln('- 跳过广告段落（含本章未完、一秒记住等）');\n    buf.writeln();\n\n    buf.writeln('## 错误处理');\n    buf.writeln('- 工具返回 error 时 → 先读 suggestion 字段');\n    buf.writeln('- 错误码: JS_SYNTAX_ERROR/REFERENCE_ERROR/TYPE_ERROR/TIMEOUT/RUNTIME_ERROR → 按 suggestion 修');\n    buf.writeln('- SCRIPT_VALIDATION_FAILED → 检查 {{URL}} 占位符和 PAGE_URL');\n    buf.writeln('- 同一错误连续 3 次 → 换完全不同的选择器/思路');\n    buf.writeln();\n\n    if (_cachedMemories.isNotEmpty) {\n      buf.writeln('## 经验记忆');\n      buf.writeln('以下是以往对话中的经验记录，请优先参考：');\n      for (final m in _cachedMemories) {\n        buf.writeln('- \$m');\n      }\n      buf.writeln();\n    }\n\n    return buf.toString();\n  }"

content = content[:prompt_start] + new_prompt + content[prompt_end:]
print("Step 3 done")

# 4) Add _executePatchMemory at end of class
last_brace = content.rfind("}")
new_method = "\n  /// 执行 patch_memory 工具，序列化 MemoryPatchResult\n  Future<String> _executePatchMemory(Map<String, dynamic> args) async {\n    final oldText = args['oldText'] as String? ?? args['old_text'] as String?;\n    final newText = args['newText'] as String? ?? args['new_text'] as String? ?? '';\n    final result = await patchMemory(oldText, newText);\n    if (result.success) {\n      return jsonEncode({'success': true, 'message': result.message});\n    }\n    return jsonEncode({\n      'error': 'memory_not_found',\n      'message': result.message,\n      'allMemories': result.allMemories,\n    });\n  }\n}\n"
content = content[:last_brace] + new_method
print("Step 4 done")

with open(target, 'w', encoding='utf-8') as f:
    f.write(content)

print("Done. New length:", len(content))
