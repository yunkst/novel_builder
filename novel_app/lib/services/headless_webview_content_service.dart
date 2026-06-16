/// Headless WebView 章节内容获取服务
///
/// 当某个域名已有 AI Agent 生成的 `chapter_content_js` 提取脚本时，
/// 本服务使用 HeadlessInAppWebView 直接加载章节页面并执行脚本获取内容，
/// 绕过后端 API → 爬虫链路。
///
/// ## 工作流程
///
/// ```
/// fetchContent(url)
///   → SiteScriptRepository.getByDomain(domain)
///   → 无脚本 → return null（上游回退到 API）
///   → 有脚本 → HeadlessInAppWebView.loadUrl(url)
///              → onLoadStop → callAsyncJavaScript(chapter_content_js)
///              → 解析 JSON {title, content}
///              → 校验 content.length > 50
///              → return ChapterContentResult
/// ```
///
/// ## 复用
///
/// - [WebViewJsExecutor] — 脚本校验、IIFE 提取、结果解析
/// - [SiteScriptRepository] — 域名脚本查询
///
/// ## 资源管理
///
/// - HeadlessInAppWebView 是单例，懒初始化
/// - 超时：页面加载 30s，脚本执行 60s
/// - 连续失败 3 次自动标记脚本 `verified = 0`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/chapter_content_result.dart';
import '../repositories/site_script_repository.dart';
import '../services/logger_service.dart';
import '../services/novel_agent/scenarios/webview_js_executor.dart';

class HeadlessWebViewContentService {
  final SiteScriptRepository _scriptRepo;

  HeadlessWebViewContentService({
    required SiteScriptRepository scriptRepo,
  }) : _scriptRepo = scriptRepo;

  // ===== Headless WebView 单例 =====

  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _controller;
  bool _isInitializing = false;
  bool _isFetching = false;

  // ===== 脚本健康度追踪 =====

  /// 脚本连续失败次数（内存，不持久化）
  final Map<String, int> _scriptFailureCount = {};

  /// 连续失败多少次后自动标记 unverified
  static const int _maxConsecutiveFailures = 3;

  // ===== 公开 API =====

  /// 尝试用 Headless WebView 获取章节内容。
  ///
  /// 返回 `null` 表示该域名无提取脚本，应由上游回退到 API。
  /// 返回 [ChapterContentResult] 表示获取成功。
  /// 抛异常表示脚本执行失败，也应回退。
  Future<ChapterContentResult?> fetchContent(String chapterUrl) async {
    if (_isFetching) return null;

    // 1. 查找该域名的提取脚本
    final domain = _extractDomain(chapterUrl);
    if (domain == null) return null;

    final script = await _scriptRepo.getByDomain(domain);
    if (script == null || !script.hasChapterContentJs) return null;

    // 2. 确保 WebView 就绪
    await _ensureWebView();

    _isFetching = true;
    try {
      LoggerService.instance.i(
        'HeadlessWebView: 开始获取 domain=$domain url=$chapterUrl',
        category: LogCategory.cache,
        tags: ['headless-webview', 'fetch'],
      );

      // 3. 加载页面
      await _loadPage(chapterUrl);

      // 4. 执行提取脚本
      final content = await _executeContentScript(
        script.chapterContentJs,
        chapterUrl,
      );

      // 5. 校验内容
      if (content == null || content.trim().isEmpty) {
        _recordFailure(script.id);
        LoggerService.instance.w(
          'HeadlessWebView: 脚本返回空内容 domain=$domain',
          category: LogCategory.cache,
          tags: ['headless-webview', 'empty-result'],
        );
        return null;
      }

      if (content.trim().length < 50) {
        _recordFailure(script.id);
        LoggerService.instance.w(
          'HeadlessWebView: 内容过短(${content.length}字符) domain=$domain',
          category: LogCategory.cache,
          tags: ['headless-webview', 'short-content'],
        );
        return null;
      }

      // 6. 成功 → 清除失败计数，标记已使用
      _recordSuccess(script.id);

      LoggerService.instance.i(
        'HeadlessWebView: 获取成功 domain=$domain len=${content.length}',
        category: LogCategory.cache,
        tags: ['headless-webview', 'success'],
      );

      return ChapterContentResult(
        content: content,
        fromCache: false, // WebView 每次都是实时获取
      );
    } catch (e) {
      _recordFailure(script.id);
      LoggerService.instance.w(
        'HeadlessWebView: 获取失败 domain=$domain error=$e',
        category: LogCategory.cache,
        tags: ['headless-webview', 'error'],
      );
      return null;
    } finally {
      _isFetching = false;
    }
  }

  /// 释放 WebView 资源
  void dispose() {
    _headlessWebView?.dispose();
    _headlessWebView = null;
    _controller = null;
    _scriptFailureCount.clear();
  }

