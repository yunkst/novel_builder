import 'package:flutter/material.dart';
import 'package:novel_app/services/novel_sync_service.dart';
import '../core/theme/app_colors.dart';

enum BatchSyncType { upload, download }

class BatchSyncDialog extends StatefulWidget {
  final BatchSyncType type;
  final Future<BatchSyncResult> Function() syncAction;

  const BatchSyncDialog({
    super.key,
    required this.type,
    required this.syncAction,
  });

  /// 显示上传进度对话框
  static Future<void> showUpload(
    BuildContext context,
    Future<BatchSyncResult> Function() syncAction,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchSyncDialog(
        type: BatchSyncType.upload,
        syncAction: syncAction,
      ),
    );
  }

  /// 显示下载进度对话框
  static Future<void> showDownload(
    BuildContext context,
    Future<BatchSyncResult> Function() syncAction,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchSyncDialog(
        type: BatchSyncType.download,
        syncAction: syncAction,
      ),
    );
  }

  @override
  State<BatchSyncDialog> createState() => _BatchSyncDialogState();
}

class _BatchSyncDialogState extends State<BatchSyncDialog> {
  bool _isSyncing = true;
  final int _current = 0;
  final int _total = 0;
  final String _currentTitle = '';
  BatchSyncResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    try {
      final result = await widget.syncAction();
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpload = widget.type == BatchSyncType.upload;
    final title = isUpload ? '上传所有小说' : '下载所有小说';

    return AlertDialog(
      title: Text(title),
      content: _isSyncing ? _buildProgress() : _buildResult(),
      actions: _isSyncing
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
    );
  }

  Widget _buildProgress() {
    final isUpload = widget.type == BatchSyncType.upload;
    final action = isUpload ? '上传' : '下载';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          '正在$action...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _currentTitle.isNotEmpty ? '$_currentTitle ($_current/$_total)' : '准备中...',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: context.appColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            '同步失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          result.failureCount == 0 ? Icons.check_circle : Icons.warning,
          color: result.failureCount == 0 ? context.appColors.success : context.appColors.warning,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          '同步完成',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '成功: ${result.successCount}  失败: ${result.failureCount}  总计: ${result.total}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (result.failureTitles.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '失败列表:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          ...result.failureTitles.map(
            (title) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '$title: ${result.errorMessages[title] ?? "未知错误"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
