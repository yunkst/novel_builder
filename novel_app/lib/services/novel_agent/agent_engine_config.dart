/// Agent Engine 配置管理
///
/// 管理 Hermes Agent（ReAct 循环）的 LLM 后端配置，存储在 SharedPreferences 中。
/// 与 DslEngineConfig 独立，用户可为 Agent 对话配置不同的 LLM 后端。
///
/// 回退机制：当 Agent 专属配置为空时，自动回退到 DSL Engine 的配置，
/// 保证向后兼容——未配置 Agent 后端的现有用户行为不变。
library;

import '../../services/preferences_service.dart';
import '../dsl_engine/dsl_engine_config.dart';
import 'package:novel_app/services/logger_service.dart';

class AgentEngineConfig {
  const AgentEngineConfig._();

  // -- 配置项 key --

  static const _keyApiUrl = 'agent_engine_api_url';
  static const _keyApiKey = 'agent_engine_api_key';
  static const _keyModel = 'agent_engine_model';

  /// 场景级覆盖配置的 key 模板
  ///
  /// 命名规则：`agent_engine_{scenarioId}_{suffix}`，例如
  /// `agent_engine_writing_api_url`。场景级配置留空时回退到全局默认。
  static String _scenarioKeyUrl(String scenarioId) =>
      'agent_engine_${scenarioId}_api_url';
  static String _scenarioKeyApiKey(String scenarioId) =>
      'agent_engine_${scenarioId}_api_key';
  static String _scenarioKeyModel(String scenarioId) =>
      'agent_engine_${scenarioId}_model';

  // -- 读取（Agent 专属值，不含回退） --

  /// Agent 专属 LLM API 基础 URL（如 https://api.openai.com/v1）
  static Future<String> getApiUrl() async {
    return await PreferencesService.instance.getString(_keyApiUrl);
  }

  /// Agent 专属 LLM API Key
  static Future<String> getApiKey() async {
    return await PreferencesService.instance.getString(_keyApiKey);
  }

  /// Agent 专属默认模型名（留空则回退到 DSL Engine 设置）
  static Future<String> getModel() async {
    return await PreferencesService.instance.getString(_keyModel);
  }

  // -- 回退方法（Agent 使用这些） --

  /// 获取有效的 API URL
  /// 优先使用 Agent 专属配置，为空则回退到 DSL Engine 配置
  static Future<String> getEffectiveApiUrl() async {
    final agentUrl = await getApiUrl();
    if (agentUrl.isNotEmpty) return agentUrl;
    return await DslEngineConfig.getApiUrl();
  }

  /// 获取有效的 API Key
  /// 优先使用 Agent 专属配置，为空则回退到 DSL Engine 配置
  static Future<String> getEffectiveApiKey() async {
    final agentKey = await getApiKey();
    if (agentKey.isNotEmpty) return agentKey;
    return await DslEngineConfig.getApiKey();
  }

  /// 获取有效的模型名
  /// 优先使用 Agent 专属配置 → DSL Engine 配置 → 硬编码默认值
  static Future<String> getEffectiveModel() async {
    final agentModel = await getModel();
    if (agentModel.isNotEmpty) return agentModel;
    final dslModel = await DslEngineConfig.getModel();
    if (dslModel.isNotEmpty) return dslModel;
    return 'deepseek-chat';
  }

  /// 检查 Agent 配置是否完整（考虑回退）
  /// 当 Agent 专属或 DSL Engine 任一配置完整时返回 true
  static Future<bool> isConfigured() async {
    final url = await getEffectiveApiUrl();
    final key = await getEffectiveApiKey();
    final configured = url.isNotEmpty && key.isNotEmpty;
    if (!configured) {
      LoggerService.instance.w(
        'Agent Engine 配置不完整: url=${url.isNotEmpty}, key=${key.isNotEmpty}',
        category: LogCategory.ai,
        tags: ['agent', 'config'],
      );
    }
    return configured;
  }

  // ========== 场景级覆盖配置 ==========
  //
  // 每个 Agent 场景（如 writing / webview_extract）可独立配置 LLM 后端。
  // 留空时按以下优先级回退：场景级 → Agent 全局 → DSL Engine → 硬编码默认。
  // 存储 key 模板：`agent_engine_{scenarioId}_{suffix}`

  /// 获取指定场景的 API URL（不含回退）
  static Future<String> getScenarioApiUrl(String scenarioId) async {
    return await PreferencesService.instance
        .getString(_scenarioKeyUrl(scenarioId));
  }

  /// 获取指定场景的 API Key（不含回退）
  static Future<String> getScenarioApiKey(String scenarioId) async {
    return await PreferencesService.instance
        .getString(_scenarioKeyApiKey(scenarioId));
  }

  /// 获取指定场景的 Model（不含回退）
  static Future<String> getScenarioModel(String scenarioId) async {
    return await PreferencesService.instance
        .getString(_scenarioKeyModel(scenarioId));
  }

