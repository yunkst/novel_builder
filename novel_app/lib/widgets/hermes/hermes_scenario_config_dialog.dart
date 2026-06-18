import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/services/novel_agent/agent_engine_config.dart';
import 'package:novel_app/services/novel_agent/agent_scenario_factory.dart';
import 'package:novel_app/utils/toast_utils.dart';

/// 场景级 LLM 配置弹框
///
/// 为当前 Agent 场景单独配置 LLM 后端（API URL / Key / Model）。
/// 留空时回退到全局默认（设置 → AI 配置中的全局默认 LLM）。
///
/// 调用方：HermesChatDialog 右上角的"场景配置"按钮。
class HermesScenarioConfigDialog extends ConsumerStatefulWidget {
  const HermesScenarioConfigDialog({
    super.key,
    required this.scenarioId,
  });

  /// 场景标识（'writing' / 'webview_extract' / ...）
  final String scenarioId;

  @override
  ConsumerState<HermesScenarioConfigDialog> createState() =>
      _HermesScenarioConfigDialogState();
}

class _HermesScenarioConfigDialogState
    extends ConsumerState<HermesScenarioConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasOverride = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    _apiUrlController.text =
        await AgentEngineConfig.getScenarioApiUrl(widget.scenarioId);
    _apiKeyController.text =
        await AgentEngineConfig.getScenarioApiKey(widget.scenarioId);
    _modelController.text =
        await AgentEngineConfig.getScenarioModel(widget.scenarioId);
    _hasOverride =
        await AgentEngineConfig.hasScenarioOverride(widget.scenarioId);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
    });
    try {
      await AgentEngineConfig.setScenarioApiUrl(
          widget.scenarioId, _apiUrlController.text.trim());
      await AgentEngineConfig.setScenarioApiKey(
          widget.scenarioId, _apiKeyController.text.trim());
      await AgentEngineConfig.setScenarioModel(
          widget.scenarioId, _modelController.text.trim());
      if (!mounted) return;
      ToastUtils.showSuccess('场景配置已保存');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showError('保存失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _clearOverride() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空场景覆盖'),
        content: const Text(
            '确定要清空当前场景的 LLM 配置吗？\n清空后将使用全局默认 LLM（设置 → AI 配置）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AgentEngineConfig.clearScenarioConfig(widget.scenarioId);
    _apiUrlController.clear();
    _apiKeyController.clear();
    _modelController.clear();
    if (!mounted) return;
    setState(() {
      _hasOverride = false;
    });
    ToastUtils.showSuccess('场景覆盖已清空');
  }

  String get _scenarioDisplayName {
    final info = AgentScenarioFactory.availableScenarios
        .where((s) => s.id == widget.scenarioId)
        .firstOrNull;
    return info?.displayName ?? widget.scenarioId;
  }

  String get _scenarioIcon {
    final info = AgentScenarioFactory.availableScenarios
        .where((s) => s.id == widget.scenarioId)
        .firstOrNull;
    return info?.icon ?? '🤖';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 480,
          maxHeight: 560,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              child: Row(
                children: [
                  Text(_scenarioIcon, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_scenarioDisplayName — LLM 配置',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_hasOverride)
                          Text(
                            '已自定义',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 表单
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        children: [
                          // 说明文字
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '留空使用全局默认 LLM。\n全局默认在 设置 → AI 配置 中配置。',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // API URL
                          TextFormField(
                            controller: _apiUrlController,
                            decoration: const InputDecoration(
                              labelText: 'API URL',
                              hintText: '留空使用全局默认',
                              border: OutlineInputBorder(),
                              helperText: '如 https://api.openai.com/v1',
                            ),
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 12),
                          // API Key
                          TextFormField(
                            controller: _apiKeyController,
                            decoration: const InputDecoration(
                              labelText: 'API Key',
                              hintText: '留空使用全局默认',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          // Model
                          TextFormField(
                            controller: _modelController,
                            decoration: const InputDecoration(
                              labelText: '默认模型（可选）',
                              hintText: '留空使用全局默认',
                              border: OutlineInputBorder(),
                              helperText: '如 gpt-4o, deepseek-chat',
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1),
            // 按钮栏
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _isLoading || _isSaving ? null : _clearOverride,
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: const Text('清空覆盖'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _isLoading || _isSaving ? null : () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading || _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
