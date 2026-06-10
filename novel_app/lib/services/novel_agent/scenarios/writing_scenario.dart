/// 写作场景 — 封装现有的小说写作 Agent 能力
///
/// 将 AgentTools + ToolExecutor + AgentSystemPrompt 统一封装为
/// AgentScenario 实现，不改变任何行为。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/reading_context_providers.dart';
import 'package:novel_app/services/logger_service.dart';

import '../agent_scenario.dart';
import '../agent_tools.dart';
import '../agent_system_prompt.dart';
import '../tool_executor.dart';

class WritingScenario implements AgentScenario {
  final Ref _ref;
  late final ToolExecutor _executor = ToolExecutor(_ref);

  WritingScenario(this._ref);

  @override
  String get id => ScenarioIds.writing;

  @override
  String get displayName => '小说写作助手';

  @override
  List<Map<String, dynamic>> get tools => AgentTools.allTools;

  @override
  Set<String> get destructiveTools => AgentTools.destructiveTools;

  @override
  String buildSystemPrompt(AgentScenarioContext context) {
    return AgentSystemPrompt.build(
      readingContext: context.readingContext ?? const ReadingContext(),
    );
  }

  @override
  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    LoggerService.instance.d(
      'WritingScenario 执行工具: $name',
      category: LogCategory.ai,
      tags: ['agent', 'scenario', 'writing', name],
    );
    return await _executor.execute(name, args);
  }
}
