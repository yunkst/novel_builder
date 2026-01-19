import 'package:flutter/material.dart';
import '../models/app_version.dart';
import '../services/app_update_service.dart';

/// APP更新对话框
///
/// 显示有新版本可用，提供下载更新选项
class AppUpdateDialog extends StatefulWidget {
  final AppVersion version;
  final AppUpdateService updateService;
  final VoidCallback? onUpdateComplete;

  const AppUpdateDialog({
    super.key,
    required this.version,
    required this.updateService,
    this.onUpdateComplete,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  bool _isDownloading = false;
  bool _isDownloadComplete = false;
  bool _isInstalling = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.version.forceUpdate
                ? Icons.system_update_alt
                : Icons.new_releases,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            widget.version.forceUpdate ? '强制更新' : '发现新版本',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本信息
            Text(
              '版本 ${widget.version.version}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '大小: ${widget.version.fileSizeFormatted}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            // 更新日志
            if (widget.version.changelog != null &&
                widget.version.changelog!.isNotEmpty) ...[
              Text(
                '更新内容:',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.version.changelog!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 下载进度
            if (_isDownloading || _isDownloadComplete) ...[
              if (_isDownloading) ...[
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}% - $_statusMessage',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ] else if (_isDownloadComplete) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '下载完成',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    // 强制更新时不显示"稍后提醒"按钮
    final showSkipButton = !widget.version.forceUpdate && !_isDownloading;

    if (_isInstalling) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    if (_isDownloadComplete) {
      return [
        TextButton(
          onPressed: _isInstalling ? null : _installApk,
          child: const Text('立即安装'),
        ),
      ];
    }

    if (_isDownloading) {
      return [
        TextButton(
          onPressed: null,
          child: const Text('下载中...'),
        ),
      ];
    }

    return [
      if (showSkipButton)
        TextButton(
          onPressed: () async {
            await widget.updateService.ignoreVersion(widget.version.version);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('稍后提醒'),
        ),
      ElevatedButton(
        onPressed: _startDownload,
        child: const Text('立即更新'),
      ),
    ];
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = '准备下载...';
    });

    final success = await widget.updateService.downloadUpdate(
      version: widget.version,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
      onStatus: (status) {
        if (mounted) {
          setState(() {
            _statusMessage = status;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloadComplete = success;
        _statusMessage = success ? '下载完成' : '下载失败';
      });

      if (success) {
        // 下载成功后自动提示安装
        _installApk();
      }
    }
  }

  Future<void> _installApk() async {
    setState(() {
      _isInstalling = true;
    });

    final success =
        await widget.updateService.installUpdate(widget.version.version);

    if (mounted) {
      setState(() {
        _isInstalling = false;
      });

      if (success) {
        // 安装启动后关闭对话框
        Navigator.of(context).pop();
        widget.onUpdateComplete?.call();
      } else {
        // 安装失败，显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('安装失败，请手动安装')),
        );
      }
    }
  }
}

/// 显示更新对话框的辅助函数
Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppVersion version,
  required AppUpdateService updateService,
  VoidCallback? onUpdateComplete,
}) {
  return showDialog(
    context: context,
    barrierDismissible: !version.forceUpdate,
    builder: (context) => WillPopScope(
      onWillPop: () async => !version.forceUpdate,
      child: AppUpdateDialog(
        version: version,
        updateService: updateService,
        onUpdateComplete: onUpdateComplete,
      ),
    ),
  );
}
