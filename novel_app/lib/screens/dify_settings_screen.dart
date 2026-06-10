import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dsl_engine/dsl_engine_config.dart';
import '../utils/toast_utils.dart';

class DifySettingsScreen extends ConsumerWidget {
  const DifySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DifySettingsContent();
  }
}

class DifySettingsContent extends StatefulWidget {
  const DifySettingsContent({super.key});

  @override
  State<DifySettingsContent> createState() => _DifySettingsContentState();
}

class _DifySettingsContentState extends State<DifySettingsContent> {
  final _formKey = GlobalKey<FormState>();
  final _difyUrlController = TextEditingController();
  final _flowTokenController = TextEditingController();
  final _structTokenController = TextEditingController();
  final _aiWriterPromptController = TextEditingController();
  final _maxHistoryLengthController = TextEditingController();

  // DSL Engine 配置
  final _dslApiUrlController = TextEditingController();
  final _dslApiKeyController = TextEditingController();
  final _dslModelController = TextEditingController();
  bool _dslEnabled = false;

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
    _dslApiUrlController.dispose();
    _dslApiKeyController.dispose();
    _dslModelController.dispose();
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

    await _loadDslSettings();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadDslSettings() async {
    _dslEnabled = await DslEngineConfig.isEnabled();
    _dslApiUrlController.text = await DslEngineConfig.getApiUrl();
    _dslApiKeyController.text = await DslEngineConfig.getApiKey();
    _dslModelController.text = await DslEngineConfig.getModel();
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

      // 保存 DSL Engine 配置
      await DslEngineConfig.setEnabled(_dslEnabled);
      await DslEngineConfig.setApiUrl(_dslApiUrlController.text.trim());
      await DslEngineConfig.setApiKey(_dslApiKeyController.text.trim());
      await DslEngineConfig.setModel(_dslModelController.text.trim());

      if (mounted) {
        ToastUtils.showSuccess('设置已保存');
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
                  _buildDslEngineSection(),
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

  /// DSL Engine 配置区块
  Widget _buildDslEngineSection() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'DSL Engine（直连 LLM）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Switch(
              value: _dslEnabled,
              onChanged: (v) => setState(() => _dslEnabled = v),
            ),
          ],
        ),
        if (_dslEnabled) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _dslApiUrlController,
            decoration: const InputDecoration(
              labelText: 'LLM API URL',
              hintText: '例如: https://api.deepseek.com/v1',
              border: OutlineInputBorder(),
              helperText: 'OpenAI 兼容的 API 地址',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _dslApiKeyController,
            decoration: const InputDecoration(
              labelText: 'LLM API Key',
              hintText: 'sk-xxx',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _dslModelController,
            decoration: const InputDecoration(
              labelText: '默认模型（可选）',
              hintText: '留空使用 DSL 内置模型',
              border: OutlineInputBorder(),
              helperText: '如 deepseek-chat, deepseek-v4-pro',
            ),
          ),
        ],
      ],
    );
  }
}
