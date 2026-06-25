/// LLM 配置服务
///
/// 统一管理 LLM 配置序列的读取、切换和迁移。
/// 所有 AI 调用路径（WritingService、Hermes Agent）都通过此服务获取 LLM 配置。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers/database_providers.dart';
import '../models/llm_config.dart' as app;
import '../services/dsl_engine/llm_provider.dart' as llm;
import '../services/logger_service.dart';

class LlmConfigService {
  final Ref _ref;

  static const String _activeProfileKey = 'active_llm_profile_id';
  static const String _migratedKey = 'llm_configs_migrated';
  static const String _scenarioPrefix = 'active_llm_profile_';

  LlmConfigService(this._ref);

  // ── 查询 ──

  /// 获取所有配置
  Future<List<app.LlmConfig>> getAllConfigs() async {
    final repo = _ref.read(llmConfigRepositoryProvider);
    return repo.getAll();
  }

  /// 获取当前激活的全局配置（优先场景配置 → 默认配置 → 第一条）
  Future<app.LlmConfig?> getActiveConfig({String? scenarioId}) async {
    final repo = _ref.read(llmConfigRepositoryProvider);
    final prefs = await SharedPreferences.getInstance();

    // 1. 场景级配置
    if (scenarioId != null) {
      final scenarioProfileId =
          prefs.getInt('$_scenarioPrefix$scenarioId');
      if (scenarioProfileId != null) {
        final config = await repo.getById(scenarioProfileId);
        if (config != null) return config;
      }
    }

    // 2. 全局激活配置
    final activeId = prefs.getInt(_activeProfileKey);
    if (activeId != null) {
      final config = await repo.getById(activeId);
      if (config != null) return config;
    }

    // 3. 默认配置
    final defaultConfig = await repo.getDefault();
    if (defaultConfig != null) return defaultConfig;

    // 4. 第一条配置
    final all = await repo.getAll();
    return all.isNotEmpty ? all.first : null;
  }

  /// 获取默认配置 ID
  Future<int?> getDefaultConfigId() async {
    final repo = _ref.read(llmConfigRepositoryProvider);
    final config = await repo.getDefault();
    return config?.id;
  }

  // ── 设置激活 ──

  /// 设置全局激活配置
  Future<void> setActiveConfig(int configId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeProfileKey, configId);
    LoggerService.instance.i('全局激活 LLM 配置: id=$configId',
        category: LogCategory.ai, tags: ['llm_config', 'set_active']);
  }

  /// 设置场景级激活配置（configId 为 null 时清除场景覆盖）
  Future<void> setActiveConfigForScenario(
      String scenarioId, int? configId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_scenarioPrefix$scenarioId';
    if (configId != null) {
      await prefs.setInt(key, configId);
    } else {
      await prefs.remove(key);
    }
    LoggerService.instance.i(
        '场景 $scenarioId 激活 LLM 配置: id=$configId',
        category: LogCategory.ai,
        tags: ['llm_config', 'set_active_scenario']);
  }

  // ── 构建 LlmProvider 配置 ──

  /// 将 LlmConfig 转换为 LlmProvider 的 LlmConfig
  llm.LlmConfig buildLlmProviderConfig(app.LlmConfig config) {
    return llm.LlmConfig(
      baseUrl: config.apiUrl,
      apiKey: config.apiKey,
      defaultModel: config.model,
    );
  }

  // ── CRUD 委托 ──

  Future<int> saveConfig(app.LlmConfig config) async {
    final repo = _ref.read(llmConfigRepositoryProvider);
    final id = await repo.save(config);
    // 如果是第一条或标记为默认，设置默认
    if (config.isDefault) {
      await repo.setDefault(id);
    } else {
      final count = await repo.count();
      if (count == 1) {
        await repo.setDefault(id);
      }
    }
    return id;
  }

  Future<void> deleteConfig(int id) async {
    final repo = _ref.read(llmConfigRepositoryProvider);
    await repo.delete(id);
  }

  Future<void> setDefault(int id) async {
    final repo = _ref.read(llmConfigRepositoryProvider);
    await repo.setDefault(id);
  }

  // ── 旧配置迁移 ──

  /// 首次运行时从旧 DslEngineConfig 迁移数据到 llm_configs 表
  ///
  /// 迁移逻辑：
  /// 1. 检查 _migratedKey 是否已标记
  /// 2. 读取旧 DslEngineConfig 的 apiUrl/apiKey/model
  /// 3. 如果有有效数据，创建一条默认配置
  /// 4. 遍历 AgentEngineConfig 的场景覆盖，为每个有覆盖的场景创建配置或设置引用
  /// 5. 标记迁移完成
  Future<void> ensureMigratedFromLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    LoggerService.instance.i('开始从旧配置迁移到 llm_configs 表...',
        category: LogCategory.ai, tags: ['llm_config', 'migration']);

    final repo = _ref.read(llmConfigRepositoryProvider);

    // 读取旧全局配置
    final apiUrl = prefs.getString('dsl_engine_api_url') ?? '';
    final apiKey = prefs.getString('dsl_engine_api_key') ?? '';
    final model = prefs.getString('dsl_engine_model') ?? '';

    if (apiUrl.isNotEmpty && apiKey.isNotEmpty) {
      final now = DateTime.now();
      final id = await repo.save(app.LlmConfig(
        name: '默认配置',
        apiUrl: apiUrl,
        apiKey: apiKey,
        model: model,
        isDefault: true,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));
      await repo.setDefault(id);
      LoggerService.instance.i('迁移旧全局配置到 id=$id',
          category: LogCategory.ai,
          tags: ['llm_config', 'migration', 'global']);
    }

    // 迁移 Agent 场景级覆盖
    final scenarioKeys = [
      'agent_writing_scenario',
      'agent_webview_extract_scenario',
    ];
    for (int i = 0; i < scenarioKeys.length; i++) {
      final scenarioId = scenarioKeys[i];
      final sApiUrl = prefs.getString('agent_${scenarioId}_api_url') ?? '';
      final sApiKey = prefs.getString('agent_${scenarioId}_api_key') ?? '';
      final sModel = prefs.getString('agent_${scenarioId}_model') ?? '';

      if (sApiUrl.isNotEmpty && sApiKey.isNotEmpty) {
        final now = DateTime.now();
        final id = await repo.save(app.LlmConfig(
          name: '场景-${scenarioId.replaceAll('_', ' ')}',
          apiUrl: sApiUrl,
          apiKey: sApiKey,
          model: sModel,
          isDefault: false,
          sortOrder: i + 1,
          createdAt: now,
          updatedAt: now,
        ));
        // 设置场景激活
        await setActiveConfigForScenario(scenarioId, id);
        LoggerService.instance.i('迁移场景 $scenarioId 配置到 id=$id',
            category: LogCategory.ai,
            tags: ['llm_config', 'migration', 'scenario']);
      }
    }

    // 标记迁移完成
    await prefs.setBool(_migratedKey, true);
    LoggerService.instance.i('旧配置迁移完成',
        category: LogCategory.ai, tags: ['llm_config', 'migration', 'done']);
  }
}
