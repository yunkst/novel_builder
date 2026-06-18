/// Headless WebView 错误类型与结果类型
///
/// 集中管理 Headless WebView 相关错误和返回值，避免在多个调用方之间复制
/// 错误消息字符串。新的错误类型应在这里扩展，并提供 i18n hook。
library;

import '../models/chapter_content_result.dart';

// ===== 优先级枚举 =====

/// HeadlessWebView fetchContent 的请求优先级
enum FetchPriority {
  /// 预加载、历史上下文等后台任务
  low,

  /// 阅读器前台请求（可抢占低优先级任务）
  high,
}

// ===== 结果类型 =====

/// HeadlessWebView fetchContent 的结果类型
///
/// 替代原来的 `ChapterContentResult?` 返回值，明确区分三种情况：
/// - **成功**：携带 [ChapterContentResult]
/// - **无脚本**：该域名没有提取脚本，不可重试
/// - **忙碌**：WebView 正忙（被互斥拦截），可等待重试
class FetchContentResult {
  final ChapterContentResult? _success;
  final bool _noScript;
  final bool _busy;

  const FetchContentResult._({
    ChapterContentResult? success,
    bool noScript = false,
    bool busy = false,
  })  : _success = success,
        _noScript = noScript,
        _busy = busy;

  /// 成功获取
  factory FetchContentResult.success(ChapterContentResult result) =>
      FetchContentResult._(success: result);

  /// 该域名无提取脚本
  factory FetchContentResult.noScript() =>
      const FetchContentResult._(noScript: true);

  /// WebView 正忙（被互斥拦截）
  factory FetchContentResult.busy() =>
      const FetchContentResult._(busy: true);

  /// 是否获取成功
  bool get isSuccess => _success != null;

  /// 是否无提取脚本
  bool get isNoScript => _noScript;

  /// 是否 WebView 正忙
  bool get isBusy => _busy;

  /// 获取成功结果（仅在 [isSuccess] 为 true 时有效）
  ChapterContentResult get content => _success!;
}

// ===== 异常类型 =====

/// 当目标域名没有 AI Agent 生成的提取脚本时抛出的异常。
///
/// 调用方应提示用户在 WebView 浏览器中访问该网站并运行 AI 提取
/// 功能生成 `chapter_content_js` / `chapter_list_js` 脚本。
class NoExtractionScriptException implements Exception {
  /// 用户可读的错误消息（中文）
  static const String defaultMessage =
      '该网站暂无提取脚本，请在浏览器中打开该网站并使用 AI 提取功能生成脚本';

  final String domain;
  final String? url;

  const NoExtractionScriptException(this.domain, {this.url});

  @override
  String toString() => 'NoExtractionScriptException(domain=$domain, url=$url)';

  /// 用户可读消息
  String get userMessage => defaultMessage;
}

/// 当 WebView 被其他任务占用且无法在重试次数内获取时抛出的异常。
///
/// 与 [NoExtractionScriptException] 不同，这不是脚本缺失问题，
/// 而是资源竞争导致的临时性失败，用户可以稍后重试。
class WebViewBusyException implements Exception {
  /// 用户可读的错误消息（中文）
  static const String defaultMessage = '内容获取服务正忙，请稍后重试';

  final String domain;
  final String? url;

  const WebViewBusyException(this.domain, {this.url});

  @override
  String toString() => 'WebViewBusyException(domain=$domain, url=$url)';

  /// 用户可读消息
  String get userMessage => defaultMessage;
}
