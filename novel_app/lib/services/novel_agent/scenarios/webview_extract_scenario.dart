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
import 'package:novel_app/services/logger_service.dart';

import '../agent_scenario.dart';
import 'webview_js_executor.dart';

class WebViewExtractScenario implements AgentScenario {
  final Ref _ref;
  final InAppWebViewController _webviewController;
  final String _currentUrl;

  /// 是否为 Headless 模式
  ///
  /// Headless 模式下使用 `HeadlessInAppWebView`（后台无 UI），
  /// 不受可见 WebView 页面生命周期影响。
  /// 普通模式下使用可见 `InAppWebView`（向后兼容）。
  final bool _isHeadless;

  /// 普通 WebView 模式构造函数（向后兼容）
  WebViewExtractScenario(this._ref, this._webviewController, this._currentUrl)
    : _isHeadless = false;

  /// Headless 模式工厂构造函数
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
  Set<String> get destructiveTools => {}; // 已禁用确认 — 所有工具自动执行

  @override
  String buildSystemPrompt(AgentScenarioContext context) {
    final url = context.currentUrl ?? _currentUrl;
    return '''
## 当前页面
URL: $url

## 工作目标
从当前小说网站页面生成 JavaScript 提取脚本，获取小说目录和章节内容。

## 工作流程
1. 调用 get_page_info 获取页面 DOM 结构和页面类型推断
2. 调用 get_cached_script 查询该域名是否已有缓存脚本，有则检查可用性，无则新生成
3. 生成两段 JS 脚本：
   - 目录提取脚本：提取小说标题 + 章节列表（含URL），支持自动翻页
   - 内容提取脚本：提取章节标题 + 正文，支持自动翻页拼接
4. 调用 execute_js 测试脚本
5. 测试成功后调用 save_script 保存

## 跨页面提取
- 当前页面是**目录页**时，先提取章节 URL 列表
- 如果某章节的 URL 与当前页不同（如 `/book/xxx/yyy.html`），调用 **navigate_to** 工具跳转到该 URL
- 跳转成功后再次调用 get_page_info 探测新页面 DOM，编写内容提取脚本
- 如果当前页本身就是章节内容页（pageType=chapter_content），直接提取正文

## JS 脚本规范
- 整个脚本是一个 async IIFE: `(async function() { ... return JSON.stringify(result); })()`
- **必须**在脚本开头声明页面URL参数: `const PAGE_URL = '{{URL}}';`
  - 目录脚本中 `PAGE_URL` 是章节列表页 URL
  - 内容脚本中 `PAGE_URL` 是章节内容页 URL
  - **禁止硬编码任何 URL**，所有 URL 相关操作必须通过 `PAGE_URL` 变量
  - **禁止使用** `window.location.href` / `document.URL` / `location.href`，统一用 `PAGE_URL`
  - 翻页时如果链接是相对路径，用 `new URL(href, PAGE_URL).href` 拼接完整URL
- 目录脚本返回: `{ "title": "小说名", "chapters": [{ "title": "第1章 xxx", "url": "..." }] }`
- 内容脚本返回: `{ "title": "章节名", "content": "正文..." }`
- 翻页逻辑：检测下一页按钮 → 点击 → `await new Promise(r => setTimeout(r, 1000))` → 继续提取
- 清理广告：移除含"本章未完"、"一秒记住"等关键词的段落
- 使用标准 DOM API（querySelector、querySelectorAll、innerText），不依赖第三方库

## 注意事项
- 如果脚本执行失败，根据错误信息修正后重试
- 优先使用 id 选择器和语义化 class
- 章节URL必须是完整URL（含协议和域名），如果是相对路径请拼接完整
- 内容提取时跳过广告段落（含"本章未完"、"一秒记住"、"笔趣阁"等关键词的行）
- 如果页面不是小说目录页，直接告知用户

## 错误处理策略
收到工具返回的 error 响应时，**务必先阅读 suggestion 字段**获取修复建议，再决定下一步。

**JS 错误码**（来自 execute_js）：
- `JS_SYNTAX_ERROR`：语法错误 → 检查括号/引号配对，IIFE 格式是否完整
- `JS_REFERENCE_ERROR`：引用了未定义变量 → 不要使用 jQuery/\$/underscore/Vue/React 等第三方库，只用原生 DOM API；检查变量名拼写
- `JS_TYPE_ERROR`：访问了 null/undefined 属性 → 在 querySelector 后加 if(el) 判断
- `JS_TIMEOUT`：脚本超时（>60秒）→ 检查死循环，用 await new Promise(r => setTimeout(r, 100)) 分批
- `JS_RUNTIME_ERROR`：其他运行时错误 → 简化提取逻辑重试
- `missing_param`：缺少参数 → 查看 missing 字段了解具体缺哪些

**保存脚本错误**（来自 save_script）：
- 注意字段名是**下划线格式**：domain / chapter_list_js / chapter_content_js
- 如果缺参，查看 received_keys 和 missing 字段，不要反复重试同一个错误调用

**脚本校验错误**（来自 execute_js / save_script）：
- `SCRIPT_VALIDATION_FAILED`：脚本不符合参数化规范，查看 validation_error 和 script_type 定位问题
  - 缺少 {{URL}} 占位符 → 在脚本开头加 `const PAGE_URL = '{{URL}}';`
  - 硬编码 URL 过多 → 改用 PAGE_URL 变量拼接完整 URL
  - 使用了 window.location.href/document.URL → 改用 PAGE_URL
  - 脚本已校验通过的标志：{{URL}} 占位符 + PAGE_URL 变量 + 无 location.href

**同一错误连续出现 3 次**时，**换一种完全不同的思路**重写脚本（如换选择器、简化提取逻辑、放弃某些字段），不要在同一个错误上死磕。
''';
  }

