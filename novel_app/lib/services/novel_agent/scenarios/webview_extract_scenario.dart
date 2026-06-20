/// WebView 网页小说提取场景
///
/// 在用户浏览小说网站时，通过 ReAct 循环生成 JS 脚本
/// 提取小说目录和章节内容。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/core/providers/extraction_task_providers.dart';
import 'package:novel_app/core/providers/webview_add_novel_providers.dart';
import 'package:novel_app/core/providers/webview_providers.dart';
import 'package:novel_app/services/logger_service.dart';

import '../agent_scenario.dart';
import 'run_store.dart';
import 'webview_js_executor.dart';

class WebViewExtractScenario with AgentScenarioCleanupMixin
    implements AgentScenario {
  final Ref _ref;
  final InAppWebViewController _webviewController;
  final String _currentUrl;

  /// 是否为 Headless 模式
  ///
  /// Headless 模式下使用 `HeadlessInAppWebView`（后台无 UI），
  /// 不受可见 WebView 页面生命周期影响。
  /// 普通模式下使用可见 `InAppWebView`（向后兼容）。
  final bool _isHeadless;

  /// Headless 模式下，是否已把 _currentUrl 同步到 Headless WebView
  ///
  /// Headless WebView 是全局单例池，复用同一实例。
  /// 上次执行可能停留在任意页面（about:blank / 上次的章节 URL），
  /// 必须在第一次执行 WebView 类工具前显式 loadUrl + 等待 onLoadStop。
  bool _headlessPageSynced = false;

  /// 需要 Headless WebView 已就绪的工具（其余 3 个是纯数据库工具）
  static const _webviewRequiredTools = {
    'get_page_info',
    'execute_js',
    'navigate_to',
    'get_current_url',
  };

  /// 脚本执行记录内存存储（句柄机制）
  ///
  /// 每次 execute_js 成功执行后，脚本自动登记到此处并返回 run_id；
  /// save_script 通过 run_id 引用已验证脚本（零重传）；
  /// get_cached_script 从数据库加载的脚本也登记到此处，
  /// 后续 execute_js 通过 run_id 重跑（零重抄）。
  final RunStore _runStore = RunStore();

  /// 自上次 onNoToolCalls 检查以来，是否产生过工具调用
  ///
  /// 状态机核心：注入提示的前提是 agent "行动过"（产生过 tool_call）。
  /// - true（调过工具）→ 结束时检查脚本是否存在，无脚本则注入并复位
  /// - false（首次空响应 / 注入后仍无行动）→ 不注入，结束
  /// executeTool 开头置 true，onNoToolCalls 注入后复位为 false。
  bool _hadToolCallSinceLastCheck = false;

  /// 本次会话是否已成功保存脚本（save_script 成功时置 true）
  bool _scriptSavedThisSession = false;

  /// 普通 WebView 模式构造函数（向后兼容）
  WebViewExtractScenario(this._ref, this._webviewController, this._currentUrl)
    : _isHeadless = false;

  /// Headless 模式工厂构造函数
  ///
  /// 注意：Headless 模式下，_currentUrl 与 WebView 实际页面**不同步**。
  /// 第一次执行工具时会通过 [_ensureHeadlessPageLoaded] 显式同步。
  WebViewExtractScenario.headless(
    this._ref,
    this._webviewController,
    this._currentUrl,
  ) : _isHeadless = true;

  @override
  String get id => ScenarioIds.webviewExtract;

  @override
  String get displayName => '网页小说提取';

  @override
  String buildSystemPrompt(AgentScenarioContext context) {
    final url = context.currentUrl ?? _currentUrl;
    final buf = StringBuffer();

    buf.writeln('## 当前页面');
    buf.writeln('URL: ' + url);
    buf.writeln();

    buf.writeln('## 工作目标');
    buf.writeln('为当前小说网站编写可复用的 JS 提取脚本，经 execute_js 验证后 save_script 保存到本地数据库。');
    buf.writeln('核心产出：目录提取（chapter_list_js）+ 内容提取（chapter_content_js），两段都必须测试通过。');
    buf.writeln();

    buf.writeln('## 工作流程');
    buf.writeln('1. get_page_info → 获取 DOM 结构和页面类型');
    buf.writeln('2. get_cached_script → 有缓存则 execute_js(run_id=...) 重跑验证，无则新生成');
    buf.writeln('3. execute_js(script=...) 测试脚本，获取 __meta.run_id');
    buf.writeln('4. save_script(domain, list_run_id, content_run_id) 零重传保存 → 完成');
    buf.writeln();

    buf.writeln('## run_id 机制');
    buf.writeln('- 不要在上下文保留完整脚本 → 用 run_id 句柄引用');
    buf.writeln('- 重跑: execute_js(run_id=<id>) → 保存: save_script(domain, list_run_id=<id>, content_run_id=<id>)');
    buf.writeln();

    buf.writeln('## JS 脚本规范');
    buf.writeln('- 脚本是 async IIFE: (async function() { ... return JSON.stringify(result); })()');
    buf.writeln('- 首行必须声明 `const PAGE_URL = \'{{URL}}\';`，禁止 window.location.href');
    buf.writeln('- 目录返回: { "title": "...", "chapters": [{ "title": "...", "url": "..." }] }');
    buf.writeln('- 内容返回: { "title": "...", "content": "..." }');
    buf.writeln('- 翻页: 检测下一页 → 点击 → await new Promise(r => setTimeout(r, 1000)) → 继续');
    buf.writeln('- 只使用标准 DOM API（querySelector, innerText），不依赖 jQuery/Vue/React');
    buf.writeln('- 跳过广告段落（含本章未完、一秒记住等）');
    buf.writeln();

    buf.writeln('## 错误处理');
    buf.writeln('- 工具返回 error 时 → 先读 suggestion 字段');
    buf.writeln('- 错误码: JS_SYNTAX_ERROR/REFERENCE_ERROR/TYPE_ERROR/TIMEOUT/RUNTIME_ERROR → 按 suggestion 修');
    buf.writeln('- SCRIPT_VALIDATION_FAILED → 检查 {{URL}} 占位符和 PAGE_URL');
    buf.writeln('- 同一错误连续 3 次 → 换完全不同的选择器/思路');
    buf.writeln();

    buf.writeln('## 脚本实际使用日志');
    buf.writeln('脚本在对话中 execute_js 跑通，不代表真实使用也能成功。用 get_script_logs 查看实际运行日志：');
    buf.writeln('- get_script_logs(domain) → 查看脚本在阅读器/预加载等真实场景的运行日志');
    buf.writeln('- 适用：execute_js 通过但用户反馈抓取失败（内容为空、超时、页面结构变化）');
    buf.writeln('- 日志来源：阅读器获取章节内容、FAB 添加小说、预加载等非对话场景');
    buf.writeln('- 默认返回 warning 及以上级别（只看问题），填 level=info 可看成功记录');
    buf.writeln();

    if (_cachedMemories.isNotEmpty) {
      buf.writeln('## 经验记忆');
      buf.writeln('以下是以往对话中的经验记录，请优先参考：');
      for (final m in _cachedMemories) {
        buf.writeln('- ' + m);
      }
      buf.writeln();
    }

    return buf.toString();
  }

  /// 无 tool_call 注入钩子：Agent 即将"无工具调用结束"时调用
  ///
  /// 注入前提：自上次检查以来 agent 必须产生过 tool_call（即"行动过"）。
  /// 一个字段 `_hadToolCallSinceLastCheck` 统一表达所有终止条件：
  /// - 首次无 tool_call（从未调过工具）→ 标记为 false → 不注入，直接结束
  /// - agent 行动过 + 脚本已存在 → 正常结束
  /// - agent 行动过 + 脚本不存在 → 注入提示，复位标记为 false
  /// - 注入后再次结束：期间有新 tool_call → 标记为 true → 重新检查；无 → 结束
  @override
  Future<String?> onNoToolCalls(List<ChatMessage> messages) async {
    // 前提：agent 自上次检查以来必须"行动过"。
    // 首次空响应、或注入后仍无新行动，都落入此分支 → 不注入。
    if (!_hadToolCallSinceLastCheck) {
      return null;
    }

    // agent 行动过了，检查脚本是否真的存在（内存标志短路，否则查库）
    final hasScript = _scriptSavedThisSession || await _hasScriptInDb();
    if (hasScript) {
      return null; // 有脚本，正常结束
    }

    // 无脚本，注入提示；复位标记，等待下一轮是否有新行动
    _hadToolCallSinceLastCheck = false;

    LoggerService.instance.i(
      'WebViewExtract 注入提示: agent 已行动但未保存脚本 (url=$_currentUrl)',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'injection', 'hint'],
    );
    return '系统检测：本次会话中尚未保存任何提取脚本到数据库。\n'
        '请立即采取以下任一行动：\n'
        '1) 若 execute_js 已成功解析出目录/正文，调用 save_script 保存脚本；\n'
        '2) 若确实无法生成脚本，请说明具体原因（反爬、动态加载、需登录等）。';
  }

  /// 查询当前域名的 site_scripts 表是否有记录
  Future<bool> _hasScriptInDb() async {
    final domain = Uri.tryParse(_currentUrl)?.host ?? '';
    if (domain.isEmpty) return false;
    try {
      final db = await _ref.read(databaseConnectionProvider).database;
      final results = await db.query(
        'site_scripts',
        where: 'domain = ?',
        whereArgs: [domain],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (e) {
      LoggerService.instance.w(
        '查询 site_scripts 失败: $e',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'db_query_error'],
      );
      return false;
    }
  }

  @override
  List<Map<String, dynamic>> get tools => [
        _getPageInfoTool,
        _executeJsTool,
        _navigateToTool,
        _getCurrentUrlTool,
        _getCachedScriptTool,
        _saveScriptTool,
        _listCachedScriptsTool,
        _inspectScriptTool,
        _getScriptLogsTool,
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
  }

  @override
  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    // 任意工具调用都视为 agent 在"行动"，标记供 onNoToolCalls 状态机判断
    _hadToolCallSinceLastCheck = true;

    LoggerService.instance.d(
      'WebViewExtractScenario 执行工具: $name',
      category: LogCategory.ai,
      tags: ['agent', 'scenario', 'webview-extract', name],
    );

    // patch_memory 由场景自行处理
    if (name == 'patch_memory') {
      return await _executePatchMemory(args);
    }

    // Headless 模式：仅 WebView 类工具（get_page_info / execute_js / navigate_to）
    // 需要确保 Headless WebView 加载了 _currentUrl。
    // 数据库工具（get_cached_script / save_script / list_cached_scripts）不依赖 WebView。
    if (_isHeadless && _webviewRequiredTools.contains(name)) {
      final syncResult = await _ensureHeadlessPageLoaded();
      if (syncResult != null) {
        return syncResult;
      }
    }

    // 更新提取任务状态
    _updateTaskPhase(name);

    try {
      String result;
      switch (name) {
        case 'get_page_info':
          result = await _getPageInfo();
        case 'execute_js':
          result = await _executeJs(args);
        case 'navigate_to':
          result = await _navigateTo(args);
        case 'get_current_url':
          result = await _getCurrentUrl();
        case 'get_cached_script':
          result = await _getCachedScript(args);
        case 'save_script':
          result = await _saveScript(args);
        case 'list_cached_scripts':
          result = await _listCachedScripts();
        case 'inspect_script':
          result = await _inspectScript(args);
        case 'get_script_logs':
          result = await _getScriptLogs(args);
        default:
          result = jsonEncode({
            'error': 'unknown_tool',
            'message': '未知工具: $name',
          });
      }

      // 工具完成后更新状态
      _ref.read(extractionTaskNotifierProvider).toolEnd();

      return result;
    } catch (e, stackTrace) {
      _ref.read(extractionTaskNotifierProvider).toolEnd();

      LoggerService.instance.e(
        'WebViewExtractScenario 工具执行失败: $name, error=$e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['agent', 'scenario', 'webview-extract', name, 'error'],
      );
      return jsonEncode({
        'error': 'execution_failed',
        'message': e.toString(),
      });
    }
  }

  /// 根据工具名更新提取任务阶段
  void _updateTaskPhase(String toolName) {
    final notifier = _ref.read(extractionTaskNotifierProvider);
    notifier.toolStart(toolName);

    // 首次执行时，从 _currentUrl 提取域名并启动任务
    if (notifier.isIdle) {
      final domain = Uri.tryParse(_currentUrl)?.host ?? '';
      if (domain.isNotEmpty) {
        notifier.start(domain);
      }
    }

    switch (toolName) {
      case 'get_page_info':
      case 'navigate_to':
        notifier.setPhase(ExtractionPhase.analyzing, toolName: toolName);
      case 'execute_js':
        notifier.setPhase(ExtractionPhase.executing, toolName: toolName);
      case 'save_script':
        notifier.setPhase(ExtractionPhase.saving, toolName: toolName);
    }
  }

  // ===== 工具实现 =====

  /// 获取当前页面信息（URL + 精简 DOM + 页面类型推断）
  ///
  /// Headless 模式下使用 [_currentUrl] 作为页面 URL（Headless WebView
  /// 的 getUrl() 在某些平台上可能不准确或返回 about:blank）。
  Future<String> _getPageInfo() async {
    try {
      // Headless 模式使用 _currentUrl；普通模式从 WebView 获取实际 URL
      final String pageUrl;
      if (_isHeadless) {
        pageUrl = _currentUrl;
      } else {
        final url = await _webviewController.getUrl();
        pageUrl = url?.toString() ?? _currentUrl;
      }

      final domResult = await _webviewController.evaluateJavascript(
        source: _domSimplifyJs,
      );

      // 推断页面类型
      final pageTypeResult = await _webviewController.evaluateJavascript(
        source: _inferPageTypeJs,
      );
      String pageType = 'unknown';
      String? pageTitle;
      if (pageTypeResult != null && pageTypeResult is String) {
        try {
          final parsed = jsonDecode(pageTypeResult);
          pageType = parsed['pageType'] ?? 'unknown';
          pageTitle = parsed['title'] ?? '';
        } catch (_) {
          // 推断失败不影响主流程
        }
      }

      LoggerService.instance.i(
        '获取页面信息: $pageUrl (domLen=${(domResult ?? '').length}, pageType=$pageType, headless=$_isHeadless)',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'get_page_info'],
      );
      return jsonEncode({
        'url': pageUrl,
        'pageType': pageType,
        'title': pageTitle ?? '',
        'dom': domResult ?? '',
      });
    } catch (e) {
      LoggerService.instance.w(
        'get_page_info 失败: $e (pageUrl=$_currentUrl)',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'get_page_info', 'error'],
      );
      return jsonEncode({
        'error': 'PAGE_NOT_READY',
        'message': '页面尚未加载完成或 WebView 未初始化',
        'raw': e.toString(),
        'suggestion': '请等待几秒后重试 get_page_info',
      });
    }
  }

  /// 确保 Headless WebView 已加载 _currentUrl
  ///
  /// Headless WebView 是全局单例池，复用同一实例。
  /// 上次执行可能停留在任意页面，必须在第一次执行 WebView 工具前显式同步。
  ///
  /// 优化：先检查 WebView 当前 URL 是否就是 _currentUrl，避免无效 loadUrl。
  ///
  /// 返回 `null` 表示同步成功；返回 JSON 字符串表示同步失败（作为工具错误返回给 LLM）。
  Future<String?> _ensureHeadlessPageLoaded() async {
    if (_headlessPageSynced) return null;

    try {
      // 池复用：先检查 WebView 实际 URL，可能已经是 _currentUrl
      final currentUrl = await _webviewController.getUrl();
      if (currentUrl != null && currentUrl.toString() == _currentUrl) {
        await Future.delayed(_domStabilizeDelay);
        _headlessPageSynced = true;
        return null;
      }

      LoggerService.instance.i(
        'Headless 模式: 同步加载 _currentUrl → $_currentUrl',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'headless-sync'],
      );

      await _webviewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(_currentUrl)),
      );

      final loaded = await _waitForUrl(_currentUrl, timeout: _pageLoadTimeout);
      if (loaded) {
        _headlessPageSynced = true;
        return null;
      }

      // 超时：Headless WebView 的 getUrl() 在某些平台可能不更新，
      // 但 loadUrl 调用本身是成功的，信任它并继续
      LoggerService.instance.w(
        'Headless 模式: URL 同步超时，信任 loadUrl 调用并继续',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'headless-sync', 'timeout'],
      );
      await Future.delayed(_headlessTrustDelay);
      _headlessPageSynced = true;
      return null;
    } catch (e) {
      LoggerService.instance.e(
        'Headless 模式: URL 同步失败 $e',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'headless-sync', 'error'],
      );
      return jsonEncode({
        'error': 'PAGE_NOT_READY',
        'message': 'Headless WebView 加载目标页面失败: $e',
        'url': _currentUrl,
        'suggestion': '请稍后重试 get_page_info',
      });
    }
  }

  // ===== WebView 加载等待（统一 _ensureHeadlessPageLoaded 和 _navigateTo 的轮询逻辑）=====

  static const _pageLoadTimeout = Duration(seconds: 30);
  static const _pollInterval = Duration(milliseconds: 500);
  static const _domStabilizeDelay = Duration(milliseconds: 500);
  static const _headlessTrustDelay = Duration(seconds: 2);

  /// 等待 WebView 加载完成（URL 匹配 targetUrl）
  ///
  /// 返回 `true` 表示成功等到 URL 匹配；`false` 表示超时。
  /// [trustOnTimeout] 为 true 时，超时不再抛错（Headless WebView 在某些平台
  /// 的 getUrl() 不更新，但 loadUrl 本身成功）。
  Future<bool> _waitForUrl(
    String targetUrl, {
    Duration timeout = _pageLoadTimeout,
    bool trustOnTimeout = false,
  }) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      await Future.delayed(_pollInterval);
      try {
        final current = await _webviewController.getUrl();
        if (current != null && current.toString() == targetUrl) {
          await Future.delayed(_domStabilizeDelay);
          return true;
        }
      } catch (e) {
        // 轮询错误继续等待
        LoggerService.instance.d(
          '轮询 getUrl 失败: $e',
          category: LogCategory.ai,
          tags: ['agent', 'webview-extract', 'poll_url'],
        );
      }
    }
    return false;
  }

  /// 在 WebView 中执行 JS 脚本（使用 callAsyncJavaScript）
  ///
  /// ## 双模式
  ///
  /// ### run_id 模式（新，推荐）
  /// - 传 `run_id` 参数，从 RunStore 加载脚本执行
  /// - `test_url` 仍可选（覆盖脚本中 {{URL}}，未传则用 _currentUrl）
  /// - 用于「重跑已有脚本」，零重抄
  ///
  /// ### script 模式（旧，兼容）
  /// - 传 `script` 参数（带 {{URL}} 占位符的 async IIFE），直接执行
  /// - 执行成功后自动登记到 RunStore 返回 run_id
  /// - 用于「探测 DOM 结构」或「新写/修改提取脚本」
  ///
  /// 执行前会：
  /// 1. 若 run_id 模式：从 RunStore 读取完整脚本
  /// 2. 若 script 模式：校验脚本包含 `{{URL}}` 占位符（防呆）
  /// 3. 将 `{{URL}}` 替换为 `test_url` 或当前页面 URL
  /// 4. 通过 callAsyncJavaScript 执行替换后的脚本
  ///
  /// callAsyncJavaScript 相比 evaluateJavascript 的优势：
  /// - 支持 async/await（Promise 结果正确返回）
  /// - 支持 setTimeout 等异步操作（翻页等待）
  /// - 结构化返回值 CallAsyncJavaScriptResult{value, error}
  /// - JS 错误通过 error 字段返回，不再静默吞噬
  ///
  /// ## 返回值（结构统一）
  /// 无论执行成功/失败，返回值都包含 `run_id` 字段（成功时登记到 RunStore）；
  /// 成功时 script 字段返回前 200 字符（避免长脚本占上下文）。
  Future<String> _executeJs(Map<String, dynamic> args) async {
    // ── 解析参数（run_id 优先）──
    final runId = args['run_id'] as String?;
    final script = args['script'] as String?;

    if (runId == null && (script == null || script.isEmpty)) {
      return jsonEncode({
        'error': 'missing_param',
        'message': '需要 script 或 run_id 参数',
        'missing': ['script 或 run_id'],
        'suggestion': script != null && script.isEmpty
            ? 'script 参数为空字符串，请传入有效的 JS 代码，或使用 run_id 引用之前执行的脚本'
            : '请传入 script（探测/新写脚本）或 run_id（重跑已有脚本）',
      });
    }

    // ── 解析脚本来源 ──
    final String effectiveScript;

    if (runId != null) {
      // run_id 模式：从 RunStore 加载
      final entry = _runStore.get(runId);
      if (entry == null) {
        return jsonEncode({
          'error': 'RUN_ID_NOT_FOUND',
          'message': '未找到 $runId（可能已被淘汰或未注册）',
          'suggestion': 'RunStore 有容量限制（50 条 LRU 淘汰）。请重新执行 script 模式注册新 run_id',
        });
      }
      effectiveScript = entry.script;
    } else {
      // script 模式：校验 + 使用
      final validationError = WebViewJsExecutor.validateScript(script!);
      if (validationError != null) {
        LoggerService.instance.w(
          '脚本校验失败: $validationError',
          category: LogCategory.ai,
          tags: ['agent', 'webview-extract', 'execute_js', 'validation'],
        );
        return jsonEncode({
          'error': 'SCRIPT_VALIDATION_FAILED',
          'message': '脚本校验失败',
          'validation_error': validationError,
          'suggestion': validationError,
        });
      }
      effectiveScript = script;
    }

    // ── 参数注入：将 {{URL}} 替换为 test_url 或当前页面 URL ──
    final testUrl = (args['test_url'] as String?) ?? _currentUrl;
    final resolvedScript = effectiveScript.replaceAll('{{URL}}', testUrl);

    // ── 提取 IIFE 函数体 ──
    final functionBody = WebViewJsExecutor.extractAsyncFunctionBody(resolvedScript);

    final modeLabel = runId != null ? 'run_id=$runId' : 'script(len=${script?.length ?? 0})';
    LoggerService.instance.d(
      '执行 JS ($modeLabel): {{URL}} → $testUrl (resolvedLen=${resolvedScript.length})',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'execute_js', runId != null ? 'run_id' : 'script'],
    );

    try {
      final result = await _webviewController
          .callAsyncJavaScript(functionBody: functionBody)
          .timeout(const Duration(seconds: 60));

      // callAsyncJavaScript 返回 CallAsyncJavaScriptResult?
      if (result == null) {
        return jsonEncode({'result': null});
      }

      // JS Promise reject → 返回错误信息
      if (result.error != null) {
        final errorStr = result.error.toString();
        final errorInfo = _parseJsError(errorStr, effectiveScript);
        LoggerService.instance.w(
          'JS 执行错误: ${errorInfo.code} - ${errorInfo.message}',
          category: LogCategory.ai,
          tags: ['agent', 'webview-extract', 'execute_js', errorInfo.code],
        );
        return jsonEncode({
          'error': errorInfo.code,
          'message': errorInfo.message,
          'raw': errorStr,
          'suggestion': errorInfo.suggestion,
        });
      }

      // ── JS Promise resolve → 成功，登记到 RunStore ──
      // stringifyJsResult 总是返回 String（null → '{"result":null}'，对象 → jsonEncode）
      final resultStr = WebViewJsExecutor.stringifyJsResult(result.value);

      // 尝试解析为业务对象（Map），用于平铺到顶层（保持向后兼容）
      Map<String, dynamic>? businessFields;
      dynamic decoded;
      try {
        decoded = jsonDecode(resultStr);
        if (decoded is Map<String, dynamic>) {
          businessFields = decoded;
        }
      } catch (_) {
        // 非 JSON 字符串，无法平铺，原样放在 result 字段
        final preview = resultStr.length > 200
            ? '${resultStr.substring(0, 200)}...'
            : resultStr;
        LoggerService.instance.d(
          'JS 结果非 JSON: $preview',
          category: LogCategory.ai,
          tags: ['agent', 'webview-extract', 'execute_js', 'non_json'],
        );
      }

      // 结果摘要（截断 300 字符）用于 RunStore 记录
      final resultSummary = resultStr.toString().length > 300
          ? '${resultStr.toString().substring(0, 300)}...'
          : resultStr.toString();

      // 仅在 script 模式（新脚本）下登记；run_id 模式是重跑已有记录，不重复登记
      final String storedRunId;
      if (runId != null) {
        storedRunId = runId;
      } else {
        storedRunId = _runStore.put(
          script: effectiveScript,
          success: true,
          source: RunEntrySource.execution,
          testUrl: testUrl,
          resultSummary: resultSummary,
        );
      }

      LoggerService.instance.i(
        '执行 JS 成功: $storedRunId (mode=${runId != null ? "replay" : "register"}), resultLen=${resultStr.toString().length}',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'execute_js'],
      );

      // 返回值结构：业务字段平铺到顶层（向后兼容）+ __meta 元数据
      //
      // - 业务字段（title / chapters / pageUrl 等）平铺 → 现有测试和旧调用方零改动
      // - __meta.run_id → save_script 引用此 id 即可，无需重传脚本内容
      // - __meta.script_preview → 仅 register 模式返回（截断 200 字符），供 AI 确认
      // - __meta.mode → register（新写脚本）/ replay（重跑 run_id）
      final scriptPreview = effectiveScript.length > 200
          ? '${effectiveScript.substring(0, 200)}...'
          : effectiveScript;

      final response = <String, dynamic>{
        if (businessFields != null) ...businessFields else 'result': decoded ?? resultStr,
        '__meta': <String, dynamic>{
          'run_id': storedRunId,
          'mode': runId != null ? 'replay' : 'register',
          'store_size': _runStore.length,
          if (runId == null) 'script_preview': scriptPreview,
        },
      };
      return jsonEncode(response);
    } on TimeoutException {
      LoggerService.instance.w(
        '执行 JS 超时 (>60s)',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'execute_js', 'timeout'],
      );
      return jsonEncode({
        'error': 'JS_TIMEOUT',
        'message': '脚本执行超过 60 秒未返回',
        'script_length': effectiveScript.length,
        'suggestion':
            '检查脚本中是否有死循环、长时间 setTimeout，或在循环中加 await new Promise(r => setTimeout(r, 100)) 让出主线程',
      });
    } catch (e) {
      // Dart 层异常（如 callAsyncJavaScript 方法本身不可用）
      final errorInfo = _parseJsError(e.toString(), effectiveScript);
      LoggerService.instance.w(
        '执行 JS 失败: ${errorInfo.code} - ${errorInfo.message}',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'execute_js', errorInfo.code],
      );
      return jsonEncode({
        'error': errorInfo.code,
        'message': errorInfo.message,
        'raw': e.toString(),
        'suggestion': errorInfo.suggestion,
      });
    }
  }

  /// 解析 WebView 抛出的 JS 异常，按错误类型给出针对性修复建议
  ({String code, String message, String suggestion}) _parseJsError(
    String raw,
    String script,
  ) {
    final lowerRaw = raw.toLowerCase();

    // 语法错误
    if (lowerRaw.contains('syntaxerror')) {
      return (
        code: 'JS_SYNTAX_ERROR',
        message: '脚本有语法错误',
        suggestion:
            '检查括号/引号是否配对，async IIFE 格式是否正确: (async function(){...})()',
      );
    }

    // 引用错误（未定义变量 / 第三方库）
    if (lowerRaw.contains('referenceerror')) {
      // 提取出错的变量名
      final match = RegExp(r"(\w+)\s+is\s+not\s+defined").firstMatch(raw);
      final varName = match?.group(1);
      final isLibHint = varName != null &&
          (varName == r'$' ||
              varName == 'jQuery' ||
              varName == '_' ||
              varName == 'Vue' ||
              varName == 'React');
      return (
        code: 'JS_REFERENCE_ERROR',
        message: varName != null
            ? '引用了未定义的变量: $varName'
            : '引用了未定义的变量',
        suggestion: isLibHint
            ? '目标网站没有加载 $varName 等第三方库，请改用原生 DOM API (document.querySelector, innerText, etc.)'
            : '检查变量名拼写是否正确，注意 IIFE 内是独立作用域，外部 const/let 无法直接访问',
      );
    }

    // 类型错误
    if (lowerRaw.contains('typeerror')) {
      // 提取"Cannot read properties of XXX (reading 'yyy')"
      final nullMatch =
          RegExp(r"Cannot read propert(?:y|ies) of (null|undefined)").firstMatch(raw);
      final isNullAccess = nullMatch != null;
      return (
        code: 'JS_TYPE_ERROR',
        message: isNullAccess
            ? '访问了 null/undefined 对象的属性'
            : '类型错误',
        suggestion: isNullAccess
            ? 'querySelector 可能返回 null。访问前加判断: const el = document.querySelector("..."); if (el) { ... }'
            : '检查对象/数组的访问方式是否正确，必要时加 typeof 或 instanceof 判断',
      );
    }

    // Dart 侧类型转换错误：evaluateJavascript 返回了 Map 而非 String
    // 典型错误: "type '_Map<String, dynamic>' is not a subtype of type 'FutureOr<String>'"
    if (raw.contains('_Map<String, dynamic>') ||
        raw.contains('FutureOr<String>')) {
      return (
        code: 'JS_TYPE_ERROR',
        message: '脚本返回了 JSON 对象而非字符串',
        suggestion:
            '脚本必须返回字符串（用 JSON.stringify 包装返回值）。例如: return JSON.stringify({title: ..., content: ...})',
      );
    }

    // 超时（被外层 catch 捕获前）
    if (lowerRaw.contains('timeout')) {
      return (
        code: 'JS_TIMEOUT',
        message: '脚本执行超时',
        suggestion:
            '在长循环中加 await new Promise(r => setTimeout(r, 100)) 让出主线程，避免阻塞 WebView',
      );
    }

    return (
      code: 'JS_RUNTIME_ERROR',
      message: '脚本执行失败: $raw',
      suggestion:
          '根据错误信息修正后重试。如果连续失败 3 次，建议换一种思路（如换选择器、简化提取逻辑）',
    );
  }

  /// 让 WebView 跳转到指定 URL
  ///
  /// 场景：当前页是目录页，AI 需要提取某个章节的内容。
  /// 章节 URL 在目录页中已提取到，AI 调用本工具跳转到该 URL 后，
  /// 再调用 get_page_info / execute_js 提取正文。
  ///
  /// 等待 onLoadStop 完成才返回，确保后续工具调用看到的是新页面。
  /// 同时禁止跳转至当前页面（避免无意义重载）。
  Future<String> _navigateTo(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) {
      return jsonEncode({
        'error': 'missing_param',
        'message': '缺少 url 参数',
        'missing': ['url'],
        'suggestion': '传入要跳转的完整 URL，例如 https://example.com/chapter/1.html',
      });
    }

    // 校验 URL 格式
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      LoggerService.instance.w(
        'URL 解析失败: $url - $e',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'navigate_to', 'url_parse'],
      );
      return jsonEncode({
        'error': 'INVALID_URL',
        'message': 'URL 格式不合法: $url',
        'suggestion': '请传入完整的 URL（包含 http/https）',
      });
    }
    if (!uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return jsonEncode({
        'error': 'INVALID_URL',
        'message': 'URL 必须是 http(s) 绝对地址: $url',
        'suggestion': '请使用完整 URL（包含 http/https），不支持 javascript: 等伪协议',
      });
    }

    // 阻止跳转到当前页面（避免无意义重载浪费一次 HTTP 请求）
    if (_isHeadless) {
      // Headless 模式：用 _currentUrl 比较
      if (_currentUrl == url) {
        return jsonEncode({
          'ok': true,
          'message': '已在目标页面',
          'url': url,
          'note': '当前页面已为目标 URL，未执行跳转',
        });
      }
    } else {
      try {
        final currentUrl = await _webviewController.getUrl();
        if (currentUrl != null && currentUrl.toString() == url) {
          return jsonEncode({
            'ok': true,
            'message': '已在目标页面',
            'url': url,
            'note': '当前页面已为目标 URL，未执行跳转',
          });
        }
      } catch (_) {
        // getUrl 失败不阻止跳转
      }
    }

    try {
      LoggerService.instance.i(
        'navigate_to: 跳转 $url (headless=$_isHeadless)',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'navigate_to'],
      );

      await _webviewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );

      final loaded = await _waitForUrl(
        url,
        trustOnTimeout: _isHeadless,
      );
      if (!loaded && !_isHeadless) {
        return jsonEncode({
          'error': 'NAVIGATE_TIMEOUT',
          'message': '跳转后等待页面加载超时（30秒）',
          'target_url': url,
          'suggestion': '检查网络连接，或目标网站是否可访问',
        });
      }

      return jsonEncode({
        'ok': true,
        'url': url,
        'message': '跳转成功',
      });
    } catch (e) {
      LoggerService.instance.w(
        'navigate_to 失败: $url, error=$e',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'navigate_to', 'error'],
      );
      return jsonEncode({
        'error': 'NAVIGATE_FAILED',
        'message': '跳转失败: ${e.toString()}',
        'url': url,
      });
    }
  }

  /// 查询 WebView 当前实际加载的 URL
  ///
  /// 区别于 [_currentUrl]（场景构造时传入的预期 URL），本工具返回
  /// WebView 运行时的真实 URL（`getUrl()` 的返回值）。
  ///
  /// 典型用途：
  /// - 在 navigate_to 之后确认 WebView 是否真的停留在目标页面
  /// - 排查 Headless WebView 在某些平台 URL 不更新的问题
  /// - 判断 JS 脚本中的 `{{URL}}` 占位符实际会被替换成什么
  Future<String> _getCurrentUrl() async {
    final expectedUrl = _currentUrl;
    String? actualUrl;
    try {
      final uri = await _webviewController.getUrl();
      actualUrl = uri?.toString();
    } catch (e) {
      LoggerService.instance.w(
        'get_current_url: getUrl() 调用失败 $e',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'get_current_url', 'error'],
      );
      return jsonEncode({
        'error': 'GET_URL_FAILED',
        'message': '无法读取 WebView 当前 URL: $e',
        'expected_url': expectedUrl,
        'suggestion': '可能 WebView 尚未就绪，请稍后重试 get_current_url',
      });
    }

    LoggerService.instance.i(
      'get_current_url: actual=$actualUrl (expected=$expectedUrl, headless=$_isHeadless)',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'get_current_url'],
    );

    // getUrl() 返回空：某些平台 Headless WebView 未加载页面时会返回 null
    if (actualUrl == null || actualUrl.isEmpty) {
      return jsonEncode({
        'url': null,
        'expected_url': expectedUrl,
        'matched': false,
        'note': 'WebView 当前未加载任何页面（getUrl 返回空）',
        'suggestion': _isHeadless
            ? 'Headless WebView 可能尚未加载页面，可调用 get_page_info 触发加载'
            : '页面可能尚未初始化，请稍后重试',
      });
    }

    return jsonEncode({
      'url': actualUrl,
      'expected_url': expectedUrl,
      'matched': actualUrl == expectedUrl,
    });
  }

  /// 查询该域名是否已有缓存脚本
  ///
  /// ## 新行为（run_id 句柄）
  /// 从数据库读出脚本后自动注册到 RunStore，返回 `list_run_id` + `content_run_id`。
  /// 后续 AI 调用 `execute_js(run_id=...)` 即可重跑，**零重抄**。
  ///
  /// 业务字段（id / domain / use_count / verified）平铺到顶层，保持向后兼容。
  /// 完整脚本内容**不返回**到顶层（避免占上下文）；需要时可调 `inspect_script(run_id)`。
  Future<String> _getCachedScript(Map<String, dynamic> args) async {
    final domain = args['domain'] as String?;
    final url = _currentUrl;

    // 提取域名
    final uri = Uri.tryParse(url);
    final effectiveDomain = domain ?? uri?.host ?? '';

    if (effectiveDomain.isEmpty) {
      return jsonEncode({
        'error': 'missing_domain',
        'message': '无法确定域名',
        'current_url': url,
        'suggestion': '当前页面 URL 无法解析出域名。请传入 domain 参数（如 "www.example.com"）',
      });
    }

    /// 查询数据库（通过 DatabaseConnection）
    final List<Map<String, dynamic>> results;
    try {
      final dbConnection = _ref.read(databaseConnectionProvider);
      final db = await dbConnection.database;
      results = await db.query(
        'site_scripts',
        where: 'domain = ?',
        whereArgs: [effectiveDomain],
        orderBy: 'last_used_at DESC',
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询缓存脚本失败: domain=$effectiveDomain - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['agent', 'webview-extract', 'get_cached_script', 'db_error'],
      );
      return jsonEncode({
        'error': 'DB_QUERY_FAILED',
        'message': '查询缓存脚本数据库失败: $e',
        'domain': effectiveDomain,
        'suggestion': '数据库可能被锁或损坏，请重试 get_cached_script',
      });
    }

    if (results.isEmpty) {
      return jsonEncode({
        'found': false,
        'domain': effectiveDomain,
        'message': '该域名无缓存脚本，需要新生成提取脚本',
        'suggestion': '请用 execute_js(script=...) 测试新脚本，测试通过后用 save_script(list_run_id=..., content_run_id=..., domain=...) 保存',
      });
    }

    // 取最近使用的一个脚本，注册到 RunStore 并返回 run_id
    final row = results.first;
    final listJs = row['chapter_list_js'] as String? ?? '';
    final contentJs = row['chapter_content_js'] as String? ?? '';
    final dbId = row['id'] as String;

    // 注册到 RunStore（db_xxx 形式）
    final listRunId = _runStore.put(
      script: listJs,
      success: true,
      source: RunEntrySource.database,
      rawId: dbId,
      domain: effectiveDomain,
    );
    final contentRunId = _runStore.put(
      script: contentJs,
      success: true,
      source: RunEntrySource.database,
      rawId: dbId,
      domain: effectiveDomain,
    );

    LoggerService.instance.i(
      '查询缓存脚本: domain=$effectiveDomain, found=1, list=$listRunId, content=$contentRunId',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'get_cached_script'],
    );

    return jsonEncode({
      'found': true,
      'domain': effectiveDomain,
      'id': dbId,
      'list_run_id': listRunId,
      'content_run_id': contentRunId,
      'use_count': row['use_count'],
      'verified': row['verified'],
      'url_pattern': row['url_pattern'],
      'sample_url': row['sample_url'],
      // 元信息：所有候选脚本（供 AI 选择，但脚本内容不返回）
      'candidates': results.map((r) => {
        'id': r['id'],
        'use_count': r['use_count'],
        'verified': r['verified'],
        'last_used_at': r['last_used_at'],
      }).toList(),
      'message':
          '已加载缓存脚本到 RunStore。用 execute_js(run_id=$listRunId) 重跑目录脚本，execute_js(run_id=$contentRunId) 重跑内容脚本',
    });
  }

  /// 保存提取脚本到数据库
  ///
  /// ## 双模式
  ///
  /// ### run_id 模式（新，推荐）
  /// - 传 `list_run_id` + `content_run_id`，从 RunStore 取已验证的脚本存库
  /// - **零重传**——脚本内容不经过 LLM 上下文
  /// - 保存的版本天然与测试版本一致（引用同一 RunStore 记录）
  ///
  /// ### 旧模式（兼容）
  /// - 传 `domain` + `chapter_list_js` + `chapter_content_js` 完整脚本
  /// - 校验 `{{URL}}` 占位符后存库
  /// - 向后兼容现有测试和旧 AI 行为
  /// 保存脚本后通知 UI 失效重读
  ///
  /// `_saveScript` 直接 `db.insert('site_scripts')` 写库，绕过了 Provider 状态管理。
  /// 若不主动失效，三个 UI 入口都看不到新脚本：
  /// - 脚本管理面板（`siteScriptListProvider`，StateNotifier 仅初始化加载一次）
  /// - 「添加小说」FAB（`webviewCurrentSiteScriptProvider`，FutureProvider 仅在
  ///   URL host 变化时重查；agent 写库后 URL 未变，不会自动失效）
  ///
  /// 因此在每次 insert 成功后调用本方法：
  /// - `refresh()` 让脚本管理面板重新 `getAll()`
  /// - `invalidate()` 强制 FAB 按钮按当前域名重查，立即出现
  void _notifyScriptSaved() {
    _ref.read(siteScriptListProvider.notifier).refresh();
    _ref.invalidate(webviewCurrentSiteScriptProvider);
  }

  Future<String> _saveScript(Map<String, dynamic> args) async {
    final listRunId = args['list_run_id'] as String?;
    final contentRunId = args['content_run_id'] as String?;
    final domain = args['domain'] as String?;
    final urlPattern = args['url_pattern'] as String? ?? '';

    // ── run_id 模式 ──
    if (listRunId != null && contentRunId != null) {
      // 取 RunStore 中的脚本内容
      final listEntry = _runStore.get(listRunId);
      final contentEntry = _runStore.get(contentRunId);

      // 逐个检查缺失
      final missing = <String, String>{};
      if (listEntry == null) {
        missing['list_run_id'] = listRunId;
      }
      if (contentEntry == null) {
        missing['content_run_id'] = contentRunId;
      }
      if (domain == null || domain.isEmpty) {
        missing['domain'] = 'domain 参数缺失或为空';
      }

      if (missing.isNotEmpty) {
        final msg = missing.containsKey('domain')
            ? '缺少 domain 参数'
            : 'RunStore 中未找到以下 run_id（可能已被淘汰）: ${missing.keys.join(", ")}';
        return jsonEncode({
          'error': 'run_id',
          'message': msg,
          'missing_run_ids': missing,
          'store_size': _runStore.length,
          'suggestion': missing.containsKey('domain')
              ? '请传入 save_script(domain, list_run_id, content_run_id) 中的 domain 参数'
              : '用 execute_js(script=...) 重新执行脚本获取新的 run_id，然后调用 save_script(list_run_id=..., content_run_id=...)',
        });
      }

      final chapterListJs = listEntry!.script;
      final chapterContentJs = contentEntry!.script;

      // 校验（RunStore 中的脚本应该已通过校验，但加一层防御）
      final listVal = WebViewJsExecutor.validateScript(chapterListJs);
      if (listVal != null) {
        return jsonEncode({
          'error': 'SCRIPT_VALIDATION_FAILED',
          'message': 'RunStore 中的目录脚本校验失败（数据不一致，请用 script 模式重新生成）',
          'script_type': 'chapter_list_js',
          'run_id': listRunId,
          'validation_error': listVal,
        });
      }
      final contentVal = WebViewJsExecutor.validateScript(chapterContentJs);
      if (contentVal != null) {
        return jsonEncode({
          'error': 'SCRIPT_VALIDATION_FAILED',
          'message': 'RunStore 中的内容脚本校验失败（数据不一致，请用 script 模式重新生成）',
          'script_type': 'chapter_content_js',
          'run_id': contentRunId,
          'validation_error': contentVal,
        });
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = now.toString();

      try {
        final dbConnection = _ref.read(databaseConnectionProvider);
        final db = await dbConnection.database;
        await db.insert('site_scripts', {
          'id': id,
          'domain': domain,
          'url_pattern': urlPattern,
          'chapter_list_js': chapterListJs,
          'chapter_content_js': chapterContentJs,
          'sample_url': _currentUrl,
          'created_at': now,
          'last_used_at': now,
          'use_count': 0,
          'verified': 0,
        });
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          '保存脚本到数据库失败 (run_id模式): domain=$domain - $e',
          stackTrace: stackTrace.toString(),
          category: LogCategory.database,
          tags: ['agent', 'webview-extract', 'save_script', 'db_error'],
        );
        return jsonEncode({
          'error': 'DB_SAVE_FAILED',
          'message': '保存脚本到数据库失败: $e',
          'domain': domain,
          'suggestion': '数据库可能被锁，请重试 save_script',
        });
      }

      _scriptSavedThisSession = true;
      _notifyScriptSaved();

      LoggerService.instance.i(
        '保存提取脚本 (run_id 模式): domain=$domain, id=$id, listId=$listRunId, contentId=$contentRunId',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'save_script', 'run_id'],
      );

      return jsonEncode({
        'success': true,
        'id': id,
        'domain': domain,
        'message': '脚本已保存（通过 run_id 引用，测试版本与保存版本一致）',
        'source_run_ids': {'list': listRunId, 'content': contentRunId},
      });
    }

    // ── 旧模式（兼容）：传完整脚本 ──
    final chapterListJs = args['chapter_list_js'] as String?;
    final chapterContentJs = args['chapter_content_js'] as String?;

    // 逐个检查，精确报告缺失字段
    final missing = <String>[];
    if (domain == null || domain.isEmpty) missing.add('domain');
    if (chapterListJs == null || chapterListJs.isEmpty) {
      missing.add('chapter_list_js');
    }
    if (chapterContentJs == null || chapterContentJs.isEmpty) {
      missing.add('chapter_content_js');
    }
    if (missing.isNotEmpty) {
      return jsonEncode({
        'error': 'missing_param',
        'message': '缺少必需的参数: ${missing.join(", ")}',
        'missing': missing,
        'received_keys': args.keys.toList(),
        'suggestion':
            missing.contains('domain') && listRunId == null
                ? '请补充 domain 参数。或使用 run_id 模式：save_script(list_run_id=..., content_run_id=...)+domain'
                : listRunId != null
                    ? '请补充所有必需的 run_id 参数（list_run_id + content_run_id + domain）'
                    : '请补充缺失参数。注意字段名是下划线格式: domain / chapter_list_js / chapter_content_js',
      });
    }

    // 防呆校验：目录脚本
    final listValidation = WebViewJsExecutor.validateScript(chapterListJs!);
    if (listValidation != null) {
      LoggerService.instance.w(
        '保存时目录脚本校验失败: $listValidation',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'save_script', 'validation'],
      );
      return jsonEncode({
        'error': 'SCRIPT_VALIDATION_FAILED',
        'message': '目录脚本校验失败',
        'script_type': 'chapter_list_js',
        'validation_error': listValidation,
        'suggestion': listValidation,
      });
    }

    // 防呆校验：内容脚本
    final contentValidation = WebViewJsExecutor.validateScript(chapterContentJs!);
    if (contentValidation != null) {
      LoggerService.instance.w(
        '保存时内容脚本校验失败: $contentValidation',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'save_script', 'validation'],
      );
      return jsonEncode({
        'error': 'SCRIPT_VALIDATION_FAILED',
        'message': '内容脚本校验失败',
        'script_type': 'chapter_content_js',
        'validation_error': contentValidation,
        'suggestion': contentValidation,
      });
    }

    // {{URL}} 占位符原样存入数据库，不做替换
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = now.toString();

    try {
      final dbConnection = _ref.read(databaseConnectionProvider);
      final db = await dbConnection.database;
      await db.insert('site_scripts', {
        'id': id,
        'domain': domain,
        'url_pattern': urlPattern,
        'chapter_list_js': chapterListJs,
        'chapter_content_js': chapterContentJs,
        'sample_url': _currentUrl,
        'created_at': now,
        'last_used_at': now,
        'use_count': 0,
        'verified': 0,
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '保存脚本到数据库失败 (兼容模式): domain=$domain - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['agent', 'webview-extract', 'save_script', 'db_error'],
      );
      return jsonEncode({
        'error': 'DB_SAVE_FAILED',
        'message': '保存脚本到数据库失败: $e',
        'domain': domain,
        'suggestion': '数据库可能被锁，请重试 save_script',
      });
    }

    _scriptSavedThisSession = true;
    _notifyScriptSaved();

    LoggerService.instance.i(
      '保存提取脚本 (旧模式): domain=$domain, id=$id',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'save_script', 'legacy'],
    );

    return jsonEncode({
      'success': true,
      'id': id,
      'domain': domain,
      'message': '脚本已保存',
    });
  }

  /// 列出所有已保存脚本
  Future<String> _listCachedScripts() async {
    final dbConnection = _ref.read(databaseConnectionProvider);
    final db = await dbConnection.database;
    final results = await db.query(
      'site_scripts',
      orderBy: 'last_used_at DESC',
      limit: 20,
    );

    final scripts = results.map((row) => {
          'id': row['id'],
          'domain': row['domain'],
          'urlPattern': row['url_pattern'],
          'useCount': row['use_count'],
          'verified': row['verified'],
          'lastUsedAt': row['last_used_at'],
        }).toList();

    return jsonEncode({
      'count': scripts.length,
      'scripts': scripts,
    });
  }

  /// 查看 RunStore 中某条 run_id 的完整脚本内容
  ///
  /// 调试用：当 AI 需要查看/修改一段已注册的脚本（如 debug execute_js 失败、
  /// 改写缓存脚本）时，用本工具拿到完整脚本，而不是从上下文里翻历史。
  ///
  /// 注意：返回完整脚本会占用上下文，**非必要时不要调用**。
  Future<String> _inspectScript(Map<String, dynamic> args) async {
    final runId = args['run_id'] as String?;
    if (runId == null || runId.isEmpty) {
      return jsonEncode({
        'error': 'missing_param',
        'message': '缺少 run_id 参数',
        'missing': ['run_id'],
        'suggestion': '请传入要查看的 run_id（来自 execute_js 的 __meta.run_id 或 get_cached_script 的 list_run_id/content_run_id）',
      });
    }

    final entry = _runStore.get(runId);
    if (entry == null) {
      return jsonEncode({
        'error': 'RUN_ID_NOT_FOUND',
        'message': '未找到 $runId（可能已被淘汰或未注册）',
        'store_size': _runStore.length,
        'suggestion': 'RunStore 有容量限制（50 条 LRU 淘汰）。若是 database 来源的 id，请重新调用 get_cached_script 加载',
      });
    }

    return jsonEncode({
      'run_id': entry.runId,
      'script': entry.script,
      'success': entry.success,
      'source': entry.source.name,
      'script_length': entry.script.length,
      if (entry.testUrl != null) 'test_url': entry.testUrl,
      if (entry.resultSummary != null) 'result_summary': entry.resultSummary,
      if (entry.domain != null) 'domain': entry.domain,
    });
  }

  /// 查询指定域名的提取脚本在实际使用中的运行日志
  ///
  /// AI 在对话中用 execute_js 测试脚本时，脚本能跑通不代表真实使用也能成功。
  /// 本工具让 AI 查看 HeadlessWebView 在阅读器/FAB/预加载等真实场景中
  /// 执行脚本时的错误、超时、空结果等日志，定位"脚本能跑通但实际抓取失败"的问题。
  ///
  /// 日志来源：
  /// - HeadlessWebViewContentService（阅读器获取章节内容）
  /// - HeadlessWebViewChapterListService（FAB 添加小说获取目录）
  /// - 预加载服务
  ///
  /// 过滤策略：先按 tag `headless-webview` 过滤（覆盖 ContentService 和
  /// ChapterListService 的日志），再按 domain 关键词 + 级别过滤。
  Future<String> _getScriptLogs(Map<String, dynamic> args) async {
    // 1. 解析参数
    final domain = args['domain'] as String? ??
        Uri.tryParse(_currentUrl)?.host ??
        '';
    final levelStr = args['level'] as String? ?? 'warning';
    final limit = (args['limit'] as int?)?.clamp(1, 30) ?? 10;

    if (domain.isEmpty) {
      return jsonEncode({
        'error': 'missing_domain',
        'message': '无法确定域名',
        'current_url': _currentUrl,
        'suggestion': '请传入 domain 参数（如 "www.example.com"）',
      });
    }

    // 2. 级别映射
    final minLevel = _parseLogLevel(levelStr);

    // 3. 从 LoggerService 获取日志
    //    策略：先按 tag 'headless-webview' 过滤，再按 domain 关键词 + 级别过滤
    final logs = LoggerService.instance.getLogsByTag('headless-webview');
    final filtered = logs
        .where((log) =>
            log.level.index >= minLevel.index &&
            log.message.contains(domain))
        .toList();

    // 按时间倒序（最新在前）
    final sorted = filtered.reversed.take(limit).toList();

    // 4. 格式化返回
    if (sorted.isEmpty) {
      return jsonEncode({
        'found': false,
        'domain': domain,
        'message': '该域名无 headless-webview 运行日志（可能尚未在阅读器中使用过，或日志已被清理）',
        'suggestion': '如果脚本刚保存，需要在阅读器中打开该网站的章节后才会产生运行日志',
      });
    }

    return jsonEncode({
      'found': true,
      'domain': domain,
      'count': sorted.length,
      'total_matching': filtered.length,
      'logs': sorted.map((log) {
        final msg = log.message.length > 300
            ? '${log.message.substring(0, 300)}...'
            : log.message;
        return {
          'time': LoggerService.formatTimestamp(log.timestamp),
          'level': log.level.label,
          'message': msg,
          'tags': log.tags.where((t) => t != 'headless-webview').toList(),
        };
      }).toList(),
    });
  }

  /// 解析日志级别字符串为 LogLevel 枚举
  LogLevel _parseLogLevel(String level) {
    switch (level) {
      case 'error':
        return LogLevel.error;
      case 'warning':
        return LogLevel.warning;
      case 'info':
        return LogLevel.info;
      case 'debug':
        return LogLevel.debug;
      default:
        return LogLevel.warning;
    }
  }

  // ===== DOM 精简脚本 =====

  /// 在 WebView 中执行的 DOM 精简脚本
  ///
  /// 移除无关元素（script/style/nav 等），截断长文本，
  /// 返回精简后的 HTML 结构供 LLM 分析。
  static const _domSimplifyJs = '''
(function() {
  var clone = document.cloneNode(true);
  // 移除不需要的元素
  var removeTags = ['script','style','link','meta','noscript','svg','img','video','audio','iframe','nav','footer','header','aside'];
  removeTags.forEach(function(tag) {
    clone.querySelectorAll(tag).forEach(function(el) { el.remove(); });
  });
  // 移除广告类
  clone.querySelectorAll('[class*="ad"],[id*="ad"],[class*="banner"],[class*="popup"],[class*="sidebar"]').forEach(function(el) { el.remove(); });
  // 精简 class：只保留前3个
  clone.querySelectorAll('[class]').forEach(function(el) {
    var classes = el.className.split(' ').slice(0, 3).join(' ');
    el.setAttribute('class', classes);
  });
  // 截断过长文本
  var walker = document.createTreeWalker(clone, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) {
    if (walker.currentNode.textContent.length > 200) {
      walker.currentNode.textContent = walker.currentNode.textContent.substring(0, 200) + '...';
    }
  }
  // 截断整体 HTML 长度
  var html = clone.documentElement.outerHTML;
  if (html.length > 15000) {
    html = html.substring(0, 15000) + '\\n... [DOM truncated]';
  }
  return html;
})()
''';

  /// 页面类型推断脚本
  ///
  /// 通过 DOM 特征简单判断是目录页还是章节内容页：
  /// - 大量相同结构链接 + 长列表 → chapter_list
  /// - 少量链接 + 大量长段落 → chapter_content
  /// - 其他 → unknown
  ///
  /// 返回 JSON: `{"pageType": "chapter_list|chapter_content|unknown", "title": "页面title"}`
  static const _inferPageTypeJs = r'''
(function() {
  try {
    var title = document.title || '';
    // 统计链接数量
    var links = document.querySelectorAll('a[href]');
    var linkCount = links.length;
    // 统计长段落（>200字符）
    var paragraphs = document.querySelectorAll('p, div');
    var longParaCount = 0;
    var paraSample = [];
    for (var i = 0; i < paragraphs.length && paraSample.length < 5; i++) {
      var text = (paragraphs[i].innerText || '').trim();
      if (text.length > 200) {
        longParaCount++;
        if (paraSample.length < 3) paraSample.push(text.length);
      }
    }
    // 列表标签
    var listItems = document.querySelectorAll('li').length;
    // 简单启发式：
    // 链接密度高 + 段落少 → 目录页
    // 链接少 + 大量长段落 → 章节内容页
    var pageType = 'unknown';
    if (linkCount >= 20 && longParaCount <= 3) {
      pageType = 'chapter_list';
    } else if (longParaCount >= 3 && linkCount < 20) {
      pageType = 'chapter_content';
    } else if (listItems >= 10 && linkCount >= 10) {
      pageType = 'chapter_list';
    }
    return JSON.stringify({pageType: pageType, title: title});
  } catch (e) {
    return JSON.stringify({pageType: 'unknown', title: '', error: e.toString()});
  }
})()
''';

  // ===== 工具定义（OpenAI Function Calling schema）=====

  static const _getPageInfoTool = {
    'type': 'function',
    'function': {
      'name': 'get_page_info',
      'description':
          '获取当前浏览器页面的 URL、页面标题、页面类型推断（chapter_list=目录页 / chapter_content=章节内容页 / unknown=未知）和精简后的 DOM 结构。注意：pageType 仅为参考，请结合 DOM 确认。若返回 PAGE_NOT_READY，请稍后重试。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    },
  };

  static const _executeJsTool = {
    'type': 'function',
    'function': {
      'name': 'execute_js',
      'description':
          '在当前 WebView 页面中执行 JavaScript 脚本。'
          '支持两种模式：\n'
          '  1. **探测模式**（传 script）：传入 JS 代码探测 DOM 结构或执行新写的提取脚本。'
          '脚本必须包含 {{URL}} 占位符。执行成功后自动注册到 RunStore 并在 __meta.run_id 返回。\n'
          '  2. **重跑模式**（传 run_id）：从 RunStore 加载已注册的脚本执行，零重抄。'
          'run_id 来源：execute_js 的 __meta.run_id、get_cached_script 的 list_run_id/content_run_id。\n'
          '返回值：业务字段平铺到顶层（title/chapters/...），工具元数据在 __meta 内。\n'
          '脚本超时 60 秒会被自动终止（返回 JS_TIMEOUT）。'
          '常见错误码: JS_SYNTAX_ERROR / JS_REFERENCE_ERROR / JS_TYPE_ERROR / SCRIPT_VALIDATION_FAILED / RUN_ID_NOT_FOUND。'
          '请根据返回的 suggestion 字段修正。',
      'parameters': {
        'type': 'object',
        'properties': {
          'script': {
            'type': 'string',
            'description':
                '【探测模式】要执行的 JavaScript 代码。必须包含 {{URL}} 占位符。'
                "格式: (async function(){ const PAGE_URL = '{{URL}}'; ... return JSON.stringify(result); })()",
          },
          'run_id': {
            'type': 'string',
            'description':
                '【重跑模式】RunStore 中的 run_id（exec_xxx 或 db_xxx）。'
                '从 RunStore 加载脚本执行，AI 无需在上下文中保留脚本内容。',
          },
          'test_url': {
            'type': 'string',
            'description':
                '可选。测试用的 URL，会替换脚本中的 {{URL}}。'
                '测试内容脚本时，建议从目录脚本返回的 chapters 数组中取一个 URL 传入。'
                '不填则使用当前浏览器页面 URL。',
          },
        },
      },
    },
  };

  static const _getCachedScriptTool = {
    'type': 'function',
    'function': {
      'name': 'get_cached_script',
      'description':
          '查询指定域名是否已有缓存的提取脚本。找到后自动注册到 RunStore 并返回 '
          'list_run_id + content_run_id，**不返回完整脚本内容**（避免占上下文）。'
          '后续可直接 execute_js(run_id=list_run_id) 重跑，零重抄。'
          '若需查看完整内容（调试），用 inspect_script(run_id=...)。',
      'parameters': {
        'type': 'object',
        'properties': {
          'domain': {
            'type': 'string',
            'description':
                '要查询的域名（如 www.example.com）。不填则使用当前页面域名。',
          },
        },
      },
    },
  };

  static const _saveScriptTool = {
    'type': 'function',
    'function': {
      'name': 'save_script',
      'description':
          '保存提取脚本到本地数据库。'
          '支持两种模式：\n'
          '  1. **run_id 模式**（推荐，零重传）：save_script(domain, list_run_id, content_run_id)。'
          '从 RunStore 引用已测试通过的脚本，保存版本与测试版本天然一致。\n'
          '  2. **旧模式**（兼容）：传 domain + chapter_list_js + chapter_content_js 完整脚本。',
      'parameters': {
        'type': 'object',
        'properties': {
          'domain': {
            'type': 'string',
            'description': '网站域名',
          },
          'list_run_id': {
            'type': 'string',
            'description':
                '【run_id 模式】目录提取脚本在 RunStore 中的 run_id（exec_xxx）。'
                '从之前 execute_js 调用的 __meta.run_id 获取。',
          },
          'content_run_id': {
            'type': 'string',
            'description':
                '【run_id 模式】内容提取脚本在 RunStore 中的 run_id（exec_xxx）。',
          },
          'chapter_list_js': {
            'type': 'string',
            'description': '【旧模式】目录提取 JS 脚本（完整内容）。',
          },
          'chapter_content_js': {
            'type': 'string',
            'description': '【旧模式】内容提取 JS 脚本（完整内容）。',
          },
          'url_pattern': {
            'type': 'string',
            'description': 'URL 模式正则（可选，用于匹配目录页URL）',
          },
        },
      },
    },
  };

  static const _inspectScriptTool = {
    'type': 'function',
    'function': {
      'name': 'inspect_script',
      'description':
          '查看 RunStore 中某条 run_id 的完整脚本内容。**调试用**，仅在需要时调用。'
          '常见场景：(1) execute_js 失败需要看完整脚本 debug；(2) 想基于已注册脚本改写并重新执行。'
          '注意：返回完整脚本会占用上下文，**非必要时不要调用**。',
      'parameters': {
        'type': 'object',
        'properties': {
          'run_id': {
            'type': 'string',
            'description':
                'RunStore 中的 run_id。'
                '来源：execute_js 的 __meta.run_id、get_cached_script 的 list_run_id/content_run_id。',
          },
        },
        'required': ['run_id'],
      },
    },
  };

  static const _getScriptLogsTool = {
    'type': 'function',
    'function': {
      'name': 'get_script_logs',
      'description':
          '查询指定域名的提取脚本在实际使用中的运行日志。'
          '用于诊断"execute_js 能跑通但实际抓取失败"的问题——查看 HeadlessWebView '
          '在阅读器/FAB/预加载等真实场景中执行脚本时的错误、超时、空结果、内容过短等记录。'
          '返回最近 N 条匹配日志（按时间倒序），每条含时间戳、级别、消息摘要。'
          '注意：日志来自真实使用场景（非当前对话），用于定位脚本上线后的问题。',
      'parameters': {
        'type': 'object',
        'properties': {
          'domain': {
            'type': 'string',
            'description': '要查询的域名（如 www.example.com）。不填则使用当前页面域名。',
          },
          'level': {
            'type': 'string',
            'enum': ['error', 'warning', 'info', 'debug'],
            'description':
                '日志级别下限过滤。默认 warning（含 error），只看问题。'
                '填 info 可包含成功记录，填 error 只看错误。',
          },
          'limit': {
            'type': 'integer',
            'description': '返回条数上限，默认 10，最大 30（避免日志占满上下文）。',
          },
        },
      },
    },
  };

  static const _listCachedScriptsTool = {
    'type': 'function',
    'function': {
      'name': 'list_cached_scripts',
      'description': '列出所有已保存的提取脚本（按最近使用排序，最多20条）。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    },
  };

  static const _navigateToTool = {
    'type': 'function',
    'function': {
      'name': 'navigate_to',
      'description':
          '让 WebView 跳转到指定 URL，等待页面加载完成后返回。'
          '用于从目录页跳转到章节内容页提取正文。'
          '跳转成功后可调用 get_page_info 查看新页面的 DOM 结构。',
      'parameters': {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': '目标 URL（必须是完整的 http/https 地址）',
          },
        },
        'required': ['url'],
      },
    },
  };

  static const _getCurrentUrlTool = {
    'type': 'function',
    'function': {
      'name': 'get_current_url',
      'description':
          '查询 WebView 当前实际加载的 URL（不是场景构造时传入的预期 URL）。'
          '返回字段：url=WebView 实际 URL，expected_url=场景预期 URL，matched=两者是否一致。'
          '典型用途：1) navigate_to 之后确认跳转是否生效；2) 排查 Headless WebView URL 不更新的问题；'
          '3) 判断 execute_js 脚本中 {{URL}} 占位符实际会被替换成什么。'
          'Headless 模式下首次调用会自动同步预期 URL 到 Headless WebView。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    },
  };

  /// 执行 patch_memory 工具，序列化 MemoryPatchResult
  Future<String> _executePatchMemory(Map<String, dynamic> args) async {
    final oldText = args['oldText'] as String? ?? args['old_text'] as String?;
    final newText = args['newText'] as String? ?? args['new_text'] as String? ?? '';
    final result = await patchMemory(oldText, newText);
    if (result.success) {
      LoggerService.instance.i(
        'patchMemory 成功: ${result.message}',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'patch_memory', 'success'],
      );
      return jsonEncode({'success': true, 'message': result.message});
    }
    LoggerService.instance.w(
      'patchMemory 失败: ${result.message}',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'patch_memory', 'failed'],
    );
    return jsonEncode({
      'error': 'memory_not_found',
      'message': result.message,
      'allMemories': result.allMemories,
    });
  }
}
