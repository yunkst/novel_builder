import 'dify/dify_workflow_service.dart';

/// 章节生成服务 - 门面类（本地 LLM Provider 流式调用，不再依赖远程 Dify）
///
/// 委托给：
/// - [DifyWorkflowService]: cmd 路由 + WritingService 流式调用
///
/// 重命名计划：计划在 2.0 版本重命名为 ChapterGenerationService，
/// 当前保留 DifyService 旧名以保持 API 稳定。
class DifyService {
  late final DifyWorkflowService _workflow;

  /// 构造函数
  ///
  /// [ref] Riverpod 容器（WidgetRef 或 Ref），用于 DifyWorkflowService 获取 LLM 配置
  DifyService({dynamic ref}) {
    _workflow = DifyWorkflowService(ref: ref);
  }

  /// 获取工作流服务
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
}