  @override
  List<Map<String, dynamic>> get tools => [
        _getPageInfoTool,
        _executeJsTool,
        _navigateToTool,
        _getCachedScriptTool,
        _saveScriptTool,
        _listCachedScriptsTool,
      ];

  @override
  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    LoggerService.instance.d(
      'WebViewExtractScenario 执行工具: $name',
      category: LogCategory.ai,
      tags: ['agent', 'scenario', 'webview-extract', name],
    );

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
        case 'get_cached_script':
          result = await _getCachedScript(args);
        case 'save_script':
          result = await _saveScript(args);
        case 'list_cached_scripts':
          result = await _listCachedScripts();
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
      return jsonEncode({
        'error': 'PAGE_NOT_READY',
        'message': '页面尚未加载完成或 WebView 未初始化',
        'raw': e.toString(),
        'suggestion': '请等待几秒后重试 get_page_info',
      });
    }
  }

  /// 在 WebView 中执行 JS 脚本（使用 callAsyncJavaScript）
  ///
  /// 执行前会：
  /// 1. 校验脚本包含 `{{URL}}` 占位符（防呆）
  /// 2. 将 `{{URL}}` 替换为 `test_url`（如提供）或当前页面 URL
  /// 3. 通过 callAsyncJavaScript 执行替换后的脚本
  ///
  /// callAsyncJavaScript 相比 evaluateJavascript 的优势：
  /// - 支持 async/await（Promise 结果正确返回）
  /// - 支持 setTimeout 等异步操作（翻页等待）
  /// - 结构化返回值 CallAsyncJavaScriptResult{value, error}
  /// - JS 错误通过 error 字段返回，不再静默吞噬
  Future<String> _executeJs(Map<String, dynamic> args) async {
    final script = args['script'] as String?;
    if (script == null || script.isEmpty) {
      return jsonEncode({
        'error': 'missing_param',
        'message': '缺少 script 参数',
        'missing': ['script'],
        'suggestion':
            '请传入要执行的 JavaScript 代码。格式要求: (async function(){ const PAGE_URL = \'{{URL}}\'; ... return JSON.stringify(result); })()',
      });
    }

    // 防呆校验：脚本必须符合参数化规范
    final validationError = WebViewJsExecutor.validateScript(script);
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

    // 参数注入：将 {{URL}} 替换为 test_url 或当前页面 URL
    final testUrl = (args['test_url'] as String?) ?? _currentUrl;
    final resolvedScript = script.replaceAll('{{URL}}', testUrl);

    // callAsyncJavaScript 的 functionBody 会被包裹为 async function() { <body> }
    // Agent 生成的脚本是 (async function(){...})() 格式（IIFE），
    // 需要提取内部函数体，否则 IIFE 返回值会被丢弃
    final functionBody = WebViewJsExecutor.extractAsyncFunctionBody(resolvedScript);

    LoggerService.instance.d(
      '执行 JS: 替换 {{URL}} → $testUrl (scriptLen=${resolvedScript.length})',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'execute_js', 'inject'],
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
        final errorInfo = _parseJsError(errorStr, script);
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

      // JS Promise resolve → 返回结果
      LoggerService.instance.i(
        '执行 JS 成功: resultLen=${(result.value ?? '').toString().length}',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'execute_js'],
      );
      return WebViewJsExecutor.stringifyJsResult(result.value);
    } on TimeoutException {
      LoggerService.instance.w(
        '执行 JS 超时 (>60s)',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'execute_js', 'timeout'],
      );
      return jsonEncode({
        'error': 'JS_TIMEOUT',
        'message': '脚本执行超过 60 秒未返回',
        'script_length': script.length,
        'suggestion':
            '检查脚本中是否有死循环、长时间 setTimeout，或在循环中加 await new Promise(r => setTimeout(r, 100)) 让出主线程',
      });
    } catch (e) {
      // Dart 层异常（如 callAsyncJavaScript 方法本身不可用）
      final errorInfo = _parseJsError(e.toString(), script);
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
    } catch (_) {
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

      // 调用 loadUrl 触发跳转
      await _webviewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );

      // 等待页面加载（最多 30 秒）
      // 通过轮询 getUrl 检查 URL 是否为目标 URL
      final start = DateTime.now();
      String? loadedUrl;
      while (DateTime.now().difference(start) < const Duration(seconds: 30)) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final current = await _webviewController.getUrl();
          if (current != null && current.toString() == url) {
            loadedUrl = current.toString();
            break;
          }
        } catch (_) {
          // 忽略轮询错误
        }
      }

      // Headless 模式：即使 getUrl 轮询超时，也信任 loadUrl 调用
      // 因为 Headless WebView 的 getUrl() 在某些平台可能不更新
      if (loadedUrl == null && _isHeadless) {
        // 给 DOM 额外稳定时间
        await Future.delayed(const Duration(seconds: 2));
        loadedUrl = url; // 信任传入的 URL
      }

      if (loadedUrl == null) {
        return jsonEncode({
          'error': 'NAVIGATE_TIMEOUT',
          'message': '跳转后等待页面加载超时（30秒）',
          'target_url': url,
          'suggestion': '检查网络连接，或目标网站是否可访问',
        });
      }

      // 给 DOM 一些稳定时间
      await Future.delayed(const Duration(milliseconds: 500));

      return jsonEncode({
        'ok': true,
        'url': loadedUrl,
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

  /// 查询该域名是否已有缓存脚本
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

    // 查询数据库（通过 DatabaseConnection）
    final dbConnection = _ref.read(databaseConnectionProvider);
    final db = await dbConnection.database;
    final results = await db.query(
      'site_scripts',
      where: 'domain = ?',
      whereArgs: [effectiveDomain],
      orderBy: 'last_used_at DESC',
    );

    if (results.isEmpty) {
      return jsonEncode({
        'found': false,
        'domain': effectiveDomain,
        'message': '该域名无缓存脚本，需要新生成提取脚本',
      });
    }

    // 统一使用下划线命名，与 save_script 参数名一致
    final scripts = results.map((row) => {
          'id': row['id'],
          'domain': row['domain'],
          'url_pattern': row['url_pattern'],
          'chapter_list_js': row['chapter_list_js'],
          'chapter_content_js': row['chapter_content_js'],
          'use_count': row['use_count'],
          'verified': row['verified'],
        }).toList();

    LoggerService.instance.i(
      '查询缓存脚本: domain=$effectiveDomain, found=${scripts.length}',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'get_cached_script'],
    );

    return jsonEncode({
      'found': true,
      'domain': effectiveDomain,
      'scripts': scripts,
    });
  }

  /// 保存提取脚本到数据库
  ///
  /// 保存前会校验两个脚本均包含 `{{URL}}` 占位符（防呆）。
  /// `{{URL}}` 占位符原样存入数据库，不做替换。
  Future<String> _saveScript(Map<String, dynamic> args) async {
    final domain = args['domain'] as String?;
    final chapterListJs = args['chapter_list_js'] as String?;
    final chapterContentJs = args['chapter_content_js'] as String?;
    final urlPattern = args['url_pattern'] as String? ?? '';

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
            '请补充缺失参数。注意字段名是下划线格式: domain / chapter_list_js / chapter_content_js',
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

    LoggerService.instance.i(
      '保存提取脚本: domain=$domain, id=$id',
      category: LogCategory.ai,
      tags: ['agent', 'webview-extract', 'save_script'],
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
          '在当前 WebView 页面中执行 JavaScript 脚本并返回结果。用于测试生成的提取脚本。'
          '脚本必须包含 {{URL}} 占位符（代码层会自动替换为真实 URL）。'
          '脚本超时 60 秒会被自动终止（返回 JS_TIMEOUT）。'
          '常见错误码: JS_SYNTAX_ERROR / JS_REFERENCE_ERROR / JS_TYPE_ERROR / SCRIPT_VALIDATION_FAILED。'
          '请根据返回的 suggestion 字段修正。',
      'parameters': {
        'type': 'object',
        'properties': {
          'script': {
            'type': 'string',
            'description':
                '要执行的 JavaScript 代码。必须包含 {{URL}} 占位符。'
                "格式: (async function(){ const PAGE_URL = '{{URL}}'; ... return JSON.stringify(result); })()",
          },
          'test_url': {
            'type': 'string',
            'description':
                '可选。测试用的 URL，会替换脚本中的 {{URL}}。'
                '测试内容脚本时，建议从目录脚本返回的 chapters 数组中取一个 URL 传入。'
                '不填则使用当前浏览器页面 URL。',
          },
        },
        'required': ['script'],
      },
    },
  };

  static const _getCachedScriptTool = {
    'type': 'function',
    'function': {
      'name': 'get_cached_script',
      'description':
          '查询指定域名是否已有缓存的提取脚本。如果有则返回脚本内容，可直接复用或修改后测试。返回字段使用下划线命名（chapter_list_js / chapter_content_js），与 save_script 参数名一致。',
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
      'description': '保存提取脚本到本地数据库，下次访问同域名时可直接复用。',
      'parameters': {
        'type': 'object',
        'properties': {
          'domain': {
            'type': 'string',
            'description': '网站域名',
          },
          'chapter_list_js': {
            'type': 'string',
            'description': '目录提取 JS 脚本',
          },
          'chapter_content_js': {
            'type': 'string',
            'description': '内容提取 JS 脚本',
          },
          'url_pattern': {
            'type': 'string',
            'description': 'URL 模式正则（可选，用于匹配目录页URL）',
          },
        },
        'required': ['domain', 'chapter_list_js', 'chapter_content_js'],
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
}
