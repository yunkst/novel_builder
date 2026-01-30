import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/toast_utils.dart';

class DifySettingsScreen extends StatefulWidget {
  const DifySettingsScreen({super.key});

  @override
  State<DifySettingsScreen> createState() => _DifySettingsScreenState();
}

class _DifySettingsScreenState extends State<DifySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _difyUrlController = TextEditingController();
  final _flowTokenController = TextEditingController();
  final _structTokenController = TextEditingController();
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
    _flowTokenController.dispose();
    _structTokenController.dispose();
    _aiWriterPromptController.dispose();
    _maxHistoryLengthController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();

    // 加载基础配置
    _difyUrlController.text = prefs.getString('dify_url') ?? '';
    _aiWriterPromptController.text = prefs.getString('ai_writer_prompt') ?? '';
    _maxHistoryLengthController.text =
        (prefs.getInt('max_history_length') ?? 3000).toString();

    // 向后兼容：迁移旧的dify_token到新的双token架构
    final oldToken = prefs.getString('dify_token');
    final flowToken = prefs.getString('dify_flow_token');
    final structToken = prefs.getString('dify_struct_token');

    if (oldToken != null && oldToken.isNotEmpty) {
      // 如果存在旧token且新的flow_token不存在，则自动迁移
      if (flowToken == null || flowToken.isEmpty) {
        _flowTokenController.text = oldToken;
        // 保存迁移后的配置
        await prefs.setString('dify_flow_token', oldToken);
        // 清理旧配置（可选，建议保留一段时间）
        // await prefs.remove('dify_token');
      } else {
        _flowTokenController.text = flowToken;
      }

      // 如果struct_token不存在，使用旧token作为默认值
      if (structToken == null || structToken.isEmpty) {
        _structTokenController.text = oldToken;
        await prefs.setString('dify_struct_token', oldToken);
      } else {
        _structTokenController.text = structToken;
      }
    } else {
      // 没有旧token，直接加载新配置
      _flowTokenController.text = flowToken ?? '';
      _structTokenController.text = structToken ?? '';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dify_url', _difyUrlController.text.trim());
      await prefs.setString(
          'dify_flow_token', _flowTokenController.text.trim());
      await prefs.setString(
          'dify_struct_token', _structTokenController.text.trim());
      await prefs.setString(
          'ai_writer_prompt', _aiWriterPromptController.text.trim());
      await prefs.setInt('max_history_length',
          int.tryParse(_maxHistoryLengthController.text) ?? 3000);

      if (mounted) {
        ToastUtils.showSuccess('Dify 设置已保存');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dify 配置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                    controller: _flowTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Flow Token (流式响应)',
                      hintText: '用于特写、总结等流式AI功能',
                      border: OutlineInputBorder(),
                      helperText: '当前所有AI功能使用此token',
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Flow Token';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _structTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Struct Token (结构化响应)',
                      hintText: '用于未来的结构化响应功能',
                      border: OutlineInputBorder(),
                      helperText: '为未来功能预留，可选填',
                    ),
                    obscureText: true,
                    // struct_token是可选的，不需要验证
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
