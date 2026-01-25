import 'package:flutter/material.dart';
import '../models/ai_accompaniment_settings.dart';

/// AI伴读设置对话框
///
/// 用于配置小说的AI伴读功能，包括自动伴读和信息提示开关
class AiAccompanimentSettingsDialog extends StatefulWidget {
  /// 初始设置
  final AiAccompanimentSettings initialSettings;

  /// 保存回调
  final ValueChanged<AiAccompanimentSettings> onSave;

  const AiAccompanimentSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.onSave,
  });

  @override
  State<AiAccompanimentSettingsDialog> createState() =>
      _AiAccompanimentSettingsDialogState();
}

class _AiAccompanimentSettingsDialogState
    extends State<AiAccompanimentSettingsDialog> {
  late bool _autoEnabled;
  late bool _infoNotificationEnabled;

  @override
  void initState() {
    super.initState();
    _autoEnabled = widget.initialSettings.autoEnabled;
    _infoNotificationEnabled = widget.initialSettings.infoNotificationEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI伴读设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('自动伴读'),
            subtitle: const Text('阅读时自动启用AI伴读功能'),
            value: _autoEnabled,
            onChanged: (value) {
              setState(() {
                _autoEnabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('信息提示'),
            subtitle: const Text('显示AI伴读相关信息提示'),
            value: _infoNotificationEnabled,
            onChanged: (value) {
              setState(() {
                _infoNotificationEnabled = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(AiAccompanimentSettings(
              autoEnabled: _autoEnabled,
              infoNotificationEnabled: _infoNotificationEnabled,
            ));
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
