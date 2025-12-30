import 'package:flutter/material.dart';

class ScrollSpeedAdjusterDialog extends StatefulWidget {
  final double initialScrollSpeed;
  final ValueChanged<double> onScrollSpeedChanged;

  const ScrollSpeedAdjusterDialog({
    super.key,
    required this.initialScrollSpeed,
    required this.onScrollSpeedChanged,
  });

  @override
  State<ScrollSpeedAdjusterDialog> createState() => _ScrollSpeedAdjusterDialogState();
}

class _ScrollSpeedAdjusterDialogState extends State<ScrollSpeedAdjusterDialog> {
  late double _currentScrollSpeed;

  @override
  void initState() {
    super.initState();
    _currentScrollSpeed = widget.initialScrollSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('调整滚动速度'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '当前速度: ${_currentScrollSpeed.toStringAsFixed(1)}x',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _currentScrollSpeed,
            min: 0.1,
            max: 5.0,
            divisions: 49,
            label: '${_currentScrollSpeed.toStringAsFixed(1)}x',
            onChanged: (value) {
              setState(() {
                _currentScrollSpeed = value;
              });
            },
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('慢 (0.1x)',
                  style:
                      TextStyle(color: Colors.grey, fontSize: 12)),
              Text('快 (5.0x)',
                  style:
                      TextStyle(color: Colors.grey, fontSize: 12)),
            ],
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
            widget.onScrollSpeedChanged(_currentScrollSpeed); // 回调滚动速度
            Navigator.pop(context); // 关闭对话框
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}