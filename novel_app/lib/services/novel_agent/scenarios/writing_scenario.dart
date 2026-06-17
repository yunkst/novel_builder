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

class WritingScenario implements AgentScenario {
  final Ref _ref;
  late final ToolExecutor _executor = ToolExecutor(_ref);

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
  Set<String> get destructiveTools => AgentTools.destructiveTools;

  @override
  String buildSystemPrompt(AgentScenarioContext context) {
    return AgentSystemPrompt.build(
      readingContext: context.readingContext ?? const ReadingContext(),
      memories: _cachedMemories,
    );
  }

  @override
  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    LoggerService.instance.d(
      'WritingScenario 执行工具: $name',
      category: LogCategory.ai,
      tags: ['agent', 'scenario', 'writing', name],
    );
    // patch_memory 由场景自行处理（需要 AgentMemoryRepository + 记忆缓存）
    if (name == 'patch_memory') {
      return await _executePatchMemory(args);
    }
    return await _executor.execute(name, args);
  }

  /// 执行 patch_memory 工具，序列化 MemoryPatchResult
  Future<String> _executePatchMemory(Map<String, dynamic> args) async {
    final oldText = args['oldText'] as String? ?? args['old_text'] as String?;
    final newText = args['newText'] as String? ?? args['new_text'] as String? ?? '';
    final result = await patchMemory(oldText, newText);
    if (result.success) {
      return jsonEncode({'success': true, 'message': result.message});
    }
    return jsonEncode({
      'error': 'memory_not_found',
      'message': result.message,
      'allMemories': result.allMemories,
    });
  }

  /// 记忆缓存（每次构建 prompt 时复用，避免重复 IO）
  List<String> _cachedMemories = const [];

  @override
  Future<List<String>> getMemories() async {
    final repo = _ref.read(agentMemoryRepositoryProvider);
    _cachedMemories = await repo.getAllByScenario(id);
    return _cachedMemories;
  }

  @override
  Future<MemoryPatchResult> patchMemory(
    String? oldText,
    String newText,
  ) async {
    final repo = _ref.read(agentMemoryRepositoryProvider);
    final all = await repo.getAllWithId(id);
    final allContents = all.map((r) => r['content'] as String).toList();

    // Case 1: 记忆为空 → 直接插入
    if (allContents.isEmpty) {
      await repo.addMemory(id, newText);
      _cachedMemories = [..._cachedMemories, newText];
      return MemoryPatchResult.ok('记忆已添加（首次插入）');
    }

    // Case 2: oldText 为空 → 新增
    if (oldText == null || oldText.isEmpty) {
      await repo.addMemory(id, newText);
      _cachedMemories = [..._cachedMemories, newText];
      return MemoryPatchResult.ok('新记忆已添加');
    }

    // Case 3: newText 为空 → 删除
    if (newText.isEmpty) {
      final hit = all.firstWhere(
        (r) => r['content'] == oldText,
        orElse: () => <String, dynamic>{},
      );
      if (hit.isEmpty) {
        return MemoryPatchResult.error(
          '未找到要删除的记忆',
          allContents,
        );
      }
      await repo.deleteMemory(hit['id'] as int);
      _cachedMemories = List<String>.from(_cachedMemories)..remove(oldText);
      return MemoryPatchResult.ok('记忆已删除');
    }

    // Case 4: 替换
    final hit = all.firstWhere(
      (r) => r['content'] == oldText,
      orElse: () => <String, dynamic>{},
    );
    if (hit.isEmpty) {
      return MemoryPatchResult.error(
        '未找到匹配的记忆内容。现有记忆：',
        allContents,
      );
    }
    await repo.updateMemory(hit['id'] as int, newText);
    final idx = _cachedMemories.indexOf(oldText);
    if (idx >= 0) {
      _cachedMemories = List<String>.from(_cachedMemories)
        ..[idx] = newText;
    }
    return MemoryPatchResult.ok('记忆已更新');
  }
}
