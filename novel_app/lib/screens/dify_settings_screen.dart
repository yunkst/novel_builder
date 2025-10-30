import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DifySettingsScreen extends StatefulWidget {
  const DifySettingsScreen({super.key});

  @override
  State<DifySettingsScreen> createState() => _DifySettingsScreenState();
}

class _DifySettingsScreenState extends State<DifySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _difyUrlController = TextEditingController();
  final _difyTokenController = TextEditingController();
  final _aiWriterPromptController = TextEditingController();
  final _maxHistoryLengthController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _difyUrlController.dispose();
    _difyTokenController.dispose();
    _aiWriterPromptController.dispose();
    _maxHistoryLengthController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    _difyUrlController.text = prefs.getString('dify_url') ?? '';
    _difyTokenController.text = prefs.getString('dify_token') ?? '';
    _aiWriterPromptController.text = prefs.getString('ai_writer_prompt') ?? '';
    _maxHistoryLengthController.text =
        (prefs.getInt('max_history_length') ?? 3000).toString();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dify_url', _difyUrlController.text.trim());
      await prefs.setString('dify_token', _difyTokenController.text.trim());
      await prefs.setString(
          'ai_writer_prompt', _aiWriterPromptController.text.trim());
      await prefs.setInt('max_history_length',
          int.tryParse(_maxHistoryLengthController.text) ?? 3000);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dify 设置已保存')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dify 配置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _difyUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Dify URL',
                      hintText: '例如: https://api.dify.ai/v1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Dify URL';
                      }
                      if (Uri.tryParse(value)?.isAbsolute != true) {
                        return '请输入有效的 URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _difyTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Dify API Token',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Dify API Token';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _aiWriterPromptController,
                    decoration: const InputDecoration(
                      labelText: 'AI 作家设定',
                      hintText: '例如：你是一个专业的网络小说作家...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _maxHistoryLengthController,
                    decoration: const InputDecoration(
                      labelText: '最长历史字符数量',
                      hintText: '例如: 3000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
    );
  }
}
