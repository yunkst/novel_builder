/// LLM 配置管理页
///
/// 用户可增删改查多个 LLM 配置，设置默认配置，拖拽排序。
/// AI Agent 和章节生成时可选择不同配置。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/services/ai_service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../models/llm_config.dart';
import '../../services/logger_service.dart';

class LlmConfigManagementScreen extends ConsumerStatefulWidget {
  const LlmConfigManagementScreen({super.key});

  @override
  ConsumerState<LlmConfigManagementScreen> createState() =>
      _LlmConfigManagementScreenState();
}

class _LlmConfigManagementScreenState
    extends ConsumerState<LlmConfigManagementScreen> {
  List<LlmConfig> _configs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final service = ref.read(llmConfigServiceProvider);
    await service.ensureMigratedFromLegacy();
    final configs = await service.getAllConfigs();
    if (mounted) {
      setState(() {
        _configs = configs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM 配置管理'),
        actions: [
          IconButton(
            onPressed: _addConfig,
            icon: const Icon(Icons.add),
            tooltip: '添加配置',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? _buildEmptyState()
              : _buildConfigList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('暂无 LLM 配置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('点击右上角 + 添加配置', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildConfigList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _configs.length,
      itemBuilder: (context, index) {
        final config = _configs[index];
        return _buildConfigCard(config, index);
      },
    );
  }

  Widget _buildConfigCard(LlmConfig config, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            config.isDefault ? Icons.star : Icons.star_border,
            color: config.isDefault ? context.appColors.warning : null,
          ),
          tooltip: config.isDefault ? '默认配置' : '设为默认',
          onPressed: config.isDefault ? null : () => _setDefault(config.id!),
        ),
        title: Row(
          children: [
            Expanded(child: Text(config.name)),
            if (config.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('默认',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
          ],
        ),
        subtitle: Text(
          '${config.apiUrl}\n模型: ${config.model.isEmpty ? "未设置" : config.model}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editConfig(config);
                break;
              case 'duplicate':
                _duplicateConfig(config);
                break;
              case 'delete':
                if (config.isDefault && _configs.length > 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请先将其他配置设为默认再删除默认配置')),
                  );
                } else {
                  _deleteConfig(config);
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            const PopupMenuItem(value: 'duplicate', child: Text('复制')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
        onTap: () => _editConfig(config),
      ),
    );
  }

  Future<void> _addConfig() async {
    final result = await showDialog<LlmConfig>(
      context: context,
      builder: (context) => const _LlmConfigEditDialog(),
    );
    if (result != null) {
      await _saveConfig(result);
    }
  }

  Future<void> _editConfig(LlmConfig config) async {
    final result = await showDialog<LlmConfig>(
      context: context,
      builder: (context) => _LlmConfigEditDialog(config: config),
    );
    if (result != null) {
      await _saveConfig(result);
    }
  }

  Future<void> _duplicateConfig(LlmConfig config) async {
    final now = DateTime.now();
    final newConfig = config.copyWith(
      id: null,
      name: '${config.name} (副本)',
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );
    await _saveConfig(newConfig);
  }

  Future<void> _setDefault(int id) async {
    final service = ref.read(llmConfigServiceProvider);
    await service.setDefault(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已设为默认配置')),
      );
    }
    await _loadConfigs();
  }

  Future<void> _deleteConfig(LlmConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除配置「${config.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && config.id != null) {
      final service = ref.read(llmConfigServiceProvider);
      await service.deleteConfig(config.id!);
      await _loadConfigs();
    }
  }

  Future<void> _saveConfig(LlmConfig config) async {
    final service = ref.read(llmConfigServiceProvider);
    try {
      await service.saveConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已保存')),
        );
      }
      await _loadConfigs();
    } catch (e) {
      LoggerService.instance.e('保存 LLM 配置失败: $e',
          category: LogCategory.ai, tags: ['llm_config', 'save_error']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }
}

/// LLM 配置编辑对话框
class _LlmConfigEditDialog extends StatefulWidget {
  final LlmConfig? config;

  const _LlmConfigEditDialog({this.config});

  @override
  State<_LlmConfigEditDialog> createState() => _LlmConfigEditDialogState();
}

class _LlmConfigEditDialogState extends State<_LlmConfigEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  bool _isDefault = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config?.name ?? '');
    _apiUrlController =
        TextEditingController(text: widget.config?.apiUrl ?? '');
    _apiKeyController =
        TextEditingController(text: widget.config?.apiKey ?? '');
    _modelController =
        TextEditingController(text: widget.config?.model ?? '');
    _isDefault = widget.config?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.config != null;
    return AlertDialog(
      title: Text(isEditing ? '编辑配置' : '添加配置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '配置名称',
                hintText: '如：DeepSeek、OpenAI',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: 'https://api.deepseek.com/v1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureApiKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: '默认模型',
                hintText: 'deepseek-chat（可留空）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('设为默认配置'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final apiUrl = _apiUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入配置名称')),
      );
      return;
    }
    if (apiUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API URL')),
      );
      return;
    }
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API Key')),
      );
      return;
    }

    final now = DateTime.now();
    final config = LlmConfig(
      id: widget.config?.id,
      name: name,
      apiUrl: apiUrl,
      apiKey: apiKey,
      model: model,
      isDefault: _isDefault,
      sortOrder: widget.config?.sortOrder ?? 0,
      createdAt: widget.config?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, config);
  }
}