  /// 写入指定场景的 API URL
  static Future<void> setScenarioApiUrl(
      String scenarioId, String value) async {
    await PreferencesService.instance
        .setString(_scenarioKeyUrl(scenarioId), value);
    LoggerService.instance.d(
      'Agent Engine 场景配置写入: scenario=$scenarioId, apiUrl 长度=${value.length}',
      category: LogCategory.ai,
      tags: ['agent', 'config', 'scenario'],
    );
  }

  /// 写入指定场景的 API Key
  static Future<void> setScenarioApiKey(
      String scenarioId, String value) async {
    await PreferencesService.instance
        .setString(_scenarioKeyApiKey(scenarioId), value);
    LoggerService.instance.d(
      'Agent Engine 场景配置写入: scenario=$scenarioId, apiKey 长度=${value.length}',
      category: LogCategory.ai,
      tags: ['agent', 'config', 'scenario'],
    );
  }

  /// 写入指定场景的 Model
  static Future<void> setScenarioModel(
      String scenarioId, String value) async {
    await PreferencesService.instance
        .setString(_scenarioKeyModel(scenarioId), value);
    LoggerService.instance.d(
      'Agent Engine 场景配置写入: scenario=$scenarioId, model=$value',
      category: LogCategory.ai,
      tags: ['agent', 'config', 'scenario'],
    );
  }

  /// 清除指定场景的所有覆盖配置
  ///
  /// 同时删除该场景的 url / key / model 三个 key。
  static Future<void> clearScenarioConfig(String scenarioId) async {
    await PreferencesService.instance.remove(_scenarioKeyUrl(scenarioId));
    await PreferencesService.instance.remove(_scenarioKeyApiKey(scenarioId));
    await PreferencesService.instance.remove(_scenarioKeyModel(scenarioId));
    LoggerService.instance.d(
      'Agent Engine 场景配置已清空: scenario=$scenarioId',
      category: LogCategory.ai,
      tags: ['agent', 'config', 'scenario'],
    );
  }

  /// 检查指定场景是否有任何覆盖配置（任一字段非空）
  static Future<bool> hasScenarioOverride(String scenarioId) async {
    final url = await getScenarioApiUrl(scenarioId);
    final key = await getScenarioApiKey(scenarioId);
    final model = await getScenarioModel(scenarioId);
    return url.isNotEmpty || key.isNotEmpty || model.isNotEmpty;
  }

  // -- 带回退的场景级读取 --

  /// 获取场景级有效的 API URL
  ///
  /// 优先级：场景级 → Agent 全局 → DSL Engine
  static Future<String> getEffectiveApiUrlForScenario(
      String scenarioId) async {
    final scenarioUrl = await getScenarioApiUrl(scenarioId);
    if (scenarioUrl.isNotEmpty) return scenarioUrl;
    return await getEffectiveApiUrl();
  }

  /// 获取场景级有效的 API Key
  ///
  /// 优先级：场景级 → Agent 全局 → DSL Engine
  static Future<String> getEffectiveApiKeyForScenario(
      String scenarioId) async {
    final scenarioKey = await getScenarioApiKey(scenarioId);
    if (scenarioKey.isNotEmpty) return scenarioKey;
    return await getEffectiveApiKey();
  }

  /// 获取场景级有效的 Model
  ///
  /// 优先级：场景级 → Agent 全局 → DSL Engine → 硬编码默认
  static Future<String> getEffectiveModelForScenario(
      String scenarioId) async {
    final scenarioModel = await getScenarioModel(scenarioId);
    if (scenarioModel.isNotEmpty) return scenarioModel;
    return await getEffectiveModel();
  }

  /// 检查指定场景的 LLM 配置是否完整（考虑所有回退层级）
  static Future<bool> isConfiguredForScenario(String scenarioId) async {
    final url = await getEffectiveApiUrlForScenario(scenarioId);
    final key = await getEffectiveApiKeyForScenario(scenarioId);
    return url.isNotEmpty && key.isNotEmpty;
  }

  // -- 写入（Agent 专属值） --

  static Future<void> setApiUrl(String value) async {
    await PreferencesService.instance.setString(_keyApiUrl, value);
    LoggerService.instance.d(
      'Agent Engine 配置写入: apiUrl 长度=${value.length}',
      category: LogCategory.ai,
      tags: ['agent', 'config'],
    );
  }

  static Future<void> setApiKey(String value) async {
    await PreferencesService.instance.setString(_keyApiKey, value);
    LoggerService.instance.d(
      'Agent Engine 配置写入: apiKey 长度=${value.length}',
      category: LogCategory.ai,
      tags: ['agent', 'config'],
    );
  }

  static Future<void> setModel(String value) async {
    await PreferencesService.instance.setString(_keyModel, value);
    LoggerService.instance.d(
      'Agent Engine 配置写入: model=$value',
      category: LogCategory.ai,
      tags: ['agent', 'config'],
    );
  }
}
