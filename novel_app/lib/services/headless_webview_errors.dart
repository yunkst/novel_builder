/// Headless WebView 错误类型
///
/// 集中管理 Headless WebView 相关错误，避免在多个调用方之间复制
/// 错误消息字符串。新的错误类型应在这里扩展，并提供 i18n hook。
library;

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
