import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/tts_timer_config.dart';
import '../services/tts_player_service.dart';
import '../widgets/tts_control_panel.dart';
import '../widgets/tts_content_display.dart';
import '../widgets/tts_chapter_selector.dart';
import '../widgets/tts_timer_settings_sheet.dart';
import '../widgets/tts_timer_complete_dialog.dart';
import '../utils/toast_utils.dart';
import '../services/logger_service.dart';
import '../core/providers/services/ai_service_providers.dart';

/// TTS播放器全屏页面 - Riverpod 版本
///
/// 每个 TTS 播放器实例都是独立的，在 State 中管理服务实例
class TtsPlayerScreen extends ConsumerStatefulWidget {
  final Novel novel;
  final List<Chapter> chapters;
  final Chapter startChapter;
  final String? startContent;
  final int startParagraphIndex;

  const TtsPlayerScreen({
    super.key,
    required this.novel,
    required this.chapters,
    required this.startChapter,
    this.startContent,
    this.startParagraphIndex = 0,
  });

  @override
  ConsumerState<TtsPlayerScreen> createState() => _TtsPlayerScreenState();
}

class _TtsPlayerScreenState extends ConsumerState<TtsPlayerScreen> {
  late TtsPlayerService _playerService;
  StreamSubscription<TtsTimerConfig>? _timerCompleteSubscription;

  @override
  void initState() {
    super.initState();

    // 初始化播放器
    _initializePlayer();

    // 监听定时完成事件将在 _initializePlayer 中设置
  }

