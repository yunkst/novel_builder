import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/tts_player_service.dart';
import '../widgets/tts_control_panel.dart';
import '../widgets/tts_content_display.dart';
import '../widgets/tts_chapter_selector.dart';

/// TTS播放器全屏页面
class TtsPlayerScreen extends StatefulWidget {
  final Novel novel;
  final List<Chapter> chapters;
  final Chapter startChapter;
  final String? startContent;

  const TtsPlayerScreen({
    super.key,
    required this.novel,
    required this.chapters,
    required this.startChapter,
    this.startContent,
  });

  @override
  State<TtsPlayerScreen> createState() => _TtsPlayerScreenState();
}

class _TtsPlayerScreenState extends State<TtsPlayerScreen> {
  late TtsPlayerService _playerService;

  @override
  void initState() {
    super.initState();

    // 创建播放器服务
    _playerService = TtsPlayerService();

    // 初始化播放器
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final success = await _playerService.initializeWithNovel(
      novel: widget.novel,
      chapters: widget.chapters,
      startChapter: widget.startChapter,
      startContent: widget.startContent,
    );

    if (!success && mounted) {
      // 初始化失败，显示错误并返回
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('TTS初始化失败: ${_playerService.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _playerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _playerService,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<TtsPlayerService>(
            builder: (context, player, child) {
              final currentChapter = player.currentChapter;
              final currentIndex = player.currentChapterIndex;
              final totalChapters = player.allChapters.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.novel.title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            // 章节选择按钮
            Consumer<TtsPlayerService>(
              builder: (context, player, child) {
                return IconButton(
                  onPressed: (player.state == TtsPlayerState.idle ||
                             player.state == TtsPlayerState.paused)
                      ? () => _showChapterSelector(player)
                      : null,
                  icon: const Icon(Icons.list),
                  tooltip: '章节列表',
                );
              },
            ),
            // 设置按钮
            IconButton(
              onPressed: () => _showSettings(),
              icon: const Icon(Icons.settings),
              tooltip: '设置',
            ),
          ],
        ),
        body: Consumer<TtsPlayerService>(
          builder: (context, player, child) {
            // 根据状态显示不同内容
            switch (player.state) {
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
                        player.errorMessage ?? '发生错误',
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
                      const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
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
                        paragraphs: player.paragraphs,
                        currentIndex: player.currentParagraphIndex,
                      ),
                    ),

                    // 控制面板
                    TtsControlPanel(
                      state: player.state,
                      hasPrevious: player.currentParagraphIndex > 0,
                      hasNext: player.currentParagraphIndex < player.paragraphs.length - 1,
                      hasPreviousChapter: player.hasPreviousChapter,
                      hasNextChapter: player.hasNextChapter,
                      speechRate: player.speechRate,
                      onPlay: () => player.play(),
                      onPause: () => player.pause(),
                      onStop: () => player.stop(),
                      onPrevious: () => player.previousParagraph(),
                      onNext: () => player.nextParagraph(),
                      onPreviousChapter: () => _previousChapter(player),
                      onNextChapter: () => _nextChapter(player),
                      onRateChanged: (rate) => player.setSpeechRate(rate),
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('跳转章节失败: ${player.errorMessage}'),
                backgroundColor: Colors.red,
              ),
            );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('跳转上一章失败: ${player.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 下一章
  Future<void> _nextChapter(TtsPlayerService player) async {
    if (!player.hasNextChapter) return;

    final nextChapter = widget.chapters[player.currentChapterIndex + 1];
    final success = await player.jumpToChapter(nextChapter);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('跳转下一章失败: ${player.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
