/// AI Service 工厂
///
/// 从 LlmConfigService 读取激活的 LLM 配置，构建 WritingService。
library;

import '../../core/providers/services/ai_service_providers.dart';
import '../dsl_engine/llm_provider.dart';
import '../llm_config_service.dart';
import 'writing_service.dart';

class AiServiceFactory {
  AiServiceFactory._();

  /// 从 LlmConfig（llm_provider 层）构建 LlmProvider
  ///
  /// 统一 LlmProvider 的构造方式，供 WritingService 和 NovelAgentService 共用。
  static LlmProvider buildLlmProvider(LlmConfig llmConfig) {
    return LlmProvider(llmConfig, httpClient: IoLlmHttpClient());
  }

  /// 从 LlmConfigService 获取激活配置，构建 WritingService
  ///
  /// [riverpodRef] Riverpod 容器（WidgetRef 或 Ref）
  /// [scenarioId] 可选场景 ID，指定场景级配置
  /// 未配置时抛异常
  static Future<WritingService> createWritingService(
    dynamic riverpodRef, {
    String? scenarioId,
  }) async {
    final configService = riverpodRef.read(llmConfigServiceProvider);
    // 确保旧配置已迁移
    await configService.ensureMigratedFromLegacy();

    final activeConfig =
        await configService.getActiveConfig(scenarioId: scenarioId);
    if (activeConfig == null) {
      throw Exception(LlmConfigService.notConfiguredMessage);
    }

    final llmConfig = configService.buildLlmProviderConfig(activeConfig);
    return WritingService(
      provider: buildLlmProvider(llmConfig),
      defaultModel:
          llmConfig.defaultModel.isNotEmpty ? llmConfig.defaultModel : null,
    );
  }
}