import 'package:flutter/material.dart';
import '../services/tts_player_service.dart';

/// TTS控制面板组件
class TtsControlPanel extends StatelessWidget {
  final TtsPlayerState state;
  final bool hasPreviousChapter;
  final bool hasNextChapter;
  final double speechRate;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onRateChanged;

  const TtsControlPanel({
    super.key,
    required this.state,
    required this.hasPreviousChapter,
    required this.hasNextChapter,
    required this.speechRate,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaying = state == TtsPlayerState.playing;
    final isPaused = state == TtsPlayerState.paused;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 播放进度
              if (isPlaying || isPaused)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.graphic_eq, size: 16, color: Color(0xFF2196F3)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: null, // 无限动画
                          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),

              // 章节切换按钮
              Row(
                children: [
                  IconButton(
                    onPressed: hasPreviousChapter ? onPreviousChapter : null,
                    icon: const Icon(Icons.skip_previous),
                    tooltip: '上一章',
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 播放/暂停/停止
                        _buildPlayButton(context),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: hasNextChapter ? onNextChapter : null,
                    icon: const Icon(Icons.skip_next),
                    tooltip: '下一章',
                  ),
                ],
              ),

              // 语速调节
              Row(
                children: [
                  const Icon(Icons.speed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: speechRate,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: '${speechRate.toStringAsFixed(1)}x',
                      onChanged: onRateChanged,
                    ),
                  ),
                  Text(
                    '${speechRate.toStringAsFixed(1)}x',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    final isPlaying = state == TtsPlayerState.playing;
    final isPaused = state == TtsPlayerState.paused;
    final isIdle = state == TtsPlayerState.idle;

    if (isPlaying) {
      // 暂停按钮
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPause,
            icon: const Icon(Icons.pause_circle_filled),
            iconSize: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle),
            iconSize: 40,
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      );
    } else if (isPaused || isIdle) {
      // 播放按钮
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onPlay,
            icon: const Icon(Icons.play_circle_filled),
            iconSize: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          if (isPaused)
            IconButton(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle),
              iconSize: 40,
              color: Theme.of(context).colorScheme.error,
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
