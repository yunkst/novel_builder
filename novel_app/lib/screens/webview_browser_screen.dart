import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/providers/webview_providers.dart';
import '../core/theme/app_colors.dart';
import '../services/browser_settings_service.dart';
import '../widgets/webview_address_bar.dart';
import '../widgets/bookmark_panel.dart';
import '../widgets/site_script_panel.dart';
import '../widgets/webview_add_novel_button.dart';
import 'model_download_manager_screen.dart';

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
                        case 'download':
                          _showDownloadManager(context);
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
                      const PopupMenuItem<String>(
                        value: 'download',
                        child: Text('模型下载管理'),
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
                    onWebViewCreated: (controller) {
                      notifier.setController(controller);
                    },
                    onLoadStart: (controller, url) {
                      notifier.handleLoadStart(url);
                    },
                    onLoadStop: (controller, url) {
                      notifier.handleLoadStop(url);
                      // 桌面模式：覆盖 viewport meta 到桌面宽，让宽度判断型
                      // 站点切桌面布局。仅改 viewport，不影响 UA / 缩放配置。
                      final isDesktop =
                          ref.read(browserDesktopModeProvider).value ?? false;
                      if (isDesktop) {
                        controller.evaluateJavascript(
                          source: BrowserSettingsService
                              .desktopViewportOverrideJs,
                        );
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      notifier.handleProgress(progress);
                    },
                    onReceivedError: (controller, request, error) {
                      notifier.handleError(error);
                    },
                    onDownloadStartRequest: (controller, request) {
                      notifier.handleDownloadStart(
                        url: request.url.toString(),
                        context: context,
                        ref: ref,
                        sourcePage: ref.read(webviewCurrentUrlProvider),
                      );
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

  /// 跳转到模型下载管理页
  void _showDownloadManager(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ModelDownloadManagerScreen(),
      ),
    );
  }
}
