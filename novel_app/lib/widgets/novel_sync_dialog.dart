import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/novel.dart';
import '../../core/providers/novel_sync_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../services/novel_sync_service.dart';

/// 小说同步对话框
///
/// 显示小说同步（上传/下载）的进度和结果。
/// 支持自动开始同步操作。
///
/// **使用示例**:
/// ```dart
/// // 上传小说
/// final result = await NovelSyncDialog.show(
///   context: context,
///   novel: novel,
///   operation: SyncOperation.upload,
/// );
///
/// // 下载小说
/// final result = await NovelSyncDialog.show(
///   context: context,
///   novel: novel,
///   operation: SyncOperation.download,
/// );
/// ```
class NovelSyncDialog extends ConsumerStatefulWidget {
  /// 要同步的小说
  final Novel novel;

  /// 同步操作类型
  final SyncOperation operation;

  /// 是否强制覆盖（仅上传时有效）
  final bool forceOverwrite;

  /// 是否删除现有数据（仅下载时有效）
  final bool deleteExisting;

  const NovelSyncDialog({
    super.key,
    required this.novel,
    required this.operation,
    this.forceOverwrite = false,
    this.deleteExisting = true,
  });

  /// 显示同步对话框
  ///
  /// 返回同步结果，如果失败或取消则返回 null
  static Future<SyncResult?> show({
    required BuildContext context,
    required Novel novel,
    required SyncOperation operation,
    bool forceOverwrite = false,
    bool deleteExisting = true,
  }) async {
    return showDialog<SyncResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NovelSyncDialog(
        novel: novel,
        operation: operation,
        forceOverwrite: forceOverwrite,
        deleteExisting: deleteExisting,
      ),
    );
  }

  @override
  ConsumerState<NovelSyncDialog> createState() => _NovelSyncDialogState();
}

class _NovelSyncDialogState extends ConsumerState<NovelSyncDialog> {
  /// 同步状态
  SyncState _state = const SyncState();

  @override
  void initState() {
    super.initState();
    // 自动开始同步
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSync();
    });
  }

  /// 开始同步操作
  Future<void> _startSync() async {
    // 设置初始状态
    setState(() {
      _state = SyncState(
        status: widget.operation == SyncOperation.upload
            ? SyncStatus.uploading
            : SyncStatus.downloading,
        progress: 0.0,
      );
    });

    try {
      final helper = ref.read(syncServiceHelperProvider);
      SyncResult result;

      if (widget.operation == SyncOperation.upload) {
        // 执行上传
        result = await helper.uploadNovel(
          widget.novel,
          forceOverwrite: widget.forceOverwrite,
        );
      } else {
        // 执行下载
        result = await helper.downloadNovel(
          widget.novel,
          deleteExisting: widget.deleteExisting,
        );
      }

      if (!mounted) return;

      if (result.success) {
        // 同步成功
        final syncVersion = result.data?['sync_version'] as int?;
        final syncedAtStr = result.data?['synced_at'] as String?;
        final syncedAt =
            syncedAtStr != null ? DateTime.tryParse(syncedAtStr) : null;

        setState(() {
          _state = SyncState(
            status: SyncStatus.success,
            progress: 1.0,
            resultData: result.data,
            syncVersion: syncVersion,
            syncedAt: syncedAt,
          );
        });

        // 延迟关闭对话框
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      } else {
        // 同步失败
        setState(() {
          _state = SyncState(
            status: SyncStatus.error,
            errorMessage: result.errorMessage ?? '同步失败',
          );
        });
      }
    } catch (e) {
      // 异常处理
      if (mounted) {
        setState(() {
          _state = SyncState(
            status: SyncStatus.error,
            errorMessage: e.toString(),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          _buildStateIcon(),
          const SizedBox(width: 8),
          Text(_buildTitle()),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 小说信息
            _buildNovelInfo(),
            const SizedBox(height: 16),

            // 状态内容
            if (_state.status == SyncStatus.uploading ||
                _state.status == SyncStatus.downloading)
              _buildProgressContent()
            else if (_state.status == SyncStatus.success)
              _buildSuccessContent()
            else if (_state.status == SyncStatus.error)
              _buildErrorContent(),
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  /// 构建状态图标
  Widget _buildStateIcon() {
    switch (_state.status) {
      case SyncStatus.idle:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncStatus.uploading:
        return Icon(
          Icons.cloud_upload_rounded,
          color: Theme.of(context).colorScheme.primary,
        );
      case SyncStatus.downloading:
        return Icon(
          Icons.cloud_download_rounded,
          color: Theme.of(context).colorScheme.primary,
        );
      case SyncStatus.success:
        return Icon(Icons.check_circle, color: context.appColors.success);
      case SyncStatus.error:
        return Icon(Icons.error, color: context.appColors.error);
    }
  }

  /// 构建标题
  String _buildTitle() {
    switch (_state.status) {
      case SyncStatus.idle:
        return '准备同步';
      case SyncStatus.uploading:
        return '上传中';
      case SyncStatus.downloading:
        return '下载中';
      case SyncStatus.success:
        return widget.operation == SyncOperation.upload ? '上传成功' : '下载成功';
      case SyncStatus.error:
        return '同步失败';
    }
  }

  /// 构建小说信息
  Widget _buildNovelInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: widget.novel.coverUrl != null &&
                    widget.novel.coverUrl!.isNotEmpty
                ? Image.network(
                    widget.novel.coverUrl!,
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                  )
                : _buildPlaceholderCover(),
          ),
          const SizedBox(width: 12),
          // 标题和作者
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.novel.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.novel.author.isNotEmpty)
                  Text(
                    widget.novel.author,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建占位封面
  Widget _buildPlaceholderCover() {
    return Container(
      width: 40,
      height: 56,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.book, size: 20, color: Theme.of(context).colorScheme.outline),
    );
  }

  /// 构建进度内容
  Widget _buildProgressContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          widget.operation == SyncOperation.upload
              ? '正在上传小说数据到服务器...'
              : '正在从服务器下载小说数据...',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// 构建成功内容
  Widget _buildSuccessContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.successContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.successContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 20, color: context.appColors.onSuccessContainer),
              const SizedBox(width: 8),
              Text(
                widget.operation == SyncOperation.upload
                    ? '小说数据已成功上传到服务器'
                    : '小说数据已成功下载到本地',
                style: TextStyle(
                  fontSize: 14,
                  color: context.appColors.onSuccessContainer,
                ),
              ),
            ],
          ),
          if (_state.syncVersion != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('同步版本', 'v${_state.syncVersion}'),
          ],
          if (_state.syncedAt != null) ...[
            const SizedBox(height: 4),
            _buildInfoRow(
              '同步时间',
              '${_state.syncedAt!.year}-${_state.syncedAt!.month.toString().padLeft(2, '0')}-${_state.syncedAt!.day.toString().padLeft(2, '0')} '
                  '${_state.syncedAt!.hour.toString().padLeft(2, '0')}:${_state.syncedAt!.minute.toString().padLeft(2, '0')}',
            ),
          ],
        ],
      ),
    );
  }

  /// 构建错误内容
  Widget _buildErrorContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.errorContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: context.appColors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _state.errorMessage ?? '未知错误',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appColors.onErrorContainer,
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
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮
  List<Widget> _buildActions() {
    if (_state.status == SyncStatus.error) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('关闭'),
        ),
        TextButton(
          onPressed: _startSync,
          child: const Text('重试'),
        ),
      ];
    }
    return [];
  }
}