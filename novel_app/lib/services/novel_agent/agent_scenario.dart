/// Agent 场景抽象 + 场景上下文
///
/// 将 Agent 的 system prompt、工具定义、工具执行、破坏性标记
/// 抽象为可插拔的场景接口，不同 UI 页面可使用不同场景。
library;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/providers/reading_context_providers.dart';

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

  const AgentScenarioContext({
    this.readingContext,
    this.webviewController,
    this.currentUrl,
    this.useHeadlessWebView = false,
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

  /// 破坏性工具集合（需要用户确认）
  Set<String> get destructiveTools;

  /// 构建系统提示词
  String buildSystemPrompt(AgentScenarioContext context);

  /// 执行工具调用
  Future<String> executeTool(String name, Map<String, dynamic> args);
}

/// 已注册的场景 ID 常量
abstract final class ScenarioIds {
  static const writing = 'writing';
  static const webviewExtract = 'webview_extract';
}
