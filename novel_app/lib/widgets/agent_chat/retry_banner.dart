/// LLM 重试状态横幅 — 钉在 AgentChatDialog 输入栏上方
///
/// 订阅 RetrySignals.instance.notifier;null 时不渲染。
///
/// 配色:transport = 橙(警告)/ round = 蓝(信息)
/// 倒计时:onRetry 给 delayMs,启动 Timer.periodic(1s) 显示
///       delayMs ≤ 1000 或倒计时到 0 → 显示「重试中…」
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';

class RetryBanner extends StatefulWidget {
  const RetryBanner({super.key});

  @override
  State<RetryBanner> createState() => _RetryBannerState();
}

class _RetryBannerState extends State<RetryBanner> {
  Timer? _tickTimer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  /// 每次 state 变化(新一次 onRetry)重新启动倒计时,从 delayMs 重算。
  /// delayMs ≤ 1s 不启动 Timer,直接显示「重试中…」。
  void _maybeScheduleTicker(RetryState state) {
    _tickTimer?.cancel();
    _remainingSeconds = (state.delayMs / 1000).ceil();
    if (_remainingSeconds <= 1) return; // ≤1s 直接显示「重试中」
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RetryState?>(
      valueListenable: RetrySignals.instance.notifier,
      builder: (context, state, _) {
        // 无活跃重试 → 取消倒计时,横幅不渲染
        if (state == null) {
          _tickTimer?.cancel();
          return const SizedBox.shrink();
        }
        _maybeScheduleTicker(state);
        final isTransport = state.level == RetryLevel.transport;
        final prefix = isTransport ? '网络重试' : '回合重试';
        final color =
            isTransport ? Colors.orange.shade700 : Colors.blue.shade700;
        final bgColor = isTransport
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.blue.withValues(alpha: 0.12);
        // 倒计时到 0 或 delayMs≤1s 都显示「重试中…」
        final remainingText =
            _remainingSeconds <= 0 ? '重试中…' : '$_remainingSeconds s 后重试';
        final tail = state.delayMs > 1000 ? ' · $remainingText' : ' · 重试中';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$prefix ${state.attempt}/${state.maxAttempts}'
                  ' · ${state.errorCategory}$tail',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
