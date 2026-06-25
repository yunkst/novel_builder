import 'dify/dify_config_service.dart';
import 'dify/dify_workflow_service.dart';

/// AI 工作流服务 - 门面类
///
/// 委托给：
/// - [DifyConfigService]: AI 设定管理
/// - [DifyWorkflowService]: 工作流调用（本地 DSL Engine 执行）
class DifyService {
  final DifyConfigService _config;
  late final DifyWorkflowService _workflow;

  /// 构造函数 - 支持依赖注入
  ///
  /// [config] 可选的配置服务实例，用于测试和依赖注入
  DifyService({DifyConfigService? config})
      : _config = config ?? DifyConfigService() {
    _workflow = DifyWorkflowService();
  }

  /// 获取配置服务（用于测试和高级用法）
  DifyConfigService get config => _config;

  /// 获取工作流服务（用于高级用法）
  DifyWorkflowService get workflow => _workflow;

  // ============================================================================
  // 工作流方法（委托给 DifyWorkflowService）
  // ============================================================================

  /// 通用的流式工作流执行方法
  Future<void> runWorkflowStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) =>
      _workflow.executeStreaming(
        inputs: inputs,
        onData: onData,
        onError: onError,
        onDone: onDone,
        enableDebugLog: enableDebugLog,
      );

  /// 通用的阻塞式工作流执行方法
  Future<Map<String, dynamic>?> runWorkflowBlocking({
    required Map<String, dynamic> inputs,
  }) =>
      _workflow.executeBlocking(inputs: inputs);
}