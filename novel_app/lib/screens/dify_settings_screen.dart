import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/llm_config_management_screen.dart';
import '../utils/toast_utils.dart';

/// AI 配置页面
///
/// 提供两个分组：
/// 1. **LLM 配置管理** — 跳转到配置管理页（增删改查多配置、设默认）
/// 2. **AI 设定** — 作家设定 prompt 和历史字符数
class DifySettingsScreen extends StatefulWidget {
  const DifySettingsScreen({super.key});

  @override
  State<DifySettingsScreen> createState() => _DifySettingsScreenState();
}

class _DifySettingsScreenState extends State<DifySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
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
    _aiWriterPromptController.dispose();
    _maxHistoryLengthController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _aiWriterPromptController.text =
        prefs.getString('ai_writer_prompt') ?? '';
    _maxHistoryLengthController.text =
        (prefs.getInt('max_history_length') ?? 3000).toString();
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'ai_writer_prompt', _aiWriterPromptController.text.trim());
      await prefs.setInt('max_history_length',
          int.tryParse(_maxHistoryLengthController.text) ?? 3000);
      if (mounted) {
        ToastUtils.showSuccess('设置已保存');
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
                  // ── LLM 配置管理 ──
                  const Text(
                    'LLM 配置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '管理多个 LLM 后端配置（API URL、Key、模型），在 Agent 和章节生成中切换使用。',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('LLM 配置管理'),
                      subtitle: const Text('添加、编辑、删除 LLM 配置'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const LlmConfigManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
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
