import '../ai/ai_service_factory.dart';
import '../ai/writing_service.dart';
import '../logger_service.dart';

/// 工作流服务（已切换到强类型 Dart Service）
///
/// 内部委托给 WritingService 处理新建章节（cmd='' 流式分支）。
/// 路由规则：根据 inputs['cmd'] 分发到对应的强类型方法。当前仅保留 cmd=''（新建章节）。
class DifyWorkflowService {
  /// Riverpod 容器（WidgetRef 或 Ref），用于通过 AiServiceFactory 获取 LLM 配置。
  final dynamic _ref;

  DifyWorkflowService({dynamic ref}) : _ref = ref;

  // ============================================================================
  // 流式执行（原 creater.yml 路径 → WritingService）
  // ============================================================================

  Future<void> executeStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
    bool enableDebugLog = false,
  }) async {
    LoggerService.instance.d(
      'DifyWorkflowService.executeStreaming: cmd=${inputs['cmd']}, '
      'inputs=${inputs.keys.toList()}',
      category: LogCategory.ai,
      tags: ['workflow', 'streaming'],
    );
    try {
      if (_ref == null) {
        throw Exception('DifyWorkflowService 需要传入 Riverpod 容器以获取 LLM 配置');
      }
      final service = await AiServiceFactory.createWritingService(_ref);
      final stream = _routeStreaming(service, inputs);
      await for (final chunk in stream) {
        onData(chunk);
      }
      onDone?.call();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'executeStreaming 失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['workflow', 'streaming', 'error'],
      );
      onError?.call(e.toString());
    }
  }

  /// 阻塞式执行（保留接口，但当前无任何阻塞式 AI 功能）
  Future<Map<String, dynamic>?> executeBlocking({
    required Map<String, dynamic> inputs,
  }) async {
    LoggerService.instance.w(
      'executeBlocking 已被调用但当前未实现任何阻塞式 AI 功能: cmd=${inputs['cmd']}',
      category: LogCategory.ai,
      tags: ['workflow', 'blocking', 'deprecated'],
    );
    return null;
  }

  // ============================================================================
  // cmd 路由
  // ============================================================================

  Stream<String> _routeStreaming(
    WritingService service,
    Map<String, dynamic> inputs,
  ) {
    final cmd = (inputs['cmd'] as String?) ?? '';
    String s(String key) => (inputs[key] ?? '').toString();

    switch (cmd) {
      case '':
        return service.createChapter(
          aiWriterSetting: s('ai_writer_setting'),
          backgroundSetting: s('background_setting'),
          historyChaptersContent: s('history_chapters_content'),
          roles: s('roles'),
          nextChapterOverview: s('next_chapter_overview'),
          userInput: s('user_input'),
        );
      default:
        throw UnimplementedError('未知的流式 cmd: "$cmd"');
    }
  }
}