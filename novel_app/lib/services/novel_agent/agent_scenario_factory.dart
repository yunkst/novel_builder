/// Agent 场景工厂
///
/// 根据 scenarioId 和 AgentScenarioContext 构造对应的场景实例。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'agent_scenario.dart';
import 'scenarios/writing_scenario.dart';
import 'scenarios/webview_extract_scenario.dart';

class AgentScenarioFactory {
  final Ref _ref;

  AgentScenarioFactory(this._ref);

  /// 构造场景实例
  AgentScenario build(String scenarioId, AgentScenarioContext context) {
    switch (scenarioId) {
      case ScenarioIds.writing:
        return WritingScenario(_ref);
      case ScenarioIds.webviewExtract:
        if (context.webviewController == null) {
          throw ArgumentError('WebViewExtract 场景需要 webviewController');
        }
        return WebViewExtractScenario(
          _ref,
          context.webviewController!,
          context.currentUrl ?? '',
        );
      default:
        throw ArgumentError('未知场景: $scenarioId');
    }
  }

  /// 获取所有可用场景的信息（用于 UI 展示）
  static List<ScenarioInfo> get availableScenarios => [
        const ScenarioInfo(
          id: ScenarioIds.writing,
          displayName: '小说写作助手',
          icon: '✍️',
        ),
        const ScenarioInfo(
          id: ScenarioIds.webviewExtract,
          displayName: '网页小说提取',
          icon: '🔍',
        ),
      ];
}

/// 场景信息（用于 UI 列表展示）
class ScenarioInfo {
  final String id;
  final String displayName;
  final String icon;

  const ScenarioInfo({
    required this.id,
    required this.displayName,
    required this.icon,
  });
}
