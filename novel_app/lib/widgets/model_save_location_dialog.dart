import 'package:flutter/material.dart';

/// 选目录对话框返回结果
class ModelSaveLocationResult {
  final String subdir;
  final String filename;

  const ModelSaveLocationResult({
    required this.subdir,
    required this.filename,
  });
}

/// 选保存位置对话框
///
/// 候选列表为 backend /app/models 下的一级子目录。
/// 用户可编辑文件名并选择目标子目录，确认后返回 [ModelSaveLocationResult]。
class ModelSaveLocationDialog extends StatefulWidget {
  final String url;
  final String filename;
  final List<Map<String, dynamic>> dirs;

  const ModelSaveLocationDialog({
    super.key,
    required this.url,
    required this.filename,
    required this.dirs,
  });

  @override
  State<ModelSaveLocationDialog> createState() =>
      _ModelSaveLocationDialogState();
}

class _ModelSaveLocationDialogState extends State<ModelSaveLocationDialog> {
  late TextEditingController _filenameController;
  String? _selectedSubdir;

  @override
  void initState() {
    super.initState();
    _filenameController = TextEditingController(text: widget.filename);
    if (widget.dirs.isNotEmpty) {
      _selectedSubdir = widget.dirs.first['name'] as String;
    }
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存模型到…'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '来源：${widget.url}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filenameController,
              decoration: const InputDecoration(
                labelText: '文件名',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Text('保存到子目录（/app/models/）',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubdir,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final d in widget.dirs)
                  DropdownMenuItem<String>(
                    value: d['name'] as String,
                    child: Text(d['name'] as String),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedSubdir = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _onConfirm,
          child: const Text('开始下载'),
        ),
      ],
    );
  }

  void _onConfirm() {
    final name = _filenameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件名不能为空')),
      );
      return;
    }
    if (_selectedSubdir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择保存目录')),
      );
      return;
    }
    Navigator.of(context).pop(ModelSaveLocationResult(
      subdir: _selectedSubdir!,
      filename: name,
    ));
  }
}
