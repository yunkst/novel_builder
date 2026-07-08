import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/model_download_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/model_download_task.dart';
import '../utils/format_utils.dart';

/// 模型下载/上传管理页面
///
/// 展示所有活跃的模型下载/上传任务，支持暂停/继续/取消/删除。
class ModelDownloadManagerScreen extends ConsumerWidget {
  const ModelDownloadManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelDownloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '模型下载管理',
          style: AppTypography.chapterTitle.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () =>
                ref.read(modelDownloadProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.tasks.isEmpty
              ? _buildEmpty(context)
              : _buildTaskList(context, ref, state.tasks),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_outlined,
              size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text(
            '暂无下载任务',
            style: AppTypography.bodyProse.copyWith(
              fontSize: 15,
              color: context.appColors.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在浏览器中点击下载链接即可添加任务',
            style: AppTypography.metaItalic.copyWith(
              color: context.appColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    WidgetRef ref,
    List<ModelDownloadTask> tasks,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _TaskCard(task: tasks[index], ref: ref),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ModelDownloadTask task;
  final WidgetRef ref;

  const _TaskCard({required this.task, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：文件名 + 状态标签
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.filename,
                    style: AppTypography.novelTitle.copyWith(
                      fontSize: 14,
                      color: context.appColors.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(context),
              ],
            ),
            const SizedBox(height: 4),
            // 子目录
            Text(
              '→ /app/models/${task.targetSubdir}/',
              style: AppTypography.metaItalic.copyWith(
                color: context.appColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            // 进度条
            _buildProgressBar(context),
            const SizedBox(height: 4),
            // 进度文本
            _buildProgressText(context),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                task.errorMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appColors.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            // 操作按钮
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final (label, color) = switch (task.status) {
      ModelDownloadStatus.downloading => ('下载中', Colors.blue),
      ModelDownloadStatus.downloadPaused => ('下载暂停', Colors.orange),
      ModelDownloadStatus.downloaded => ('待上传', Colors.teal),
      ModelDownloadStatus.uploading => ('上传中', Colors.indigo),
      ModelDownloadStatus.uploadPaused => ('上传暂停', Colors.orange),
      ModelDownloadStatus.completed => ('完成', Colors.green),
      ModelDownloadStatus.cancelled => ('已取消', Colors.grey),
      ModelDownloadStatus.failed => ('失败', Colors.red),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final progress = task.isDownloadPhase
        ? task.downloadProgress
        : task.isUploadPhase
            ? task.uploadProgress
            : task.status == ModelDownloadStatus.downloaded
                ? 1.0
                : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress > 0 ? progress : null,
        minHeight: 6,
      ),
    );
  }

  Widget _buildProgressText(BuildContext context) {
    if (task.isDownloadPhase || task.status == ModelDownloadStatus.downloaded) {
      final downloaded = FormatUtils.formatFileSize(task.downloadedBytes);
      final total = task.totalSize > 0
          ? FormatUtils.formatFileSize(task.totalSize)
          : '未知';
      final pct =
          task.totalSize > 0 ? '${(task.downloadProgress * 100).toInt()}%' : '';
      return Text(
        '$pct  $downloaded / $total',
        style: AppTypography.metaItalic.copyWith(
          color: context.appColors.inkSoft,
        ),
      );
    }
    if (task.isUploadPhase) {
      final done = task.uploadedChunkIndices.length;
      final total = task.totalChunks;
      final pct = total > 0 ? '${(task.uploadProgress * 100).toInt()}%' : '';
      return Text(
        '$pct  块 $done/$total',
        style: AppTypography.metaItalic.copyWith(
          color: context.appColors.inkSoft,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActions(BuildContext context) {
    final notifier = ref.read(modelDownloadProvider.notifier);
    final buttons = <Widget>[];

    switch (task.status) {
      case ModelDownloadStatus.downloading:
        buttons.addAll([
          _btn('暂停', Icons.pause, () => notifier.pause(task.id)),
          _btn('取消', Icons.cancel_outlined, () => notifier.cancel(task.id)),
          _btn('删除', Icons.delete_outline, () => notifier.deleteTask(task.id),
              danger: true),
        ]);
      case ModelDownloadStatus.downloadPaused:
        buttons.addAll([
          _btn('继续', Icons.play_arrow, () => notifier.resume(task.id)),
          _btn('取消', Icons.cancel_outlined, () => notifier.cancel(task.id)),
          _btn('删除', Icons.delete_outline, () => notifier.deleteTask(task.id),
              danger: true),
        ]);
      case ModelDownloadStatus.downloaded:
        buttons.addAll([
          _btn('上传', Icons.cloud_upload,
              () => notifier.startUpload(task.id)),
          _btn('删除', Icons.delete_outline, () => notifier.deleteTask(task.id),
              danger: true),
        ]);
      case ModelDownloadStatus.uploading:
        buttons.addAll([
          _btn('暂停', Icons.pause, () => notifier.pause(task.id)),
          _btn('取消', Icons.cancel_outlined, () => notifier.cancel(task.id)),
          _btn('删除', Icons.delete_outline, () => notifier.deleteTask(task.id),
              danger: true),
        ]);
      case ModelDownloadStatus.uploadPaused:
        buttons.addAll([
          _btn('继续', Icons.play_arrow, () => notifier.resume(task.id)),
          _btn('取消', Icons.cancel_outlined, () => notifier.cancel(task.id)),
          _btn('删除', Icons.delete_outline, () => notifier.deleteTask(task.id),
              danger: true),
        ]);
      case ModelDownloadStatus.failed:
        buttons.addAll([
          _btn('重试', Icons.refresh, () => notifier.resume(task.id)),
          _btn('删除', Icons.delete_outline, () => notifier.deleteTask(task.id),
              danger: true),
        ]);
      case ModelDownloadStatus.completed:
      case ModelDownloadStatus.cancelled:
        break;
    }

    return Wrap(spacing: 6, runSpacing: 4, children: buttons);
  }

  Widget _btn(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool danger = false,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: danger
          ? TextButton.styleFrom(foregroundColor: Colors.red)
          : null,
    );
  }
}
