import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dsl_engine/dsl_engine_config.dart';
import '../utils/toast_utils.dart';

/// AI 配置页面
///
/// 提供两个分组：
/// 1. **全局默认 LLM** — 所有 Agent 场景的默认后端（url / key / model）。
/// 2. **AI 设定** — 作家设定 prompt 和历史字符数。
///
/// 场景级 LLM 覆盖配置在 hermes 对话窗口右上角的"场景配置"按钮中编辑。
class DifySettingsScreen extends ConsumerWidget {
  const DifySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DifySettingsContent();
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

  // 全局默认 LLM 配置（原 DSL Engine）
  final _dslApiUrlController = TextEditingController();
  final _dslApiKeyController = TextEditingController();
  final _dslModelController = TextEditingController();

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

    // 加载全局默认 LLM 配置
    _dslApiUrlController.text = await DslEngineConfig.getApiUrl();
    _dslApiKeyController.text = await DslEngineConfig.getApiKey();
    _dslModelController.text = await DslEngineConfig.getModel();

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

      // 保存全局默认 LLM 配置
      await DslEngineConfig.setEnabled(true);
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
                  // ── 全局默认 LLM 配置 ──
                  const Text(
                    '全局默认 LLM',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '所有 Agent 场景的默认后端。场景级配置在 hermes 窗口右上角"场景配置"中设置，留空时回退到此默认。',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      hintText: '如 deepseek-chat',
                      border: OutlineInputBorder(),
                      helperText: '如 deepseek-chat, gpt-4o',
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
