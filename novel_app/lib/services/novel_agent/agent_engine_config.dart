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
