import 'package:flutter/material.dart';

/// 备份确认对话框
///
/// 显示备份操作的确认信息，包括数据库名称、文件大小等
class BackupConfirmDialog extends StatelessWidget {
  final String fileName;
  final String fileSize;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const BackupConfirmDialog({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.onConfirm,
    this.onCancel,
  });

  /// 显示对话框
  ///
  /// 返回用户是否确认备份
  static Future<bool> show({
    required BuildContext context,
    required String fileName,
    required String fileSize,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BackupConfirmDialog(
        fileName: fileName,
        fileSize: fileSize,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.backup_rounded, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('确认备份数据'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('即将上传数据库备份到服务器，请确认：'),
          const SizedBox(height: 16),
          _buildInfoRow('文件名', fileName),
          const SizedBox(height: 8),
          _buildInfoRow('文件大小', fileSize),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '备份文件将保存在服务器，不会被删除。您可以随时恢复数据。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          child: const Text('开始备份'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
