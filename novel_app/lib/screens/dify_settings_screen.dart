import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dsl_engine/dsl_engine_config.dart';
import '../services/novel_agent/agent_engine_config.dart';
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
  final _aiWriterPromptController = TextEditingController();
  final _maxHistoryLengthController = TextEditingController();

  // DSL Engine 配置（现在是唯一的 AI 引擎）
  final _dslApiUrlController = TextEditingController();
  final _dslApiKeyController = TextEditingController();
  final _dslModelController = TextEditingController();

  // Agent Engine 配置（Hermes ReAct 对话专用）
  final _agentApiUrlController = TextEditingController();
  final _agentApiKeyController = TextEditingController();
  final _agentModelController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _aiWriterPromptController.dispose();
    _maxHistoryLengthController.dispose();
    _dslApiUrlController.dispose();
    _dslApiKeyController.dispose();
    _dslModelController.dispose();
    _agentApiUrlController.dispose();
    _agentApiKeyController.dispose();
    _agentModelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();

    // 加载 AI 设定
    _aiWriterPromptController.text =
        prefs.getString('ai_writer_prompt') ?? '';
    _maxHistoryLengthController.text =
        (prefs.getInt('max_history_length') ?? 3000).toString();

    // 加载 DSL Engine 配置
    _dslApiUrlController.text = await DslEngineConfig.getApiUrl();
    _dslApiKeyController.text = await DslEngineConfig.getApiKey();
    _dslModelController.text = await DslEngineConfig.getModel();

    // 加载 Agent Engine 配置
    _agentApiUrlController.text = await AgentEngineConfig.getApiUrl();
    _agentApiKeyController.text = await AgentEngineConfig.getApiKey();
    _agentModelController.text = await AgentEngineConfig.getModel();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'ai_writer_prompt', _aiWriterPromptController.text.trim());
      await prefs.setInt('max_history_length',
          int.tryParse(_maxHistoryLengthController.text) ?? 3000);

      // 保存 DSL Engine 配置
      await DslEngineConfig.setEnabled(true);
      await DslEngineConfig.setApiUrl(_dslApiUrlController.text.trim());
      await DslEngineConfig.setApiKey(_dslApiKeyController.text.trim());
      await DslEngineConfig.setModel(_dslModelController.text.trim());

      // 保存 Agent Engine 配置
      await AgentEngineConfig.setApiUrl(_agentApiUrlController.text.trim());
      await AgentEngineConfig.setApiKey(_agentApiKeyController.text.trim());
      await AgentEngineConfig.setModel(_agentModelController.text.trim());

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
        title: const Text('AI 配置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // ── DSL Engine（LLM 直连）配置 ──
                  const Text(
                    'DSL Engine（直连 LLM）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dslApiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'LLM API URL',
                      hintText: '例如: https://api.deepseek.com/v1',
                      border: OutlineInputBorder(),
                      helperText: 'OpenAI 兼容的 API 地址',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入 API URL';
                      }
                      if (Uri.tryParse(value)?.isAbsolute != true) {
                        return '请输入有效的 URL';
                      }
                      return null;
                    },
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入 API Key';
                      }
                      return null;
                    },
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
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Hermes Agent（ReAct 对话）配置 ──
                  const Text(
                    'Hermes Agent（ReAct 对话）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '为 Agent 对话单独配置 LLM 后端，留空则使用上方 DSL Engine 的配置',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _agentApiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Agent API URL',
                      hintText: '留空使用 DSL Engine 配置',
                      border: OutlineInputBorder(),
                      helperText: '如 https://api.openai.com/v1',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agentApiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Agent API Key',
                      hintText: '留空使用 DSL Engine 配置',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agentModelController,
                    decoration: const InputDecoration(
                      labelText: 'Agent 默认模型（可选）',
                      hintText: '留空使用 DSL Engine 配置',
                      border: OutlineInputBorder(),
                      helperText: '如 gpt-4o, deepseek-chat',
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── AI 设定 ──
                  const Text(
                    'AI 设定',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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