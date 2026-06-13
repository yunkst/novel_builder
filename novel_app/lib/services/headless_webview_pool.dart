/// Headless WebView 池管理器
///
/// 通用 Headless WebView 生命周期管理，供多个场景共享同一个后台 WebView 实例。
///
/// ## 设计背景
///
/// `HeadlessWebViewContentService` 内部自管一个 Headless WebView，专用于"已有脚本时
/// 后台提取章节内容"。当 AI Agent `WebViewExtractScenario` 也要 Headless 化时，
/// 不应再独立创建一个新的 Headless WebView（系统资源开销大、初始化慢）。
/// 因此抽取本池，允许多个调用方共享：
///
/// - `HeadlessWebViewContentService`（已存在，迁移过来）
/// - `WebViewExtractScenario`（改造中，Headless 模式）
///
/// ## 工作流程
///
/// ```
/// acquire()
///   → _controller != null → 直接返回
///   → _isInitializing → 等待轮询
///   → 创建 HeadlessInAppWebView → run() → 等待 onWebViewCreated
/// ```
///
/// ## 资源管理
///
/// - 单例懒初始化，整个 APP 生命周期内只创建一次
/// - 引用计数（_refCount）允许观察使用情况（当前不强制释放）
/// - 单 flight：`acquire()` 并发调用会等待同一个初始化过程
///
/// ## 与原有 service 的关系
///
/// 本池与 `HeadlessWebViewContentService` 解耦：service 仍可独立持有自己的
/// Headless WebView；本池专供 Agent 提取场景使用，避免耦合迁移成本。
/// 后续如需统一，可以把 service 改为从池获取（向后兼容预留）。
library;

import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logger_service.dart';

/// Headless WebView 池：单例懒初始化，复用同一 WebView 实例
class HeadlessWebViewPool {
  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _controller;
  bool _isInitializing = false;
  int _refCount = 0;

  /// 是否已就绪
  bool get isReady => _controller != null;

  /// 获取一个 Headless WebView controller。
  ///
  /// 第一次调用会执行初始化（约 1-3 秒）；后续调用立即返回同一个 controller。
  /// 并发调用会等待同一个初始化过程。
  ///
  /// 抛异常表示初始化失败。
  Future<InAppWebViewController> acquire() async {
    _refCount++;
    try {
      await _ensureReady();
      return _controller!;
    } catch (e) {
      _refCount--;
      rethrow;
    }
  }

  /// 释放（仅减少引用计数，不真正销毁，因为通常保活整个 APP 生命周期）
  void release() {
    if (_refCount > 0) _refCount--;
  }

  /// 当前引用计数
  int get refCount => _refCount;

  /// 销毁（理论上不需要，由 Riverpod 生命周期管理）
  void dispose() {
    _headlessWebView?.dispose();
    _headlessWebView = null;
    _controller = null;
    _refCount = 0;
  }

  // ===== 内部 =====

  Future<void> _ensureReady() async {
    if (_controller != null) return;

    if (_isInitializing) {
      // 等待初始化完成（每 500ms 轮询，最多 30s）
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_controller != null) return;
      }
      throw Exception('HeadlessWebViewPool 初始化超时');
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
        ),
      );

      await _headlessWebView!.run();
      _controller = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('WebView 创建超时'),
      );

      LoggerService.instance.i(
        'HeadlessWebViewPool: 初始化完成',
        category: LogCategory.cache,
        tags: ['headless-webview-pool', 'init'],
      );
    } catch (e) {
      _isInitializing = false;
      // 初始化失败时清理
      _headlessWebView?.dispose();
      _headlessWebView = null;
      _controller = null;
      LoggerService.instance.e(
        'HeadlessWebViewPool: 初始化失败 $e',
        category: LogCategory.cache,
        tags: ['headless-webview-pool', 'init', 'error'],
      );
      rethrow;
    }
    _isInitializing = false;
  }
}

/// 全局 Headless WebView 池 Provider（keepAlive，APP 级别单例）
final headlessWebViewPoolProvider = Provider<HeadlessWebViewPool>((ref) {
  final pool = HeadlessWebViewPool();
  ref.onDispose(() => pool.dispose());
  return pool;
});
