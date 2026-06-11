import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/site_script.dart';
import '../../services/logger_service.dart';
import '../../services/bookmark_service.dart';
import 'database_providers.dart';

/// 当前显示的 URL（地址栏订阅）
final webviewCurrentUrlProvider = StateProvider<String>(
  (ref) => 'https://so.com',
);

/// 加载进度 0.0~1.0
final webviewLoadingProgressProvider = StateProvider<double>((ref) => 0.0);

/// 是否正在加载
final webviewIsLoadingProvider = StateProvider<bool>((ref) => false);

/// InAppWebViewController 持有者
/// 整个屏幕生命周期内复用同一个 controller 实例
final webviewControllerProvider =
    StateNotifierProvider<WebViewControllerNotifier, InAppWebViewController?>(
  (ref) => WebViewControllerNotifier(ref),
);

/// WebView Controller 状态管理
class WebViewControllerNotifier
    extends StateNotifier<InAppWebViewController?> {
  final Ref _ref;

  WebViewControllerNotifier(this._ref) : super(null);

  /// 由 InAppWebView 的 onWebViewCreated 回调设置 Controller
  void setController(InAppWebViewController controller) {
    state = controller;
  }

  /// 重置 Controller（页面销毁时调用）
  void resetController() {
    state = null;
  }

  /// 页面开始加载
  void handleLoadStart(WebUri? url) {
    _ref.read(webviewCurrentUrlProvider.notifier).state =
        url?.toString() ?? '';
    _ref.read(webviewIsLoadingProvider.notifier).state = true;
  }

  /// 页面加载完成
  void handleLoadStop(WebUri? url) {
    _ref.read(webviewCurrentUrlProvider.notifier).state =
        url?.toString() ?? '';
    _ref.read(webviewIsLoadingProvider.notifier).state = false;
    _ref.read(webviewLoadingProgressProvider.notifier).state = 1.0;
  }

  /// 加载进度变化
  void handleProgress(int progress) {
    _ref.read(webviewLoadingProgressProvider.notifier).state =
        progress / 100.0;
  }

  /// 资源加载错误
  void handleError(WebResourceError error) {
    LoggerService.instance.e(
      'WebView 资源加载错误: ${error.description} (type: ${error.type})',
      category: LogCategory.network,
      tags: ['webview', 'resource-error'],
    );
  }

  /// 加载指定 URL（自动规范化）
  Future<void> loadUrl(String input) async {
    final url = _normalizeUrl(input);
    await state?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
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
  /// - 小说（无点号）→ 搜索
  /// - https://flutter.dev → 原样
  /// - 空字符串 → so.com
  String _normalizeUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return 'https://so.com';

    // 已有协议前缀，直接使用
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return s;
    }

    // 看起来像域名（含点号且无空格）
    if (s.contains('.') && !s.contains(' ')) {
      return 'https://$s';
    }

    // 否则视为搜索词，使用 360 搜索
    return 'https://so.com/s?q=${Uri.encodeComponent(s)}';
  }
}

// ============================================================
// 收藏夹相关 Providers
// ============================================================

/// 收藏夹列表 Provider
final bookmarkListProvider =
    StateNotifierProvider<BookmarkListNotifier, AsyncValue<List<Bookmark>>>(
  (ref) => BookmarkListNotifier(),
);

/// 收藏夹状态管理
class BookmarkListNotifier extends StateNotifier<AsyncValue<List<Bookmark>>> {
  BookmarkListNotifier() : super(const AsyncValue.loading()) {
    _loadBookmarks();
  }

  /// 初始化加载收藏夹
  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = BookmarkService(prefs);
      final bookmarks = service.loadBookmarks();
      state = AsyncValue.data(bookmarks);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '初始化加载收藏夹失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['bookmark', 'init', 'error'],
      );
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 添加收藏
  Future<void> addBookmark({required String title, required String url}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = BookmarkService(prefs);
      final bookmark = Bookmark(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        url: url,
        createdAt: DateTime.now(),
      );
      await service.addBookmark(bookmark);

      // 刷新列表
      final updated = service.loadBookmarks();
      state = AsyncValue.data(updated);

      LoggerService.instance.i(
        '添加收藏: $title ($url)',
        category: LogCategory.database,
        tags: ['bookmark', 'add'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '添加收藏失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['bookmark', 'add', 'error'],
      );
    }
  }

  /// 删除收藏
  Future<void> removeBookmark(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final service = BookmarkService(prefs);
      await service.removeBookmark(id);

      // 刷新列表
      final updated = service.loadBookmarks();
      state = AsyncValue.data(updated);

      LoggerService.instance.i(
        '删除收藏: id=$id',
        category: LogCategory.database,
        tags: ['bookmark', 'remove'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除收藏失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['bookmark', 'remove', 'error'],
      );
    }
  }

  /// 检查 URL 是否已收藏
  bool isBookmarked(String url) {
    return state.value?.any((b) => b.url == url) ?? false;
  }
}

// ============================================================
// 站点脚本相关 Providers
// ============================================================

/// 脚本列表 Provider
final siteScriptListProvider = StateNotifierProvider<SiteScriptListNotifier,
    AsyncValue<List<SiteScript>>>(
  (ref) => SiteScriptListNotifier(ref),
);

/// 脚本列表状态管理
class SiteScriptListNotifier
    extends StateNotifier<AsyncValue<List<SiteScript>>> {
  final Ref _ref;

  SiteScriptListNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadScripts();
  }

  /// 初始化加载脚本列表
  Future<void> _loadScripts() async {
    try {
      final repository = _ref.read(siteScriptRepositoryProvider);
      final scripts = await repository.getAll();
      state = AsyncValue.data(scripts);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '加载脚本列表失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'load', 'error'],
      );
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 删除脚本
  Future<void> deleteScript(String id) async {
    try {
      final repository = _ref.read(siteScriptRepositoryProvider);
      await repository.delete(id);
      await _loadScripts();
      LoggerService.instance.i(
        '删除脚本: id=$id',
        category: LogCategory.database,
        tags: ['site_script', 'delete'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除脚本失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'delete', 'error'],
      );
    }
  }

  /// 删除域名的所有脚本
  Future<void> deleteScriptByDomain(String domain) async {
    try {
      final repository = _ref.read(siteScriptRepositoryProvider);
      await repository.deleteByDomain(domain);
      await _loadScripts();
      LoggerService.instance.i(
        '删除域名脚本: domain=$domain',
        category: LogCategory.database,
        tags: ['site_script', 'delete', 'domain'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除域名脚本失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'delete', 'domain', 'error'],
      );
    }
  }

  /// 标记脚本已验证
  Future<void> verifyScript(String id) async {
    try {
      final repository = _ref.read(siteScriptRepositoryProvider);
      await repository.setVerified(id, true);
      await repository.markUsed(id);
      await _loadScripts();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '验证脚本失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'verify', 'error'],
      );
    }
  }

  /// 刷新脚本列表
  void refresh() => _loadScripts();
}
