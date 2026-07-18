import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/providers/webview_providers.dart';
import '../core/theme/app_colors.dart';
import '../services/browser_settings_service.dart';
import '../services/logger_service.dart';
import '../widgets/webview_address_bar.dart';
import '../widgets/bookmark_panel.dart';
import '../widgets/site_script_panel.dart';
import '../widgets/webview_add_novel_button.dart';

/// 浏览器主屏幕
///
/// 布局：
/// - AppBar: 地址栏 + 右侧前进/后退/刷新/收藏夹按钮
/// - 顶部加载进度条（仅在加载中显示）
/// - 主体：InAppWebView 内容
/// - 系统返回手势：有历史时 WebView 后退，无历史时退出浏览器页面
///
/// [active] 标记当前浏览器是否为可见的 Tab。在 IndexedStack 常驻布局下，
/// 浏览器即使不可见（offstage）仍挂载在树上，其 PopScope 也会参与返回键分发。
/// 因此仅在 active 时拦截系统返回手势，避免在其他 Tab 误触发 WebView 后退。
class WebViewBrowserScreen extends ConsumerStatefulWidget {
  const WebViewBrowserScreen({super.key, this.active = true});

  /// 当前是否为可见的 Tab
  final bool active;

  @override
  ConsumerState<WebViewBrowserScreen> createState() =>
      _WebViewBrowserScreenState();
}

class _WebViewBrowserScreenState extends ConsumerState<WebViewBrowserScreen> {
  bool _addressBarFocused = false;
  final _addressBarKey = GlobalKey<WebViewAddressBarState>();

  /// 在网页 document 上安装 touchstart/mousedown 监听器，
  /// 用户点击网页任何内容时通过 JS handler 通知 Flutter 取消地址栏焦点。
  static const String _installWebViewTapHandlerJs = '''
(function() {
  if (window.__webViewTapInstalled) return;
  window.__webViewTapInstalled = true;

  function notifyWebViewTapped() {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('onWebViewTouched');
    }
  }

  document.addEventListener('touchstart', notifyWebViewTapped, { passive: true });
  document.addEventListener('mousedown', notifyWebViewTapped, { passive: true });
})();
''';

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(webviewIsLoadingProvider);
    final progress = ref.watch(webviewLoadingProgressProvider);
    final notifier = ref.read(webviewControllerProvider.notifier);
    final desktopMode = ref.watch(browserDesktopModeProvider).value ?? false;

    // 桌面模式变化（含首次 loading->data 与手动 toggle）-> 运行时切换 WebView
    ref.listen<AsyncValue<bool>>(browserDesktopModeProvider, (prev, next) {
      if (next is AsyncData<bool>) {
        ref
            .read(webviewControllerProvider.notifier)
            .applyDesktopMode(next.value);
      }
    });