  // ===== 内部实现 =====

  /// 从 URL 提取域名
  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : null;
    } catch (_) {
      return null;
    }
  }

  /// 确保 HeadlessInAppWebView 已初始化
  Future<void> _ensureWebView() async {
    if (_controller != null) return;
    if (_isInitializing) {
      // 等待初始化完成（简单轮询）
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_controller != null) return;
      }
      throw Exception('HeadlessWebView 初始化超时');
    }

    _isInitializing = true;
    try {
      final completer = Completer<InAppWebViewController>();

      _headlessWebView = HeadlessInAppWebView(
        onWebViewCreated: (controller) {
          if (!completer.isCompleted) {
            completer.complete(controller);
          }
        },
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          // 不加载图片，节省流量和时间
          loadsImagesAutomatically: false,
          // 禁用不需要的功能
          mediaPlaybackRequiresUserGesture: true,
          // 超时由 callAsyncJavaScript 的 timeout 控制
        ),
      );

      await _headlessWebView!.run();
      _controller = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('WebView 创建超时'),
      );

      LoggerService.instance.i(
        'HeadlessWebView: 初始化完成',
        category: LogCategory.cache,
        tags: ['headless-webview', 'init'],
      );
    } catch (e) {
      _isInitializing = false;
      // 初始化失败时清理
      _headlessWebView?.dispose();
      _headlessWebView = null;
      rethrow;
    }
    _isInitializing = false;
  }

  /// 加载页面，等待 onLoadStop
  Future<void> _loadPage(String url) async {

    // 注册一次性 onLoadStop 回调
    // HeadlessInAppWebView 不支持动态添加回调，
    // 所以用 getUrl 轮询检测页面加载完成
    await _controller!.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );

    // 轮询等待页面加载（每 500ms 检查一次，最多 30s）
    final start = DateTime.now();
    while (DateTime.now().difference(start) < const Duration(seconds: 30)) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final currentUrl = await _controller!.getUrl();
        if (currentUrl != null && currentUrl.toString() == url) {
          // 给 DOM 一些稳定时间
          await Future.delayed(const Duration(milliseconds: 500));
          return;
        }
      } catch (_) {
        // 轮询错误继续等待
      }
    }

    // 超时但不抛异常——页面可能已经部分加载，脚本可能仍能工作
    LoggerService.instance.w(
      'HeadlessWebView: 页面加载超时 url=$url',
      category: LogCategory.cache,
      tags: ['headless-webview', 'load-timeout'],
    );
  }

  /// 执行 chapter_content_js 提取脚本
  Future<String?> _executeContentScript(
    String scriptTemplate,
    String pageUrl,
  ) async {
    // 校验脚本
    final validationError = WebViewJsExecutor.validateScript(scriptTemplate);
    if (validationError != null) {
      LoggerService.instance.w(
        'HeadlessWebView: 脚本校验失败 $validationError',
        category: LogCategory.cache,
        tags: ['headless-webview', 'validation'],
      );
      return null;
    }

    // 替换 {{URL}} → 实际 URL
    final resolvedScript = scriptTemplate.replaceAll('{{URL}}', pageUrl);

    // 提取 IIFE 函数体
    final functionBody =
        WebViewJsExecutor.extractAsyncFunctionBody(resolvedScript);

    // 执行
    final result = await _controller!
        .callAsyncJavaScript(functionBody: functionBody)
        .timeout(const Duration(seconds: 60));

    if (result == null) return null;

    if (result.error != null) {
      LoggerService.instance.w(
        'HeadlessWebView: JS执行错误 ${result.error}',
        category: LogCategory.cache,
        tags: ['headless-webview', 'js-error'],
      );
      return null;
    }

    // 解析返回值
    final jsonStr = WebViewJsExecutor.stringifyJsResult(result.value);
    final data = jsonDecode(jsonStr);

    // 兼容两种返回格式：
    // 1. { "title": "...", "content": "..." }
    // 2. 直接字符串内容
    if (data is Map<String, dynamic>) {
      return (data['content'] as String?)?.trim();
    }
    if (data is String) {
      return data.trim();
    }

    return null;
  }

  // ===== 脚本健康度 =====

  void _recordFailure(String scriptId) {
    final count = (_scriptFailureCount[scriptId] ?? 0) + 1;
    _scriptFailureCount[scriptId] = count;

    if (count >= _maxConsecutiveFailures) {
      LoggerService.instance.w(
        'HeadlessWebView: 脚本连续失败$count次，自动标记 unverified id=$scriptId',
        category: LogCategory.cache,
        tags: ['headless-webview', 'auto-disable'],
      );
      _scriptRepo.setVerified(scriptId, false);
    }
  }

  void _recordSuccess(String scriptId) {
    _scriptFailureCount.remove(scriptId);
    _scriptRepo.markUsed(scriptId);
  }
}
