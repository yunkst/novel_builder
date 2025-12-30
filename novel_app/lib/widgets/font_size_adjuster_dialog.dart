import 'package:flutter/material.dart';

class FontSizeAdjusterDialog extends StatefulWidget {
  final double initialFontSize;
  final ValueChanged<double> onFontSizeChanged;

  const FontSizeAdjusterDialog({
    super.key,
    required this.initialFontSize,
    required this.onFontSizeChanged,
  });

  @override
  State<FontSizeAdjusterDialog> createState() => _FontSizeAdjusterDialogState();
}

class _FontSizeAdjusterDialogState extends State<FontSizeAdjusterDialog> {
  late double _currentFontSize;

  @override
  void initState() {
    super.initState();
    _currentFontSize = widget.initialFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('调整字体大小'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '示例文字',
            style: TextStyle(fontSize: _currentFontSize),
          ),
          Slider(
            value: _currentFontSize,
            min: 12,
            max: 32,
            divisions: 20,
            label: _currentFontSize.round().toString(),
            onChanged: (value) {
              setState(() {
                _currentFontSize = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // 用户取消
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onFontSizeChanged(_currentFontSize); // 回调字体大小
            Navigator.pop(context); // 关闭对话框
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}