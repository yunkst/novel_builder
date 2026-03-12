import 'package:flutter/material.dart';

/// URL输入对话框
///
/// 用于让用户输入小说详情页URL以添加小说
class UrlInputDialog extends StatefulWidget {
  final String? initialUrl;
  final String title;
  final String hint;
  final String confirmText;
  final String cancelText;
  final bool Function(String url) validator;

  const UrlInputDialog({
    super.key,
    this.initialUrl,
    this.title = '添加小说',
    this.hint = '请输入小说详情页URL',
    this.confirmText = '确认',
    this.cancelText = '取消',
    required this.validator,
  });

  @override
  State<UrlInputDialog> createState() => _UrlInputDialogState();
}

class _UrlInputDialogState extends State<UrlInputDialog> {
  late TextEditingController _controller;
  String? _errorText;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateUrl() {
    final url = _controller.text.trim();
    setState(() {
      _errorText = null;
    });

    if (url.isEmpty) {
      setState(() {
        _errorText = 'URL不能为空';
      });
      return;
    }

    // 验证URL格式
    if (!_isValidUrl(url)) {
      setState(() {
        _errorText = '请输入有效的URL';
      });
      return;
    }

    // 调用自定义验证器
    if (!widget.validator(url)) {
      setState(() {
        _errorText = '不支持的URL站点';
      });
      return;
    }

    Navigator.of(context).pop(url);
  }

  bool _isValidUrl(String url) {
    // 基本URL格式验证
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.hasScheme) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: _errorText,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_errorText != null) return;
              setState(() {
                _errorText = null;
              });
            },
            onSubmitted: (_) => _validateUrl(),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _validateUrl,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

/// 显示URL输入对话框
///
/// 返回用户输入的URL，如果取消则返回null
Future<String?> showUrlInputDialog(
  BuildContext context, {
  String? initialUrl,
  String title = '添加小说',
  String hint = '请输入小说详情页URL',
  String confirmText = '确认',
  String cancelText = '取消',
  required bool Function(String url) validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => UrlInputDialog(
      initialUrl: initialUrl,
      title: title,
      hint: hint,
      confirmText: confirmText,
      cancelText: cancelText,
      validator: validator,
    ),
  );
}
