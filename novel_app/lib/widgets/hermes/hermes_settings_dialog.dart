import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/services/network_service_providers.dart';
import 'package:novel_app/services/hermes_chat_service.dart';
import '../../core/theme/app_colors.dart';

/// Hermes 配置对话框
class HermesSettingsDialog extends ConsumerStatefulWidget {
  const HermesSettingsDialog({super.key});

  @override
  ConsumerState<HermesSettingsDialog> createState() => _HermesSettingsDialogState();
}

class _HermesSettingsDialogState extends ConsumerState<HermesSettingsDialog> {
  final _backendUrlController = TextEditingController();
  final _apiTokenController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiService = ref.read(apiServiceWrapperProvider);
    final url = await apiService.getHost() ?? '';
    final token = await apiService.getToken() ?? '';
    if (mounted) {
      setState(() {
        _backendUrlController.text = url;
        _apiTokenController.text = token;
      });
    }
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _apiTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Hermes 设置'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _backendUrlController,
                decoration: const InputDecoration(
                  labelText: '后端地址',
                  hintText: 'http://192.168.1.100:3800',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiTokenController,
                decoration: const InputDecoration(
                  labelText: 'API Token',
                  hintText: '输入后端 API Token',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _testResult!.contains('成功')
                        ? context.appColors.successContainer
                        : context.appColors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.contains('成功') ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: _testResult!.contains('成功') ? context.appColors.success : context.appColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTesting ? null : _testConnection,
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('测试连接'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final apiService = ref.read(apiServiceWrapperProvider);
      final service = HermesChatService(apiService: apiService);
      final result = await service.healthCheck();
      final status = result['status']?.toString() ?? 'unknown';

      if (mounted) {
        setState(() {
          _isTesting = false;
          if (status == 'healthy') {
            _testResult = '连接成功！Hermes 服务正常运行';
          } else if (status == 'unconfigured') {
            _testResult = '后端未配置 Hermes API';
          } else {
            _testResult = '连接异常：${result['message'] ?? status}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = '连接失败：$e';
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final apiService = ref.read(apiServiceWrapperProvider);
    await apiService.setConfig(
      host: _backendUrlController.text.trim(),
      token: _apiTokenController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存'), duration: Duration(seconds: 1)),
      );
      Navigator.pop(context);
    }
  }
}
