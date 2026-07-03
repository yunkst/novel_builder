/// 写作场景 — 封装现有的小说写作 Agent 能力
///
/// 将 AgentTools + ToolExecutor + AgentSystemPrompt 统一封装为
/// AgentScenario 实现，不改变任何行为。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/core/providers/reading_context_providers.dart';
import 'package:novel_app/services/logger_service.dart';

import '../agent_scenario.dart';
import '../agent_tools.dart';
import '../agent_system_prompt.dart';
import '../tool_executor.dart';

class WritingScenario with AgentScenarioCleanupMixin, AgentMemoryPatchMixin
    implements AgentScenario {
  final Ref _ref;
  late final ToolExecutor _executor = ToolExecutor(_ref);

  /// 缓存当前场景上下文，供 executeTool 内部使用
  AgentScenarioContext? _currentContext;

  WritingScenario(this._ref);

  @override
  String get id => ScenarioIds.writing;

  @override
  String get displayName => '小说写作助手';

  @override
  List<Map<String, dynamic>> get tools => [
        ...AgentTools.allTools,
        patchMemoryToolDefinition,
      ];

  @override
  String buildSystemPrompt(AgentScenarioContext context) {
    _currentContext = context;
    final novelInfo = context.currentNovelTitle != null
        ? '\n\n## 当前小说\n${context.currentNovelTitle}\n'
            '所有不传 novelId 的工具将作用于该小说。'
        : '\n\n## 当前小说\n未选择。请先调用 list_novels 查看书架，'
            '然后用 select_novel 选定目标。';
    return AgentSystemPrompt.build(
      readingContext: context.readingContext ?? const ReadingContext(),
      memories: cachedMemories,
    ) + novelInfo;
  }

  @override
  Future<String> executeTool(
    String name,
    Map<String, dynamic> args, {
    void Function(int generatedChars)? onProgress,
  }) async {
    LoggerService.instance.d(
      'WritingScenario 执行工具: $name',
      category: LogCategory.ai,
      tags: ['agent', 'scenario', 'writing', name],
    );
    // patch_memory 由场景自行处理（需要 AgentMemoryRepository + 记忆缓存）
    if (name == 'patch_memory') {
      return await _executePatchMemory(args);
    }
    // select_novel / create_novel 需要同步更新 _currentContext，
    // 确保同一 LLM 响应中后续工具调用能作用于新小说
    if (name == 'select_novel' || name == 'create_novel') {
      final result = await _executor.execute(name, args, scenarioContext: _currentContext);
      _syncCurrentContext(result);
      return result;
    }
    // 其余工具（含 create_chapter / update_chapter_content 的流式进度）透传 onProgress
    return await _executor.execute(
      name,
      args,
      scenarioContext: _currentContext,
      onProgress: onProgress,
    );
  }

  /// 写作场景无需"无 tool_call 注入"，直接结束
  @override
  Future<String?> onNoToolCalls(List<ChatMessage> messages) async => null;

  /// 从 select_novel 工具结果中提取小说信息并同步到 _currentContext
  void _syncCurrentContext(String result) {
    try {
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      if (parsed['success'] == true && parsed['novelId'] != null) {
        _currentContext = AgentScenarioContext(
          scenarioId: ScenarioIds.writing,
          readingContext: _currentContext?.readingContext,
          currentUrl: _currentContext?.currentUrl,
          currentNovelId: parsed['novelId'] as int,
          currentNovelTitle: parsed['title'] as String?,
        );
      }
    } catch (e) {
      // 解析失败，保持当前 context 不变
      LoggerService.instance.e(
        '解析 select_novel 结果失败: $result',
        category: LogCategory.ai,
        tags: ['agent', 'writing', 'sync_context', 'parse_failed'],
      );
    }
  }

  /// 执行 patch_memory 工具，序列化 MemoryPatchResult
  Future<String> _executePatchMemory(Map<String, dynamic> args) async {
    final index = args['index'] as int?;
    final newText = args['newText'] as String? ?? '';
    final result = await patchMemory(index, newText);
    if (result.success) {
      LoggerService.instance.i(
        'patchMemory 成功: ${result.message}',
        category: LogCategory.ai,
        tags: ['agent', 'writing', 'patch_memory', 'success'],
      );
      return jsonEncode({'success': true, 'message': result.message});
    }
    LoggerService.instance.w(
      'patchMemory 失败: ${result.message}',
      category: LogCategory.ai,
      tags: ['agent', 'writing', 'patch_memory', 'failed'],
    );
    // 失败：返回 [N] 格式的编号列表，与 system prompt 展示一致，供 AI 用正确编号重试
    return jsonEncode({
      'error': 'memory_index_invalid',
      'message': result.message,
      'allMemories': result.allMemories
          .asMap()
          .entries
          .map((e) => '[${e.key + 1}] ${e.value}')
          .toList(),
    });
  }

  /// 记忆缓存（由 AgentMemoryPatchMixin 提供，本类复用 mixin 的实现）
  @override
  Future<List<String>> getMemories() async {
    try {
      final repo = _ref.read(agentMemoryRepositoryProvider);
      return await loadMemories(repo);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '加载写作记忆失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['agent', 'writing', 'get_memories', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<MemoryPatchResult> patchMemory(int? index, String newText) async {
    final repo = _ref.read(agentMemoryRepositoryProvider);
    return patchMemoryImpl(repo, index, newText);
  }
}
