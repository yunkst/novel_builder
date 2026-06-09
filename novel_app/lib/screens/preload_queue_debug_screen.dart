import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preload_progress_update.dart';
import '../core/providers/service_providers.dart';
import '../core/theme/app_colors.dart';
import '../utils/toast_utils.dart';
import '../widgets/common/common_widgets.dart';

/// 预加载队列调试屏幕
///
/// 展示 PreloadService 的队列工作情况，用于调试和监控。
/// - 统计卡片：队列长度、处理状态、已处理/失败数
/// - 最后活跃小说
/// - 小说状态列表
/// - 实时进度 Stream 监听
/// - 刷新/清空队列操作
class PreloadQueueDebugScreen extends ConsumerStatefulWidget {
  const PreloadQueueDebugScreen({super.key});

  @override
  ConsumerState<PreloadQueueDebugScreen> createState() =>
      _PreloadQueueDebugScreenState();
}

class _PreloadQueueDebugScreenState
    extends ConsumerState<PreloadQueueDebugScreen> {
  Map<String, dynamic> _stats = {};
  final List<PreloadProgressUpdate> _recentUpdates = [];
  StreamSubscription<PreloadProgressUpdate>? _progressSub;
  Timer? _refreshTimer;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
    _listenProgressStream();
    // 每5秒自动刷新统计数据
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshStats();
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshStats() {
    final preloadService = ref.read(preloadServiceProvider);
    setState(() {
      _stats = preloadService.getStatistics();
    });
  }

  void _listenProgressStream() {
    final preloadService = ref.read(preloadServiceProvider);
    _progressSub = preloadService.progressStream.listen((update) {
      if (!mounted) return;
      setState(() {
        _recentUpdates.insert(0, update);
        // 最多保留50条
        if (_recentUpdates.length > 50) {
          _recentUpdates.removeRange(50, _recentUpdates.length);
        }
      });
      // 收到进度更新时同步刷新统计
      _refreshStats();
    });
  }

  Future<void> _clearQueue() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '确认清空',
      message: '确定要清空预加载队列吗？正在处理的任务将完成当前项后停止。',
      confirmText: '清空',
      icon: Icons.delete_outline,
      confirmColor: context.appColors.error,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isClearing = true;
    });

    try {
      final preloadService = ref.read(preloadServiceProvider);
      await preloadService.clearQueue();
      _recentUpdates.clear();
      _refreshStats();
      if (mounted) {
        ToastUtils.showSuccess('预加载队列已清空');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('清空队列失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('预加载队列'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStats,
            tooltip: '刷新统计',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 统计卡片
          _buildStatsGrid(colorScheme),
          const SizedBox(height: 16),

          // 最后活跃小说
          _buildLastActiveNovel(colorScheme),
          const SizedBox(height: 16),

          // 小说状态列表
          _buildNovelStatesSection(colorScheme),
          const SizedBox(height: 16),

          // 操作按钮
          _buildActionButtons(colorScheme),
          const SizedBox(height: 16),

          // 实时进度更新
          _buildRecentUpdatesSection(colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ColorScheme colorScheme) {
    final queueLength = _stats['queue_length'] as int? ?? 0;
    final isProcessing = _stats['is_processing'] as bool? ?? false;
    final totalProcessed = _stats['total_processed'] as int? ?? 0;
    final totalFailed = _stats['total_failed'] as int? ?? 0;
    final enqueuedUrls = _stats['enqueued_urls'] as int? ?? 0;

    final items = [
      _StatItem(
        label: '队列长度',
        value: '$queueLength',
        icon: Icons.queue,
        color: queueLength > 0 ? context.appColors.warning : Theme.of(context).colorScheme.outline,
      ),
      _StatItem(
        label: '处理状态',
        value: isProcessing ? '处理中' : '空闲',
        icon: isProcessing ? Icons.sync : Icons.check_circle,
        color: isProcessing ? context.appColors.success : Theme.of(context).colorScheme.outline,
      ),
      _StatItem(
        label: '已处理',
        value: '$totalProcessed',
        icon: Icons.done_all,
        color: context.appColors.info,
      ),
      _StatItem(
        label: '已失败',
        value: '$totalFailed',
        icon: Icons.error_outline,
        color: totalFailed > 0 ? context.appColors.error : Theme.of(context).colorScheme.outline,
      ),
      _StatItem(
        label: '已入队URL',
        value: '$enqueuedUrls',
        icon: Icons.link,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      _StatItem(
        label: '进度更新',
        value: '${_recentUpdates.length}',
        icon: Icons.update,
        color: context.appColors.neutral,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '队列统计',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: items.map((item) => _buildStatCard(item, colorScheme)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(_StatItem item, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastActiveNovel(ColorScheme colorScheme) {
    final lastActiveNovel = _stats['last_active_novel'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '最后活跃小说',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lastActiveNovel ?? '无',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: lastActiveNovel != null
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNovelStatesSection(ColorScheme colorScheme) {
    final novelStates = _stats['novel_states'] as Map<dynamic, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '小说状态',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${novelStates.length} 本',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (novelStates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '暂无活跃小说',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            else
              ...novelStates.entries.map((entry) {
                final novelUrl = entry.key.toString();
                final currentIndex = entry.value as int;
                // 从URL中提取简短标识
                final shortUrl = novelUrl.length > 50
                    ? '...${novelUrl.substring(novelUrl.length - 40)}'
                    : novelUrl;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shortUrl,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '第${currentIndex + 1}章',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _refreshStats,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新统计'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isClearing ? null : _clearQueue,
            icon: _isClearing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
            ),
                  )
                : const Icon(Icons.delete_sweep, size: 18),
            label: Text(_isClearing ? '清空中...' : '清空队列'),
            style: FilledButton.styleFrom(
              backgroundColor: context.appColors.error,
              foregroundColor: context.appColors.onSemantic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentUpdatesSection(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stream,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '实时进度更新',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_recentUpdates.length} 条',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (_recentUpdates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '暂无进度更新',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            else
              ..._recentUpdates.take(20).map((update) {
                return _buildProgressUpdateItem(update, colorScheme);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressUpdateItem(
      PreloadProgressUpdate update, ColorScheme colorScheme) {
    final time = update.timestamp;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            update.isPreloading ? Icons.sync : Icons.check_circle_outline,
            size: 12,
            color: update.isPreloading ? context.appColors.success : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              update.chapterUrl ?? update.novelUrl,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}