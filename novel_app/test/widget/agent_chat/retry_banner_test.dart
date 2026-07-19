/// RetryBanner widget 测试
///
/// 验证:
/// - RetrySignals.notifier null → 不渲染横幅
/// - 报告 transport → "网络重试 N/8" + 错误类别
/// - 报告 round → "回合重试 N/2"
/// - delayMs ≤ 1000 → "重试中"(无秒数)
/// - clear → 横幅消失
///
/// 运行:
///   cd novel_app
///   flutter test test/widget/agent_chat/retry_banner_test.dart
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/utils/retry_helper.dart';
import 'package:novel_app/widgets/agent_chat/retry_banner.dart';

Widget _harness(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    RetrySignals.instance.resetForTest();
  });
  tearDown(() => RetrySignals.instance.resetForTest());

  testWidgets('null state → 不渲染横幅', (tester) async {
    await tester.pumpWidget(_harness(const RetryBanner()));
    expect(find.byType(RetryBanner), findsOneWidget);
    expect(find.textContaining('重试'), findsNothing);
  });

  testWidgets('transport → "网络重试 N/8" + 错误类别', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 3,
      maxAttempts: 8,
      delayMs: 5000,
      error: const RetryableHttpException(429, '', ''),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();

    expect(find.textContaining('网络重试 3/8'), findsOneWidget);
    expect(find.textContaining('限流'), findsOneWidget);
  });

  testWidgets('round → "回合重试 N/2"', (tester) async {
    RetrySignals.instance.reportRound(
      attempt: 1,
      maxAttempts: 2,
      delayMs: 3000,
      error: const SocketException('x'),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();

    expect(find.textContaining('回合重试 1/2'), findsOneWidget);
    expect(find.textContaining('网络断开'), findsOneWidget);
  });

  testWidgets('delayMs ≤ 1000 → 显示「重试中」(无秒数)', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 2,
      maxAttempts: 8,
      delayMs: 500,
      error: const RetryableHttpException(503, '', ''),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();

    expect(find.textContaining('重试中'), findsOneWidget);
    // delayMs≤1000 不会显示「X s 后重试」
    expect(find.textContaining('s 后重试'), findsNothing);
  });

  testWidgets('clear → 横幅消失', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 1,
      maxAttempts: 8,
      delayMs: 5000,
      error: const RetryableHttpException(503, '', ''),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();
    expect(find.textContaining('网络重试 1/8'), findsOneWidget);

    RetrySignals.instance.clear();
    await tester.pump();
    expect(find.textContaining('网络重试'), findsNothing);
  });

  testWidgets('倒计时：delayMs=3000 → 显示 "3 s 后重试"', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 1,
      maxAttempts: 8,
      delayMs: 3000,
      error: const SocketException('x'),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();
    // 初始状态：_remainingSeconds = ceil(3000/1000) = 3
    expect(find.textContaining('3 s 后重试'), findsOneWidget);
    expect(find.textContaining('网络重试 1/8'), findsOneWidget);
  });

  testWidgets('倒计时归零 → 显示「重试中」', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 1,
      maxAttempts: 8,
      delayMs: 1000, // <= 1s 直接显示「重试中」
      error: const SocketException('x'),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();
    // delayMs=1000 → _remainingSeconds=1 → 不启动 Timer，直接「重试中」
    expect(find.textContaining('重试中'), findsOneWidget);
    expect(find.textContaining('s 后重试'), findsNothing);
  });

  testWidgets('httpStatusCode null → 不拼接状态码', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 1,
      maxAttempts: 8,
      delayMs: 5000,
      error: SocketException('x'), // 非 HTTP 错误，httpStatusCode=null
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();

    // 文本包含 errorCategory.label 但不包含多余空格+数字
    expect(find.textContaining('网络断开'), findsOneWidget);
    expect(find.textContaining('网络重试 1/8'), findsOneWidget);
  });
}
