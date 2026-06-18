/// Agent 场景抽象 + 场景上下文
///
/// 将 Agent 的 system prompt、工具定义、工具执行、破坏性标记
/// 抽象为可插拔的场景接口，不同 UI 页面可使用不同场景。
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/providers/reading_context_providers.dart';
import '../dsl_engine/llm_provider.dart' show ChatMessage;

// 导出 ChatMessage：AgentScenario 接口方法签名依赖它，
// 所有场景实现（implements AgentScenario）需可见。
export '../dsl_engine/llm_provider.dart' show ChatMessage;

/// Agent 场景上下文（动态参数，由调用方提供）
class AgentScenarioContext {
  /// 小说/章节阅读上下文
  final ReadingContext? readingContext;

  /// WebView 控制器（webview_extract 场景必需，Headless 模式可为 null）
  final InAppWebViewController? webviewController;

  /// 当前页面 URL（webview_extract 场景使用）
  final String? currentUrl;

  /// 是否使用 Headless WebView 模式（webview_extract 场景专用）
  ///
  /// 设为 true 时，`AgentScenarioFactory` 从 `HeadlessWebViewPool` 获取后台
  /// WebView controller，使 AI 提取进程不依赖可见 WebView 页面生命周期。
  final bool useHeadlessWebView;

  /// 当前小说的数据库主键 ID（写作场景专用）
  ///
  /// AI 通过 `select_novel` 工具设置；该值确定所有隐式工具操作的目标小说。
  /// 为 null 时调用需要小说的工具会返回 `no_current_novel` 错误，
  /// 提示 AI 先调用 `list_novels` + `select_novel`。
  final int? currentNovelId;

  /// 当前小说的标题（写作场景专用，用于 system prompt 与 UI 展示）
  final String? currentNovelTitle;

  const AgentScenarioContext({
    this.readingContext,
    this.webviewController,
    this.currentUrl,
    this.useHeadlessWebView = false,
    this.currentNovelId,
    this.currentNovelTitle,
  });
}

/// Agent 场景抽象
///
/// 每个场景定义自己的 system prompt、工具集、执行逻辑和破坏性工具标记。
/// [AgentLoop] 只依赖此接口，不关心具体场景。
abstract class AgentScenario {
  /// 场景唯一标识（'writing' | 'webview_extract' | ...）
  String get id;

  /// 场景显示名（用于 UI 展示）
  String get displayName;

  /// 工具定义列表（OpenAI Function Calling schema）
  List<Map<String, dynamic>> get tools;

  /// 构建系统提示词
  String buildSystemPrompt(AgentScenarioContext context);

  /// 执行工具调用
  Future<String> executeTool(String name, Map<String, dynamic> args);

  /// 当本轮 LLM 响应无 tool_calls（即将结束循环）时的注入钩子
  ///
  /// 场景可返回一条提示消息（将作为 user 角色追加到 messages 并继续下一轮），
  /// 用于在 Agent 漏掉关键步骤时（例如已生成脚本却忘记 save_script）"轻推"一次。
  /// 返回 null 则正常结束循环。
  ///
  /// 防重复注入由场景内部负责（例如设置 `_injected` 标志，最多注入一次）。
  ///
  /// [messages] 当前完整对话历史（已包含本轮 assistant 消息）
  Future<String?> onNoToolCalls(List<ChatMessage> messages) async {
    return null;
  }

  /// 获取当前场景的所有经验记忆
  ///
  /// 默认实现从 AgentMemoryRepository 读取，子类可覆盖。
  /// 返回的列表会拼接到 system prompt 末尾。
  Future<List<String>> getMemories() async => const [];

  /// patch 记忆（增/改/删），由 patch_memory 工具调用
  ///
  /// 行为：
  /// - oldText 为空（首次插入）→ 直接插入 newText，返回成功
  /// - oldText 非空 + newText 为空 → 查找并删除
  /// - oldText 非空 + newText 非空 → 查找并替换
  ///   - 找到：更新成功
  ///   - 找不到：返回错误 + 当前所有记忆内容（供 AI 修正）
  /// 默认实现要求场景有 [scenarioId]，可被所有 AgentScenario 复用。
  Future<MemoryPatchResult> patchMemory(
    String? oldText,
    String newText,
  ) async {
    // 默认空实现：子类应通过 Ref + Repository 提供具体逻辑
    return MemoryPatchResult.error(
      'patch_memory 在当前场景不可用',
      const [],
    );
  }
}