  Future<void> _initializePlayer() async {
    // 通过Provider创建播放器服务
    _playerService = ref.read(ttsPlayerServiceProvider);

    // 监听定时完成事件
    _timerCompleteSubscription =
        _playerService.onTimerComplete.listen((config) {
      if (mounted) {
        _showTimerCompleteDialog(config);
      }
    });

    final success = await _playerService.initializeWithNovel(
      novel: widget.novel,
      chapters: widget.chapters,
      startChapter: widget.startChapter,
      startContent: widget.startContent,
      startParagraphIndex: widget.startParagraphIndex,
    );

    if (!success && mounted) {
      // 初始化失败，显示错误并返回
      LoggerService.instance.e(
        'TTS初始化失败: ${_playerService.errorMessage}',
        category: LogCategory.tts,
        tags: ['player', 'initialization', 'failed'],
      );
      ToastUtils.showError('TTS初始化失败: ${_playerService.errorMessage}');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timerCompleteSubscription?.cancel();
    _playerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 ListenableBuilder 监听播放器状态变化
    return ListenableBuilder(
      listenable: _playerService,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: _buildTitle(),
            actions: [
              // 定时按钮
              _buildTimerButton(),
              // 章节选择按钮
              _buildChapterSelectorButton(),
              // 设置按钮
              IconButton(
                onPressed: () => _showSettings(),
                icon: const Icon(Icons.settings),
                tooltip: '设置',
              ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildTitle() {
    final currentChapter = _playerService.currentChapter;
    final currentIndex = _playerService.currentChapterIndex;
    final totalChapters = _playerService.allChapters.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.novel.title,
          style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                currentChapter?.title ?? '加载中...',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (totalChapters > 0)
              Text(
                ' ${currentIndex + 1}/$totalChapters',
                style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimerButton() {
    final timerEnabled = _playerService.timerConfig.enabled;
    final timerCount = _playerService.timerConfig.chapterCount;

    return IconButton(
      onPressed: () => _showTimerSettings(_playerService),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            timerEnabled ? Icons.timer : Icons.timer_outlined,
            color: timerEnabled ? Colors.orange : null,
          ),
          if (timerEnabled)
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '$timerCount',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.surface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      tooltip: timerEnabled ? '定时$timerCount章' : '定时结束',
    );
  }

  Widget _buildChapterSelectorButton() {
    return IconButton(
      onPressed: (_playerService.state == TtsPlayerState.idle ||
              _playerService.state == TtsPlayerState.paused)
          ? () => _showChapterSelector(_playerService)
          : null,
      icon: const Icon(Icons.list),
      tooltip: '章节列表',
    );
  }

  Widget _buildBody() {
    // 根据状态显示不同内容
    switch (_playerService.state) {
      case TtsPlayerState.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载...'),
            ],
          ),
        );

      case TtsPlayerState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _playerService.errorMessage ?? '发生错误',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        );

      case TtsPlayerState.completed:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('朗读完成', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        );

      default:
        // 显示播放界面
        return Column(
          children: [
            // 内容显示区
            Expanded(
              child: TtsContentDisplay(
                paragraphs: _playerService.paragraphs,
                currentIndex: _playerService.currentParagraphIndex,
                onParagraphTap: (index) {
                  _playerService.jumpToParagraph(index);
                },
              ),
            ),

            // 控制面板
            TtsControlPanel(
              state: _playerService.state,
              hasPreviousChapter: _playerService.hasPreviousChapter,
              hasNextChapter: _playerService.hasNextChapter,
              speechRate: _playerService.speechRate,
              onPlay: () => _playerService.play(),
              onPause: () => _playerService.pause(),
              onStop: () => _playerService.stop(),
              onPreviousChapter: () => _previousChapter(_playerService),
              onNextChapter: () => _nextChapter(_playerService),
              onRateChanged: (rate) => _playerService.setSpeechRate(rate),
            ),
          ],
        );
    }
  }

  /// 显示章节选择器
  void _showChapterSelector(TtsPlayerService player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (builderContext) => TtsChapterSelector(
        chapters: widget.chapters,
        currentIndex: player.currentChapterIndex,
        onChapterSelected: (chapter) async {
          Navigator.pop(builderContext);
          final success = await player.jumpToChapter(chapter);
          if (!success && mounted) {
            LoggerService.instance.e(
              '跳转章节失败: ${player.errorMessage}',
              category: LogCategory.tts,
              tags: ['player', 'chapter', 'jump', 'failed'],
            );
            ToastUtils.showError('跳转章节失败: ${player.errorMessage}');
          }
        },
      ),
    );
  }

  /// 显示设置
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) {
        double currentRate = _playerService.speechRate;
        bool currentAutoPlay = _playerService.autoPlayNext;

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '朗读设置',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // 语速设置
                  Row(
                    children: [
                      const Text('语速:'),
                      Expanded(
                        child: Slider(
                          value: currentRate,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${currentRate.toStringAsFixed(1)}x',
                          onChanged: (value) {
                            setState(() {
                              currentRate = value;
                            });
                            _playerService.setSpeechRate(value);
                          },
                        ),
                      ),
                      Text('${currentRate.toStringAsFixed(1)}x'),
                    ],
                  ),

                  // 自动播放开关
                  SwitchListTile(
                    title: const Text('自动播放下一章'),
                    subtitle: const Text('当前章节结束后自动开始下一章'),
                    value: currentAutoPlay,
                    onChanged: (value) {
                      setState(() {
                        currentAutoPlay = value;
                      });
                      _playerService.autoPlayNext = value;
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 上一章
  Future<void> _previousChapter(TtsPlayerService player) async {
    if (!player.hasPreviousChapter) return;

    final prevChapter = widget.chapters[player.currentChapterIndex - 1];
    final success = await player.jumpToChapter(prevChapter);
    if (!success && mounted) {
      LoggerService.instance.e(
        '跳转上一章失败: ${player.errorMessage}',
        category: LogCategory.tts,
        tags: ['player', 'chapter', 'previous', 'failed'],
      );
      ToastUtils.showError('跳转上一章失败: ${player.errorMessage}');
    }
  }

  /// 下一章
  Future<void> _nextChapter(TtsPlayerService player) async {
    if (!player.hasNextChapter) return;

    final nextChapter = widget.chapters[player.currentChapterIndex + 1];
    final success = await player.jumpToChapter(nextChapter);
    if (!success && mounted) {
      LoggerService.instance.e(
        '跳转下一章失败: ${player.errorMessage}',
        category: LogCategory.tts,
        tags: ['player', 'chapter', 'next', 'failed'],
      );
      ToastUtils.showError('跳转下一章失败: ${player.errorMessage}');
    }
  }

  /// 显示定时设置
  void _showTimerSettings(TtsPlayerService player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => TtsTimerSettingsSheet(
        currentChapterIndex: player.currentChapterIndex,
        totalChapters: player.allChapters.length,
        initialChapterCount:
            player.timerConfig.enabled ? player.timerConfig.chapterCount : null,
        onConfirm: (chapterCount) async {
          await player.setTimer(chapterCount);
          if (mounted) {
            ToastUtils.showSuccess('已设置：朗读$chapterCount章后停止');
          }
        },
      ),
    );
  }

  /// 显示定时完成对话框
  void _showTimerCompleteDialog(TtsTimerConfig config) {
    final completedChapters =
        config.getCompletedChapters(_playerService.currentChapterIndex);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TtsTimerCompleteDialog(
        completedChapters: completedChapters,
        currentChapterIndex: _playerService.currentChapterIndex,
        onContinue: () {
          Navigator.pop(context);
          // 取消定时，继续播放
          _playerService.cancelTimer();
          _playerService.play();
        },
        onClose: () {
          Navigator.pop(context);
          Navigator.pop(context); // 关闭播放器
        },
      ),
    );
  }
}
