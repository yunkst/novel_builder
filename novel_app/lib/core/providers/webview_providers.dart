import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/logger_service.dart';

/// 当前显示的 URL（地址栏订阅）
final webviewCurrentUrlProvider = StateProvider<String>(
  (ref) => 'https://www.baidu.com',
);

/// 加载进度 0.0~1.0
final webviewLoadingProgressProvider = StateProvider<double>((ref) => 0.0);

/// 是否正在加载
final webviewIsLoadingProvider = StateProvider<bool>((ref) => false);

/// WebViewController 持有者
/// 整个屏幕生命周期内复用同一个 controller 实例
final webviewControllerProvider =
    StateNotifierProvider<WebViewControllerNotifier, WebViewController?>(
  (ref) => WebViewControllerNotifier(ref),
);

/// WebView Controller 状态管理
class WebViewControllerNotifier extends StateNotifier<WebViewController?> {
  final Ref _ref;

  WebViewControllerNotifier(this._ref) : super(null);

  /// 初始化 WebView Controller（仅调用一次）
  Future<void> init() async {
    if (state != null) return;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onProgress: _handleProgress,
          onWebResourceError: _handleError,
        ),
      )
      ..loadRequest(Uri.parse('https://www.baidu.com'));

    state = controller;
  }

  void _handlePageStarted(String url) {
    _ref.read(webviewCurrentUrlProvider.notifier).state = url;
    _ref.read(webviewIsLoadingProvider.notifier).state = true;
  }

  void _handlePageFinished(String url) {
    _ref.read(webviewCurrentUrlProvider.notifier).state = url;
    _ref.read(webviewIsLoadingProvider.notifier).state = false;
    _ref.read(webviewLoadingProgressProvider.notifier).state = 1.0;
  }

  void _handleProgress(int progress) {
    _ref.read(webviewLoadingProgressProvider.notifier).state =
        progress / 100.0;
  }

  void _handleError(WebResourceError error) {
    LoggerService.instance.e(
      'WebView 资源加载错误: ${error.description} (code: ${error.errorCode})',
      category: LogCategory.network,
      tags: ['webview', 'resource-error'],
    );
  }

  /// 加载指定 URL（自动规范化）
  Future<void> loadUrl(String input) async {
    final url = _normalizeUrl(input);
    await state?.loadRequest(Uri.parse(url));
  }

  /// 后退
  Future<void> goBack() async {
    await state?.goBack();
  }

  /// 是否可以后退（有浏览历史）
  Future<bool> canGoBack() async {
    return await state?.canGoBack() ?? false;
  }

  /// 前进
  Future<void> goForward() async {
    await state?.goForward();
  }

  /// 刷新
  Future<void> reload() async {
    await state?.reload();
  }

  /// URL 规范化
  /// - baidu.com → https://baidu.com
  /// - 小说（无点号）→ 百度搜索
  /// - https://flutter.dev → 原样
  /// - 空字符串 → baidu
  String _normalizeUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return 'https://www.baidu.com';

    // 已有协议前缀，直接使用
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return s;
    }

    // 看起来像域名（含点号且无空格）
    if (s.contains('.') && !s.contains(' ')) {
      return 'https://$s';
    }

    // 否则视为搜索词，使用百度搜索
    return 'https://www.baidu.com/s?wd=${Uri.encodeComponent(s)}';
  }
}
