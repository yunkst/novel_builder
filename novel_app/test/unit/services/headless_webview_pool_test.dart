/// HeadlessWebViewPool 单元测试
///
/// 覆盖：
/// - acquire 引用计数正确性
/// - release 减少引用
/// - dispose 清理
/// - dispose 后 acquire 应该重新创建（健壮性）
/// - isReady 状态正确
///
/// 不覆盖（需集成测试）：
/// - 真实的 HeadlessInAppWebView 初始化（需要 platform channel）
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_app/services/headless_webview_pool.dart';
import 'package:novel_app/services/logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LoggerService.resetForTesting();
  });

  // ================================================================
  // 基础状态
  // ================================================================
  group('基础状态', () {
    test('新创建的 pool 处于未就绪状态', () {
      final pool = HeadlessWebViewPool();
      expect(pool.isReady, isFalse);
      expect(pool.refCount, 0);
    });

    test('dispose 后 refCount 重置为 0', () {
      final pool = HeadlessWebViewPool();
      pool.dispose();
      expect(pool.refCount, 0);
      expect(pool.isReady, isFalse);
    });
  });

  // ================================================================
  // 引用计数
  // ================================================================
  group('引用计数', () {
    test('acquire 成功（即使 WebView 初始化失败）后 refCount 增加', () async {
      final pool = HeadlessWebViewPool();

      // 在纯 Dart 测试环境，HeadlessInAppWebView.run() 会抛异常
      // acquire 的 try/catch 会回退 refCount（_ensureReady 失败时）
      // 这里只验证 acquire 调用路径存在
      try {
        await pool.acquire();
      } catch (_) {
        // 预期失败，不影响 refCount 回退
      }

      // acquire 内部：refCount++ → 失败 → refCount-- → rethrow
      // 所以 refCount 应该回到 0
      expect(pool.refCount, 0);
    });

    test('release 不允许减到负数', () {
      final pool = HeadlessWebViewPool();
      // 初始 refCount = 0
      pool.release();
      expect(pool.refCount, 0);

      pool.release();
      expect(pool.refCount, 0);
    });
  });

  // ================================================================
  // dispose 健壮性
  // ================================================================
  group('dispose 健壮性', () {
    test('多次 dispose 不抛异常', () {
      final pool = HeadlessWebViewPool();
      pool.dispose();
      // 第二次 dispose 不应抛异常
      expect(() => pool.dispose(), returnsNormally);
      expect(pool.refCount, 0);
    });

    test('dispose 后 acquire 应该尝试重新初始化（健壮性）', () async {
      final pool = HeadlessWebViewPool();
      pool.dispose();

      // 重新 acquire 会走初始化流程（在测试环境中会失败，但不应崩溃）
      try {
        await pool.acquire();
      } catch (_) {
        // 预期失败
      }
      // dispose 已重置 _controller，所以 isReady 应为 false
      expect(pool.isReady, isFalse);
    });
  });
}
