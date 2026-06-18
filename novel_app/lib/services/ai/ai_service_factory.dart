/// AI Service 工厂
///
/// 从 DslEngineConfig（SharedPreferences）读取 LLM 配置，
/// 统一构建 WritingService / InfoExtractionService。
/// 替代 DifyWorkflowService._buildDslExecutor() 的职责。
library;

import '../dsl_engine/dsl_engine_config.dart';
import '../dsl_engine/llm_provider.dart';
import 'info_extraction_service.dart';
import 'writing_service.dart';

class AiServiceFactory {
  AiServiceFactory._();

  /// 从 DslEngineConfig 构建 WritingService，未配置时抛异常
  static Future<WritingService> createWritingService() async {
    final config = await _buildLlmConfig();
    return WritingService(
      provider: LlmProvider(config),
      defaultModel: config.defaultModel.isNotEmpty ? config.defaultModel : null,
    );
  }

  /// 从 DslEngineConfig 构建 InfoExtractionService，未配置时抛异常
  static Future<InfoExtractionService> createInfoExtractionService() async {
    final config = await _buildLlmConfig();
    return InfoExtractionService(
      provider: LlmProvider(config),
      defaultModel: config.defaultModel.isNotEmpty ? config.defaultModel : null,
    );
  }

  /// 读取 DSL Engine 配置构建 LlmConfig
  ///
  /// 未配置 API URL 或 Key 时抛出明确异常（与原 DifyWorkflowService 行为一致）。
  static Future<LlmConfig> _buildLlmConfig() async {
    final apiUrl = await DslEngineConfig.getApiUrl();
    final apiKey = await DslEngineConfig.getApiKey();
    final model = await DslEngineConfig.getModel();

    if (apiUrl.isEmpty || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 DSL Engine (API URL 和 API Key)');
    }

    return LlmConfig(
      baseUrl: apiUrl,
      apiKey: apiKey,
      defaultModel: model,
    );
  }
}