    return PopScope(
      // 仅在当前 Tab 可见时拦截系统返回手势；不可见时让返回键正常向上传递。
      canPop: !widget.active,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // WebView 有浏览历史 → 后退；没有历史 → 退出浏览器页面
        // 添加超时保护：canGoBack() 是 platform channel 异步调用，
        // 在 Android 某些 WebView 版本上，无历史时可能永久挂起导致 APP 卡死
        bool canBack;
        try {
          canBack = await notifier.canGoBack().timeout(
                const Duration(milliseconds: 500),
              );
        } catch (_) {
          // 超时或异常时，默认认为不能后退，直接退出浏览器页面
          canBack = false;
        }
        if (canBack) {
          try {
            await notifier.goBack().timeout(
                  const Duration(seconds: 3),
                );
          } catch (_) {
            // goBack() 超时，直接退出浏览器页面
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: WebViewAddressBar(
              key: _addressBarKey,
              onFocusChanged: (focused) {
                setState(() => _addressBarFocused = focused);
              },
            ),
          ),
          actions: _addressBarFocused
              ? null
              : [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    tooltip: '后退',
                    onPressed: () => notifier.goBack(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    tooltip: '前进',
                    onPressed: () => notifier.goForward(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新',
                    onPressed: () => notifier.reload(),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: '更多',
                    onSelected: (value) async {
                      switch (value) {
                        case 'bookmark':
                          _showBookmarkPanel(context, notifier);
                          break;
                        case 'script':
                          _showScriptPanel(context);
                          break;
                        case 'desktopMode':
                          await ref
                              .read(browserDesktopModeProvider.notifier)
                              .toggle();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem<String>(
                        value: 'bookmark',
                        child: Text('收藏夹'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'script',
                        child: Text('脚本管理'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'desktopMode',
                        child: Row(
                          children: [
                            Icon(
                              ref.watch(browserDesktopModeProvider).value ??
                                      false
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                            ),
                            const SizedBox(width: 8),
                            const Text('桌面模式'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // 加载进度条
                if (isLoading)
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.appColors.agentAccent,
                    ),
                    backgroundColor:
                        context.appColors.agentAccent.withValues(alpha: 0.15),
                  ),
                // WebView 主体
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest:
                        URLRequest(url: WebUri('https://so.com')),
                    initialSettings: desktopModeSettings(desktopMode),
                    // 桌面模式：viewport 覆盖脚本经 initialUserScripts 在
                    // AT_DOCUMENT_START 注入，对每次导航（含 reload）都会重新执行
                    // （flutter_inappwebview 文档：initial page load and any
                    // subsequent navigations），早于站点 JS，赶在响应式断点首次
                    // 判断前拨正为桌面宽。脚本内自带 UA 自适配，手机 UA 直接 return。
                    initialUserScripts: UnmodifiableListView<UserScript>([
                      UserScript(
                        source: BrowserSettingsService
                            .desktopViewportOverrideJs,
                        // AT_DOCUMENT_START：navigator 覆盖必须早于站点 JS 执行，
                        // 否则站点读取时机已过，覆盖无效。viewport meta 改写内部
                        // 监听了 DOMContentLoaded 兜底。
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                      // 监听网页区域 touchstart/mousedown，回调 Flutter 取消地址栏焦点
                      UserScript(
                        source: _installWebViewTapHandlerJs,
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    ]),
                    onWebViewCreated: (controller) {
                      notifier.setController(controller);
                      // 注册 JS handler：用户点击网页时由网页端调起此 handler，
                      // Flutter 收到后取消地址栏焦点。
                      controller.addJavaScriptHandler(
                        handlerName: 'onWebViewTouched',
                        callback: (arguments) {
                          _unfocusAddressBar();
                          return null;
                        },
                      );
                    },
                    onLoadStart: (controller, url) {
                      notifier.handleLoadStart(url);
                    },
                    onLoadStop: (controller, url) {
                      notifier.handleLoadStop(url);
                      // 桌面模式诊断：读站点实际看到的 UA / platform / viewport / width，
                      // 写 flutter log。验证 initialUserScripts（AT_DOCUMENT_START）是否
                      // 让站点在首次布局前就按桌面宽渲染：width≈1200 即生效；若不是，说明
                      // document-start 注入在该 Android 版本未生效（另查 androidx.webkit 支持）。
                      // 注：onLoadStop 已晚于首次布局，故不再在此重跑 viewport 覆盖兜底——
                      // initialUserScripts 对每次导航都会重新注入（flutter_inappwebview 文档）。
                      final isDesktop =
                          ref.read(browserDesktopModeProvider).value ?? false;
                      if (isDesktop) {
                        controller.evaluateJavascript(source: r'''
(function(){
  var m = document.querySelector('meta[name="viewport"]');
  window.__desktopDiag = JSON.stringify({
    ua: navigator.userAgent,
    platform: navigator.platform,
    maxTouch: navigator.maxTouchPoints,
    viewport: m ? m.content : '(none)',
    width: window.innerWidth,
    url: location.href
  });
  return window.__desktopDiag;
})();
''').then((value) {
                          // evaluateJavascript 返回值已自动 jsonDecode（Android WebView2 行为）
                          LoggerService.instance.d(
                            'WebView 桌面化诊断: $value',
                            category: LogCategory.network,
                            tags: ['webview', 'desktop-mode', 'diag'],
                          );
                        });
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      notifier.handleProgress(progress);
                    },
                    onReceivedError: (controller, request, error) {
                      notifier.handleError(error);
                    },
                  ),
                ),
              ],
            ),
            // 右下角「添加小说」悬浮按钮
            // 仅在当前域名有提取脚本时显示
            const Positioned(
              right: 16,
              bottom: 16,
              child: WebViewAddNovelFab(),
            ),
          ],
        ),
      ),
    );
  }

  /// 取消地址栏焦点（用户在网页内点击时由 JS handler 触发）
  void _unfocusAddressBar() {
    _addressBarKey.currentState?.unfocus();
  }

  /// 弹出收藏夹面板
  void _showBookmarkPanel(
    BuildContext context,
    WebViewControllerNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BookmarkPanel(
        onNavigate: (url) => notifier.loadUrl(url),
      ),
    );
  }

  /// 弹出脚本管理面板
  void _showScriptPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const SiteScriptPanel(),
    );
  }
}
