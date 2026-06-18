/// Headless WebView 章节列表获取服务
///
/// 当某个域名已有 AI Agent 生成的 `chapter_list_js` 提取脚本时，
/// 本服务使用 HeadlessInAppWebView 直接加载章节列表页面并执行脚本获取章节列表，
/// 不再依赖后端 API。
///
/// ## 工作流程
///
/// ```
/// fetchChapterList(novelUrl)
///   → SiteScriptRepository.getByDomain(domain)
///   → 无脚本 → return null（上游提示用户）
///   → 有脚本 → HeadlessInAppWebView.loadUrl(novelUrl)
///              → onLoadStop → callAsyncJavaScript(chapter_list_js)
///              → 解析 JSON {title, chapters}
///              → 校验 chapters 非空
///              → return List<Chapter>
/// ```
///
/// ## 复用
///
/// - [HeadlessWebViewPool] — 共享 headless WebView 实例
/// - [WebViewJsExecutor] — 脚本校验、IIFE 提取、结果解析
/// - [SiteScriptRepository] — 域名脚本查询
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/chapter.dart';
import '../repositories/site_script_repository.dart';
import '../services/logger_service.dart';
import '../services/novel_agent/scenarios/webview_js_executor.dart';
import 'headless_webview_pool.dart';

class HeadlessWebViewChapterListService {
  final SiteScriptRepository _scriptRepo;
  final HeadlessWebViewPool _pool;

  HeadlessWebViewChapterListService({
    required SiteScriptRepository scriptRepo,
    required HeadlessWebViewPool pool,
  })  : _scriptRepo = scriptRepo,
        _pool = pool;

  bool _isFetching = false;

  // ===== 脚本健康度追踪 =====

  final Map<String, int> _scriptFailureCount = {};
  static const int _maxConsecutiveFailures = 3;

  // ===== 公开 API =====

  /// 尝试用 Headless WebView 获取章节列表。
  ///
  /// 返回 `null` 表示该域名无提取脚本，应由上游提示用户。
  /// 返回 `List<Chapter>` 表示获取成功。
  /// 抛异常表示脚本执行失败。
  Future<List<Chapter>?> fetchChapterList(String novelUrl) async {
    if (_isFetching) {
      LoggerService.instance.d(
        'HeadlessWebViewChapterList: 互斥命中，跳过 url=$novelUrl',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'mutex'],
      );
      return null;
    }

    // 1. 查找该域名的提取脚本
    final domain = _extractDomain(novelUrl);
    if (domain == null) return null;

    final script = await _scriptRepo.getByDomain(domain);
    if (script == null || !script.hasChapterListJs) return null;

    // 在 try 之前捕获 script.id，避免 catch 中重复查库
    final scriptId = script.id;

    _isFetching = true;
    var acquired = false;
    try {
      LoggerService.instance.i(
        'HeadlessWebViewChapterList: 开始获取 domain=$domain url=$novelUrl',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'fetch'],
      );

      // 2. 获取 headless WebView controller
      final controller = await _pool.acquire();
      acquired = true;

      // 3. 加载页面
      await _loadPage(controller, novelUrl);

      // 4. 执行提取脚本
      final chapters = await _executeChapterListScript(
        controller,
        script.chapterListJs,
        novelUrl,
      );

      // 5. 校验结果
      if (chapters.isEmpty) {
        _recordFailure(scriptId);
        LoggerService.instance.w(
          'HeadlessWebViewChapterList: 脚本返回空章节列表 domain=$domain',
          category: LogCategory.cache,
          tags: ['headless-webview', 'chapter-list', 'empty-result'],
        );
        return null;
      }

      // 6. 成功 → 清除失败计数，标记已使用
      _recordSuccess(scriptId);

