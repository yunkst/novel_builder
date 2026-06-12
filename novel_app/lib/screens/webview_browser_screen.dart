import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/providers/agent_scenario_provider.dart';
import '../core/providers/webview_providers.dart';
import '../services/novel_agent/agent_scenario.dart';
import '../widgets/webview_address_bar.dart';
import '../widgets/bookmark_panel.dart';
import '../widgets/site_script_panel.dart';

/// 浏览器主屏幕
///
/// 布局：
/// - AppBar: 地址栏 + 右侧前进/后退/刷新/收藏夹按钮
/// - 顶部加载进度条（仅在加载中显示）
/// - 主体：InAppWebView 内容
/// - 系统返回手势：有历史时 WebView 后退，无历史时退出浏览器页面
class WebViewBrowserScreen extends ConsumerStatefulWidget {
  const WebViewBrowserScreen({super.key});

  @override
  ConsumerState<WebViewBrowserScreen> createState() =>
      _WebViewBrowserScreenState();
}

class _WebViewBrowserScreenState extends ConsumerState<WebViewBrowserScreen> {
  bool _addressBarFocused = false;

  @override
  void initState() {
    super.initState();
    // 切换到 WebView 提取场景
    ref.read(currentAgentScenarioProvider.notifier).state =
        ScenarioIds.webviewExtract;
  }

  @override
  void deactivate() {
    // 离开浏览器时恢复写作场景（必须在 deactivate 中执行，此时 ref 仍有效）
    ref.read(currentAgentScenarioProvider.notifier).state =
        ScenarioIds.writing;
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(webviewIsLoadingProvider);
    final progress = ref.watch(webviewLoadingProgressProvider);
    final notifier = ref.read(webviewControllerProvider.notifier);

    return PopScope(
      // canPop=false 时拦截系统返回手势，由 onPopInvokedWithResult 处理
      canPop: false,
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
            // 收藏夹按钮
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              tooltip: '收藏夹',
              onPressed: () => _showBookmarkPanel(context, notifier),
            ),
            // 脚本管理按钮
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: '脚本管理',
              onPressed: () => _showScriptPanel(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // 加载进度条
            if (isLoading)
              LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 2,
              ),
            // WebView 主体
            Expanded(
              child: InAppWebView(
                initialUrlRequest:
                    URLRequest(url: WebUri('https://so.com')),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                ),
                onWebViewCreated: (controller) {
                  notifier.setController(controller);
                },
                onLoadStart: (controller, url) {
                  notifier.handleLoadStart(url);
                },
                onLoadStop: (controller, url) {
                  notifier.handleLoadStop(url);
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
      ),
    );
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
