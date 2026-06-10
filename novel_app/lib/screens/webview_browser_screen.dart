import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/providers/webview_providers.dart';
import '../widgets/webview_address_bar.dart';

/// 浏览器主屏幕
///
/// 布局：
/// - AppBar: 地址栏 + 右侧前进/后退/刷新按钮
/// - 顶部加载进度条（仅在加载中显示）
/// - 主体：WebView 内容
/// - 系统返回手势：有历史时 WebView 后退，无历史时退出浏览器页面
class WebViewBrowserScreen extends ConsumerStatefulWidget {
  const WebViewBrowserScreen({super.key});

  @override
  ConsumerState<WebViewBrowserScreen> createState() =>
      _WebViewBrowserScreenState();
}

class _WebViewBrowserScreenState extends ConsumerState<WebViewBrowserScreen> {
  @override
  void initState() {
    super.initState();
    // 异步初始化 WebView Controller（避免 build 阶段竞争）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webviewControllerProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(webviewControllerProvider);
    final isLoading = ref.watch(webviewIsLoadingProvider);
    final progress = ref.watch(webviewLoadingProgressProvider);
    final notifier = ref.read(webviewControllerProvider.notifier);

    return PopScope(
      // canPop=false 时拦截系统返回手势，由 onPopInvokedWithResult 处理
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // WebView 有浏览历史 → 后退；没有历史 → 退出浏览器页面
        final canBack = await notifier.canGoBack();
        if (canBack) {
          await notifier.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: WebViewAddressBar(),
          ),
          actions: [
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
              child: controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : WebViewWidget(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}
