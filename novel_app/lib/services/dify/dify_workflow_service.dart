import '../dsl_engine/dsl_engine_config.dart';
import '../dsl_engine/dsl_executor.dart';
import '../dsl_engine/llm_provider.dart';

/// DSL Engine 工作流服务
///
/// 负责通过本地 DSL Engine 执行 AI 工作流，不再依赖 Dify 云端 API。
/// DSL Engine 是客户端实现，复刻 Dify workflow 语义（VariablePool / GraphEngine / LLM Node）。
class DifyWorkflowService {
  DifyWorkflowService();

  /// 构建 [DslExecutor]，未配置时抛出明确错误
  Future<DslExecutor> _buildDslExecutor() async {
    final apiUrl = await DslEngineConfig.getApiUrl();
    final apiKey = await DslEngineConfig.getApiKey();
    final model = await DslEngineConfig.getModel();

    if (apiUrl.isEmpty || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 DSL Engine (API URL 和 API Key)');
    }

    return DslExecutor(
      llmConfig: LlmConfig(baseUrl: apiUrl, apiKey: apiKey),
      defaultModel: model.isNotEmpty ? model : null,
    );
  }

  /// 通用的流式工作流执行方法
  Future<void> executeStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) async {
    final dslExecutor = await _buildDslExecutor();
    return dslExecutor.runStreaming(
      inputs: inputs,
      onData: onData,
      onError: onError,
      onDone: onDone,
    );
  }

  /// 通用的阻塞式工作流执行方法
  Future<Map<String, dynamic>?> executeBlocking({
    required Map<String, dynamic> inputs,
  }) async {
    final dslExecutor = await _buildDslExecutor();
    return dslExecutor.runBlocking(inputs: inputs);
  }
}