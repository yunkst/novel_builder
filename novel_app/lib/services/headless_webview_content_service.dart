/// Headless WebView 章节内容获取服务
///
/// 当某个域名已有 AI Agent 生成的 `chapter_content_js` 提取脚本时，
/// 本服务使用 HeadlessInAppWebView 直接加载章节页面并执行脚本获取内容，
/// 绕过后端 API → 爬虫链路。
///
/// ## 工作流程
///
/// ```
/// fetchContent(url, priority)
///   → SiteScriptRepository.getByDomain(domain)
///   → 无脚本 → return FetchContentResult.noScript()
///   → 有脚本 → 检查 _isFetching
///              → 忙且可抢占 → 设置 _shouldYield，等待让出
///              → 忙且不可抢占 → return FetchContentResult.busy()
///              → 空闲 → HeadlessInAppWebView.loadUrl(url)
///                       → callAsyncJavaScript(chapter_content_js)
///                       → 解析 JSON {title, content}
///                       → 校验 content.length > 50
///                       → return FetchContentResult.success(...)
/// ```
///
/// ## 优先级抢占
///
/// - 阅读器前台请求使用 [FetchPriority.high]，可抢占预加载的 [FetchPriority.low] 任务
/// - 被抢占的低优先级请求在下一个检查点（页面加载后 / 脚本执行中每 3 秒）退出
/// - 高优先级请求等待低优先级让出，最多 5 秒
///
/// ## 资源管理
///
/// - HeadlessInAppWebView 是单例，懒初始化
/// - 超时：页面加载 30s，脚本执行 60s（3 秒粒度检查抢占信号）
/// - 连续失败 3 次自动标记脚本 `verified = 0`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/chapter_content_result.dart';
import '../repositories/site_script_repository.dart';
import '../services/logger_service.dart';
import '../services/novel_agent/scenarios/webview_js_executor.dart';
import 'headless_webview_errors.dart';

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

  // ===== 优先级抢占 =====

  /// 当前正在执行的请求的优先级
  FetchPriority _currentPriority = FetchPriority.low;

  /// 当前正在执行的请求的 URL（用于日志）
  String? _currentFetchingUrl;

  /// 低优先级请求是否应该让出（被高优先级抢占时设为 true）
  bool _shouldYield = false;

  // ===== 脚本健康度追踪 =====

  /// 脚本连续失败次数（内存，不持久化）
  final Map<String, int> _scriptFailureCount = {};

  /// 连续失败多少次后自动标记 unverified
  static const int _maxConsecutiveFailures = 3;

  // ===== 公开 API =====

  /// 尝试用 Headless WebView 获取章节内容。
  ///
  /// [priority] 请求优先级，默认 [FetchPriority.low]。
  ///   - [FetchPriority.high]：阅读器前台请求，可抢占正在执行的低优先级任务
  ///   - [FetchPriority.low]：预加载、历史上下文等后台任务
  ///
  /// 返回 [FetchContentResult] 明确区分三种情况：
  /// - `isSuccess`：获取成功，通过 `.content` 获取结果
  /// - `isNoScript`：该域名无提取脚本，不可重试
  /// - `isBusy`：WebView 正忙（被互斥拦截），可等待重试
  Future<FetchContentResult> fetchContent(
    String chapterUrl, {
    FetchPriority priority = FetchPriority.low,
  }) async {
    // ===== 互斥检查 + 优先级抢占 =====
    if (_isFetching) {
      if (priority == FetchPriority.high &&
          _currentPriority == FetchPriority.low) {
        // 高优先级抢占：通知当前低优先级请求让出
        _shouldYield = true;
        LoggerService.instance.i(
          'HeadlessWebView: 高优先级请求抢占，通知低优先级让出 '
          'newUrl=$chapterUrl currentUrl=$_currentFetchingUrl',
          category: LogCategory.cache,
          tags: ['headless-webview', 'preempt'],
        );
        // 等待低优先级请求退出
        final yielded = await _waitForYield();
        if (!yielded) {
          // 等待超时，返回 busy
          LoggerService.instance.w(
            'HeadlessWebView: 等待让出超时，返回 busy',
            category: LogCategory.cache,
            tags: ['headless-webview', 'yield-timeout'],
          );
          return FetchContentResult.busy();
        }
      } else {
        // 无法抢占（同级或低抢高），返回 busy
        LoggerService.instance.w(
          'HeadlessWebView: WebView 忙碌，无法抢占 '
          'priority=$priority currentPriority=$_currentPriority',
          category: LogCategory.cache,
          tags: ['headless-webview', 'busy'],
        );
        return FetchContentResult.busy();
      }
    }

    // 1. 查找该域名的提取脚本
    final domain = _extractDomain(chapterUrl);
    if (domain == null) return FetchContentResult.noScript();

    final script = await _scriptRepo.getByDomain(domain);
    if (script == null || !script.hasChapterContentJs) {
      return FetchContentResult.noScript();
    }

    // 2. 确保 WebView 就绪
    await _ensureWebView();

    _isFetching = true;
    _currentPriority = priority;
    _currentFetchingUrl = chapterUrl;
    _shouldYield = false;

    try {
      LoggerService.instance.i(
        'HeadlessWebView: 开始获取 domain=$domain url=$chapterUrl '
        'priority=$priority',
        category: LogCategory.cache,
        tags: ['headless-webview', 'fetch'],
      );

      // 3. 加载页面
      await _loadPage(chapterUrl);

      // 抢占检查点：页面加载后
      if (_shouldYield) {
        LoggerService.instance.i(
          'HeadlessWebView: 页面加载后被抢占让出 url=$chapterUrl',
          category: LogCategory.cache,
          tags: ['headless-webview', 'yield'],
        );
        return FetchContentResult.busy();
      }

      // 4. 执行提取脚本
      final content = await _executeContentScript(
        script.chapterContentJs,
        chapterUrl,
      );

      // 抢占检查点：脚本执行后
      if (_shouldYield) {
        LoggerService.instance.i(
          'HeadlessWebView: 脚本执行后被抢占让出 url=$chapterUrl',
          category: LogCategory.cache,
          tags: ['headless-webview', 'yield'],
        );
        return FetchContentResult.busy();
      }

      // 5. 校验内容
      if (content == null || content.trim().isEmpty) {
        _recordFailure(script.id);
        LoggerService.instance.w(
          'HeadlessWebView: 脚本返回空内容 domain=$domain',
          category: LogCategory.cache,
          tags: ['headless-webview', 'empty-result'],
        );
        return FetchContentResult.noScript();
      }

      if (content.trim().length < 50) {
        _recordFailure(script.id);
        LoggerService.instance.w(
          'HeadlessWebView: 内容过短(${content.length}字符) domain=$domain',
          category: LogCategory.cache,
          tags: ['headless-webview', 'short-content'],
        );
        return FetchContentResult.noScript();
      }

      // 6. 成功 → 清除失败计数，标记已使用
      _recordSuccess(script.id);

      LoggerService.instance.i(
        'HeadlessWebView: 获取成功 domain=$domain len=${content.length}',
        category: LogCategory.cache,
        tags: ['headless-webview', 'success'],
      );

      return FetchContentResult.success(
        ChapterContentResult(content: content, fromCache: false),
      );
    } catch (e, stackTrace) {
      _recordFailure(script.id);
      LoggerService.instance.e(
        'HeadlessWebView: 获取失败（catch 返回 noScript，区分于"真无脚本"） domain=$domain scriptId=${script.id} error=$e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.cache,
        tags: ['headless-webview', 'fetch', 'failed_no_script'],
      );
      LoggerService.instance.w(
        'HeadlessWebView: 获取失败 domain=$domain error=$e',
        category: LogCategory.cache,
        tags: ['headless-webview', 'error'],
      );
      return FetchContentResult.noScript();
    } finally {
      _isFetching = false;
      _currentPriority = FetchPriority.low;
      _currentFetchingUrl = null;
    }
  }

  /// 释放 WebView 资源
  void dispose() {
    _headlessWebView?.dispose();
    _headlessWebView = null;
    _controller = null;
    _scriptFailureCount.clear();
  }

  // ===== 优先级抢占 =====

  /// 等待低优先级请求让出 WebView。
  ///
  /// 返回 true 表示成功让出，false 表示等待超时。
  Future<bool> _waitForYield() async {
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_isFetching) return true;
    }
    LoggerService.instance.d(
      'HeadlessWebView: 等待让出超时（5s 轮询）',
      category: LogCategory.cache,
      tags: ['headless-webview', 'wait_yield', 'timeout'],
    );
    return false;
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
      LoggerService.instance.w(
        'HeadlessWebView: 初始化超时（30s 轮询）',
        category: LogCategory.cache,
        tags: ['headless-webview', 'init', 'timeout'],
      );
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
    } catch (e, stackTrace) {
      _isInitializing = false;
      // 初始化失败时清理
      _headlessWebView?.dispose();
      _headlessWebView = null;
      LoggerService.instance.e(
        'HeadlessWebView: 初始化失败 $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.cache,
        tags: ['headless-webview', 'init', 'failed'],
      );
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
      } catch (e) {
        // 轮询错误继续等待
        LoggerService.instance.d(
          'HeadlessWebView: 页面加载轮询 getUrl 失败 $e',
          category: LogCategory.cache,
          tags: ['headless-webview', 'load_page', 'poll'],
        );
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
  ///
  /// 使用 3 秒粒度循环检查抢占信号 [_shouldYield]，
  /// 使低优先级请求最多 3 秒就能响应抢占。
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

    // 执行 — 3 秒粒度检查抢占信号，总超时 60 秒
    final resultFuture = _controller!
        .callAsyncJavaScript(functionBody: functionBody);

    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await resultFuture.timeout(const Duration(seconds: 3));

        // 脚本执行完成，处理结果
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
      } on TimeoutException {
        // 3 秒超时，检查抢占信号
        if (_shouldYield) return null;
        continue;
      }
    }

    // 整体 60 秒超时
    LoggerService.instance.w(
      'HeadlessWebView: 脚本执行整体超时（60s） pageUrl=$pageUrl',
      category: LogCategory.cache,
      tags: ['headless-webview', 'execute_script', 'timeout'],
    );
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
