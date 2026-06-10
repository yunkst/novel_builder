/// WebView 网页小说提取场景
///
/// 在用户浏览小说网站时，通过 ReAct 循环生成 JS 脚本
/// 提取小说目录和章节内容。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/services/logger_service.dart';

import '../agent_scenario.dart';

class WebViewExtractScenario implements AgentScenario {
  final Ref _ref;
  final InAppWebViewController _webviewController;
  final String _currentUrl;

  WebViewExtractScenario(this._ref, this._webviewController, this._currentUrl);

  @override
  String get id => ScenarioIds.webviewExtract;

  @override
  String get displayName => '网页小说提取';

  @override
  Set<String> get destructiveTools => {'save_script'};

  @override
  String buildSystemPrompt(AgentScenarioContext context) {
    final url = context.currentUrl ?? _currentUrl;
    return '''
你是网页数据提取专家。用户正在浏览一个小说网站，你需要生成 JavaScript 脚本来提取小说的目录和内容。

## 当前页面
URL: $url

## 工作流程
1. 先调用 get_page_info 获取页面 DOM 结构
2. 分析 DOM 结构，理解页面布局（目录页还是章节页）
3. 调用 get_cached_script 查询该域名是否已有缓存脚本
4. 如果有缓存脚本，检查是否可用；如果没有，则新生成
5. 生成两段 JS 脚本：
   - 目录提取脚本：提取小说标题 + 章节列表（含URL），支持自动翻页
   - 内容提取脚本：提取章节标题 + 正文，支持自动翻页拼接
6. 调用 execute_js 测试脚本
7. 测试成功后调用 save_script 保存

## JS 脚本规范
- 整个脚本是一个 async IIFE: `(async function() { ... return JSON.stringify(result); })()`
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
''';
  }

  @override
  List<Map<String, dynamic>> get tools => [
        _getPageInfoTool,
        _executeJsTool,
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
    try {
      switch (name) {
        case 'get_page_info':
          return await _getPageInfo();
        case 'execute_js':
          return await _executeJs(args);
        case 'get_cached_script':
          return await _getCachedScript(args);
        case 'save_script':
          return await _saveScript(args);
        case 'list_cached_scripts':
          return await _listCachedScripts();
        default:
          return jsonEncode({
            'error': 'unknown_tool',
            'message': '未知工具: $name',
          });
      }
    } catch (e, stackTrace) {
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

  // ===== 工具实现 =====

  /// 获取当前页面信息（URL + 精简 DOM）
  Future<String> _getPageInfo() async {
    try {
      final url = await _webviewController.getUrl();
      final domResult = await _webviewController.evaluateJavascript(
        source: _domSimplifyJs,
      );
      LoggerService.instance.i(
        '获取页面信息: ${url?.toString() ?? ""} (domLen=${(domResult ?? '').length})',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'get_page_info'],
      );
      return jsonEncode({
        'url': url?.toString() ?? '',
        'dom': domResult ?? '',
      });
    } catch (e) {
      return jsonEncode({'error': 'fetch_failed', 'message': e.toString()});
    }
  }

  /// 在 WebView 中执行 JS 脚本
  Future<String> _executeJs(Map<String, dynamic> args) async {
    final script = args['script'] as String?;
    if (script == null || script.isEmpty) {
      return jsonEncode({'error': 'missing_param', 'message': '缺少 script 参数'});
    }
    try {
      final result = await _webviewController.evaluateJavascript(source: script);
      LoggerService.instance.i(
        '执行 JS 成功: resultLen=${(result ?? '').length}',
        category: LogCategory.ai,
        tags: ['agent', 'webview-extract', 'execute_js'],
      );
      return result ?? jsonEncode({'result': null});
    } catch (e) {
      return jsonEncode({'error': 'js_execution_failed', 'message': e.toString()});
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
      return jsonEncode({'error': 'missing_domain', 'message': '无法确定域名'});
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
        'message': '该域名无缓存脚本',
      });
    }

    final scripts = results.map((row) => {
          'id': row['id'],
          'domain': row['domain'],
          'urlPattern': row['url_pattern'],
          'chapterListJs': row['chapter_list_js'],
          'chapterContentJs': row['chapter_content_js'],
          'useCount': row['use_count'],
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
  Future<String> _saveScript(Map<String, dynamic> args) async {
    final domain = args['domain'] as String?;
    final chapterListJs = args['chapter_list_js'] as String?;
    final chapterContentJs = args['chapter_content_js'] as String?;
    final urlPattern = args['url_pattern'] as String? ?? '';

    if (domain == null || chapterListJs == null || chapterContentJs == null) {
      return jsonEncode({
        'error': 'missing_param',
        'message': '缺少 domain/chapter_list_js/chapter_content_js 参数',
      });
    }

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

  // ===== 工具定义（OpenAI Function Calling schema）=====

  static const _getPageInfoTool = {
    'type': 'function',
    'function': {
      'name': 'get_page_info',
      'description': '获取当前浏览器页面的 URL 和精简后的 DOM 结构。用于分析页面布局、找到小说目录或内容区域。',
      'parameters': {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
    },
  };

  static const _executeJsTool = {
    'type': 'function',
    'function': {
      'name': 'execute_js',
      'description': '在当前 WebView 页面中执行 JavaScript 脚本并返回结果。用于测试生成的提取脚本。',
      'parameters': {
        'type': 'object',
        'properties': {
          'script': {
            'type': 'string',
            'description': '要执行的 JavaScript 代码。应是一个 async IIFE，返回 JSON.stringify(结果)。',
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
      'description': '查询指定域名是否已有缓存的提取脚本。如果有则返回脚本内容，可直接复用。',
      'parameters': {
        'type': 'object',
        'properties': {
          'domain': {
            'type': 'string',
            'description': '要查询的域名（如 www.example.com）。不填则使用当前页面域名。',
          },
        },
        'required': <String>[],
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
        'required': <String>[],
      },
    },
  };
}
