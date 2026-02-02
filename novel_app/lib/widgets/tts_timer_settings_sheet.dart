import 'package:flutter/material.dart';

/// TTS定时设置底部弹窗
///
/// 用于设置TTS播放器的定时结束功能
class TtsTimerSettingsSheet extends StatefulWidget {
  /// 当前章节索引
  final int currentChapterIndex;

  /// 总章节数
  final int totalChapters;

  /// 初始章节数（用于编辑已有定时）
  final int? initialChapterCount;

  /// 确认回调
  final Function(int chapterCount) onConfirm;

  const TtsTimerSettingsSheet({
    super.key,
    required this.currentChapterIndex,
    required this.totalChapters,
    this.initialChapterCount,
    required this.onConfirm,
  });

  @override
  State<TtsTimerSettingsSheet> createState() => _TtsTimerSettingsSheetState();
}

class _TtsTimerSettingsSheetState extends State<TtsTimerSettingsSheet> {
  late int _chapterCount;

  @override
  void initState() {
    super.initState();
    // 如果有初始值，使用初始值；否则默认为3章
    _chapterCount = widget.initialChapterCount ?? 3;
  }

  @override
  Widget build(BuildContext context) {
    final currentChapterNum = widget.currentChapterIndex + 1;
    final targetChapterNum = widget.currentChapterIndex + _chapterCount;
    final isOverflow = targetChapterNum > widget.totalChapters;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 24, color: Theme.of(context).colorScheme.tertiary),
              const SizedBox(width: 8),
              const Text(
                '定时结束设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 说明
          const Text(
            '读多少章后停止：',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // 章节数选择器
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 减少按钮
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 40,
                  color: _chapterCount > 1
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                  onPressed: _chapterCount > 1
                      ? () => setState(() => _chapterCount--)
                      : null,
                ),
                const SizedBox(width: 16),

                // 数字显示
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.tertiary,
                        width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                  ),
                  child: Text(
                    '$_chapterCount',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 增加按钮
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 40,
                  color: _chapterCount < 99
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                  onPressed: _chapterCount < 99
                      ? () => setState(() => _chapterCount++)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 单位标签
          const Center(
            child: Text(
              '章',
              style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
            ),
          ),
          const SizedBox(height: 24),

          // 预览信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOverflow
                  ? Theme.of(context)
                      .colorScheme
                      .tertiaryContainer
                      .withValues(alpha: 0.5)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOverflow
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                width: isOverflow ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: isOverflow
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '预览',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('当前章节', '第 $currentChapterNum 章'),
                const SizedBox(height: 8),
                _buildInfoRow('将读到', '第 $targetChapterNum 章'),
                if (isOverflow) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning_amber,
                          size: 16,
                          color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '⚠️ 将超出小说总章节数（共${widget.totalChapters}章）',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.2)),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onConfirm(_chapterCount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '确认',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
