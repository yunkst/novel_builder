import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service_wrapper.dart';
import '../utils/toast_utils.dart';

class BackendSettingsScreen extends StatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  State<BackendSettingsScreen> createState() => _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends State<BackendSettingsScreen> {
  final ApiServiceWrapper _api = ApiServiceWrapper();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _isLoading = true;

  static const String _prefsHostKey = 'backend_host';
  static const String _prefsTokenKey = 'backend_token';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString(_prefsHostKey) ?? '';
      final token = prefs.getString(_prefsTokenKey) ?? '';
      _hostController.text = host;
      _tokenController.text = token;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConfig() async {
    final host = _hostController.text.trim();
    final token = _tokenController.text.trim();

    if (host.isEmpty) {
      ToastUtils.showWarning(context, '请填写后端 HOST');
      return;
    }
    if (!host.startsWith('http://') && !host.startsWith('https://')) {
      ToastUtils.showWarning(context, 'HOST 应以 http:// 或 https:// 开头');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _api.setConfig(host: host, token: token);
      if (mounted) {
        ToastUtils.showSuccess(context, '已保存后端配置');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, '保存失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    _hostController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('后端服务配置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'HOST',
                      hintText: '例如: http://127.0.0.1:8000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: 'TOKEN',
                      hintText: '选填: 访问令牌',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveConfig,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