      LoggerService.instance.i(
        'HeadlessWebViewChapterList: 获取成功 domain=$domain count=${chapters.length}',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'success'],
      );

      return chapters;
    } catch (e) {
      _recordFailure(scriptId);
      LoggerService.instance.w(
        'HeadlessWebViewChapterList: 获取失败 domain=$domain error=$e',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'error'],
      );
      rethrow;
    } finally {
      _isFetching = false;
      // 只在 acquire 成功后才 release，避免 refCount 下溢
      if (acquired) {
        _pool.release();
      }
    }
  }

  // ===== 内部实现 =====

  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : null;
    } catch (_) {
      return null;
    }
  }

  /// 加载页面，等待 onLoadStop
  Future<void> _loadPage(
    dynamic controller,
    String url,
  ) async {
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );

    // 轮询等待页面加载（每 500ms 检查一次，最多 30s）
    final start = DateTime.now();
    while (DateTime.now().difference(start) < const Duration(seconds: 30)) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final currentUrl = await controller.getUrl();
        if (currentUrl != null && currentUrl.toString() == url) {
          await Future.delayed(const Duration(milliseconds: 500));
          return;
        }
      } catch (e) {
        LoggerService.instance.d(
          'HeadlessWebViewChapterList: 页面加载轮询 getUrl 失败 $e',
          category: LogCategory.cache,
          tags: ['headless-webview', 'chapter-list', 'load_page', 'poll'],
        );
      }
    }

    LoggerService.instance.w(
      'HeadlessWebViewChapterList: 页面加载超时 url=$url',
      category: LogCategory.cache,
      tags: ['headless-webview', 'chapter-list', 'load-timeout'],
    );
  }

  /// 执行 chapter_list_js 提取脚本
  Future<List<Chapter>> _executeChapterListScript(
    dynamic controller,
    String scriptTemplate,
    String pageUrl,
  ) async {
    // 校验脚本
    final validationError = WebViewJsExecutor.validateScript(scriptTemplate);
    if (validationError != null) {
      LoggerService.instance.w(
        'HeadlessWebViewChapterList: 脚本校验失败 $validationError',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'validation'],
      );
      return [];
    }

    // 替换 {{URL}} → 实际 URL
    final resolvedScript = scriptTemplate.replaceAll('{{URL}}', pageUrl);

    // 提取 IIFE 函数体
    final functionBody =
        WebViewJsExecutor.extractAsyncFunctionBody(resolvedScript);

    // 执行
    dynamic result;
    try {
      result = await controller
          .callAsyncJavaScript(functionBody: functionBody)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      LoggerService.instance.w(
        'HeadlessWebViewChapterList: 脚本执行超时（60s） pageUrl=$pageUrl',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'execute_timeout'],
      );
      return [];
    }

    if (result == null) return [];

    if (result.error != null) {
      LoggerService.instance.w(
        'HeadlessWebViewChapterList: JS执行错误 ${result.error}',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'js-error'],
      );
      return [];
    }

    // 解析返回值
    final jsonStr = WebViewJsExecutor.stringifyJsResult(result.value);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final chaptersRaw = data['chapters'] as List<dynamic>?;
    if (chaptersRaw == null || chaptersRaw.isEmpty) {
      LoggerService.instance.w(
        'HeadlessWebViewChapterList: 脚本返回空 chapters pageUrl=$pageUrl',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'empty_result'],
      );
      return [];
    }

    final chapters = <Chapter>[];
    for (int i = 0; i < chaptersRaw.length; i++) {
      final c = chaptersRaw[i];
      if (c is! Map) continue;
      final title = c['title']?.toString().trim();
      final url = c['url']?.toString().trim();
      if (title != null && title.isNotEmpty && url != null && url.isNotEmpty) {
        chapters.add(Chapter(title: title, url: url, chapterIndex: i));
      }
    }

    return chapters;
  }

  // ===== 脚本健康度 =====

  void _recordFailure(String scriptId) {
    final count = (_scriptFailureCount[scriptId] ?? 0) + 1;
    _scriptFailureCount[scriptId] = count;

    if (count >= _maxConsecutiveFailures) {
      LoggerService.instance.w(
        'HeadlessWebViewChapterList: 脚本连续失败$count次，自动标记 unverified id=$scriptId',
        category: LogCategory.cache,
        tags: ['headless-webview', 'chapter-list', 'auto-disable'],
      );
      _scriptRepo.setVerified(scriptId, false);
    }
  }

  void _recordSuccess(String scriptId) {
    _scriptFailureCount.remove(scriptId);
    _scriptRepo.markUsed(scriptId);
  }
}