/// patch_memory 工具的执行结果
class MemoryPatchResult {
  final bool success;
  final String message;
  final List<String> allMemories; // 报错时返回所有记忆，供 AI 修正

  const MemoryPatchResult._({
    required this.success,
    required this.message,
    required this.allMemories,
  });

  factory MemoryPatchResult.ok(String message) =>
      MemoryPatchResult._(success: true, message: message, allMemories: const []);

  factory MemoryPatchResult.error(String message, List<String> allMemories) =>
      MemoryPatchResult._(success: false, message: message, allMemories: allMemories);
}

/// patch_memory 工具定义（OpenAI Function Calling schema）
///
/// 说明：这是 Agent 进化的核心机制。
/// - 遇到坑、用户帮你解决的、研究好几轮才解决的记忆，用 patch_memory 记录下来
/// - 遇到和记忆不符的，先 patch_memory 修改记忆
/// - patch_memory(oldText="...", newText="...")：
///   - oldText 为空 → 新增
///   - newText 为空 → 删除
///   - 两者都非空 → 替换
///   - 找不到 oldText → 报错并返回所有记忆
const Map<String, dynamic> patchMemoryToolDefinition = {
  'type': 'function',
  'function': {
    'name': 'patch_memory',
    'description':
        '修改/添加/删除当前场景的经验记忆。\n'
        '记忆会持久化到本地数据库，并在下次对话的 system prompt 中出现。\n'
        '使用场景：\n'
        '- 遇到坑、用户帮你解决、或者研究了好几轮才解决的记忆 → 记录下来\n'
        '- 遇到和当前记忆不符的情况 → 修改记忆\n'
        '- 旧的记忆不再适用 → 删除\n'
        '参数说明：\n'
        '- oldText 为空字符串或省略 → 新增 newText\n'
        '- newText 为空字符串或省略 → 删除 oldText\n'
        '- 两者都非空 → 查找 oldText 并替换为 newText\n'
        '- 若 oldText 在记忆中没有完全匹配 → 报错并返回所有现有记忆内容',
    'parameters': {
      'type': 'object',
      'properties': {
        'oldText': {
          'type': 'string',
          'description':
              '要被替换/删除的旧记忆内容（必须完全匹配）。为空表示新增。',
        },
        'newText': {
          'type': 'string',
          'description':
              '新记忆内容。为空表示删除。',
        },
      },
      'required': <String>[],
    },
  },
};

/// 已注册的场景 ID 常量
abstract final class ScenarioIds {
  static const writing = 'writing';
  static const webviewExtract = 'webview_extract';
}

/// 场景快速输入提示词
///
/// 在对话输入区上方展示为一行 chip，点击后追加到输入框，
/// 让用户快速发起典型任务，避免重复打字。
class ScenarioQuickPrompt {
  /// chip 上显示的简短标签
  final String label;

  /// 追加到输入框的完整提示词
  final String text;

  const ScenarioQuickPrompt({
    required this.label,
    required this.text,
  });
}

/// 各场景的快速输入提示词集合
///
/// 与场景的工具集 / system prompt 工作流同源维护，
/// UI 通过 [forScenario] 按场景 ID 取数。未配置的场景返回空列表（不渲染 chip 行）。
abstract final class ScenarioQuickPrompts {
  static const _webviewExtract = <ScenarioQuickPrompt>[
    ScenarioQuickPrompt(
      label: '为这个网站生成提取脚本',
      text: '请为当前网站编写可复用的提取脚本：先用 get_page_info 探测页面结构，'
          '再生成目录提取脚本和内容提取脚本，测试通过后用 save_script 保存到本地数据库。',
    ),
  ];

  /// 获取指定场景的快速输入提示词
  ///
  /// 未配置的场景返回空列表。
  static List<ScenarioQuickPrompt> forScenario(String scenarioId) {
    switch (scenarioId) {
      case ScenarioIds.webviewExtract:
        return _webviewExtract;
      default:
        return const <ScenarioQuickPrompt>[];
    }
  }
}
