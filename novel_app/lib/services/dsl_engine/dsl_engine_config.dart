/// DSL Engine 配置管理
///
/// 管理 DSL Engine 模式的配置项，存储在 SharedPreferences 中。
/// 与 Dify 配置独立，用户可同时配置两套。
library;

import '../../services/preferences_service.dart';
import 'package:novel_app/services/logger_service.dart';

class DslEngineConfig {
  const DslEngineConfig._();

  // -- 配置项 key --

  static const _keyEnabled = 'dsl_engine_enabled';
  static const _keyApiUrl = 'dsl_engine_api_url';
  static const _keyApiKey = 'dsl_engine_api_key';
  static const _keyModel = 'dsl_engine_model';

  // -- 读取 --

  /// 是否启用 DSL Engine
  static Future<bool> isEnabled() async {
    return await PreferencesService.instance.getBool(_keyEnabled);
  }

  /// LLM API 基础 URL（如 https://api.deepseek.com/v1）
  static Future<String> getApiUrl() async {
    return await PreferencesService.instance.getString(_keyApiUrl);
  }

  /// LLM API Key
  static Future<String> getApiKey() async {
    return await PreferencesService.instance.getString(_keyApiKey);
  }

  /// 默认模型名（留空则使用 DSL 中配置的 model）
  static Future<String> getModel() async {
    return await PreferencesService.instance.getString(_keyModel);
  }

  // -- 写入 --

  static Future<void> setEnabled(bool value) async {
    await PreferencesService.instance.setBool(_keyEnabled, value);
    LoggerService.instance.d(
      'DSL Engine 配置写入: enabled=$value',
      category: LogCategory.ai,
      tags: ['dsl', 'config'],
    );
  }

  static Future<void> setApiUrl(String value) async {
    await PreferencesService.instance.setString(_keyApiUrl, value);
    LoggerService.instance.d(
      'DSL Engine 配置写入: apiUrl 长度=${value.length}',
      category: LogCategory.ai,
      tags: ['dsl', 'config'],
    );
  }

  static Future<void> setApiKey(String value) async {
    await PreferencesService.instance.setString(_keyApiKey, value);
    LoggerService.instance.d(
      'DSL Engine 配置写入: apiKey 长度=${value.length}',
      category: LogCategory.ai,
      tags: ['dsl', 'config'],
    );
  }

  static Future<void> setModel(String value) async {
    await PreferencesService.instance.setString(_keyModel, value);
    LoggerService.instance.d(
      'DSL Engine 配置写入: model=$value',
      category: LogCategory.ai,
      tags: ['dsl', 'config'],
    );
  }

  /// 检查 DSL Engine 配置是否完整
  static Future<bool> isConfigured() async {
    final url = await getApiUrl();
    final key = await getApiKey();
    final configured = url.isNotEmpty && key.isNotEmpty;
    if (!configured) {
      LoggerService.instance.w(
        'DSL Engine 配置不完整: url=${url.isNotEmpty}, key=${key.isNotEmpty}',
        category: LogCategory.ai,
        tags: ['dsl', 'config'],
      );
    }
    return configured;
  }
}
