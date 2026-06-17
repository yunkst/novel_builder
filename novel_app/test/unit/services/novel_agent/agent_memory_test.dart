/// Agent 记忆进化功能单元测试
///
/// 验证 patch_memory 工具 + 场景记忆隔离 + system prompt 拼接
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/novel_agent/agent_memory_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/repositories/agent_memory_repository.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import '../../../helpers/test_database_setup.dart';

void main() {
  group('MemoryPatchResult', () {
    test('ok 返回 success=true + message', () {
      final result = MemoryPatchResult.ok('已添加');
      expect(result.success, isTrue);
      expect(result.message, '已添加');
      expect(result.allMemories, isEmpty);
    });

    test('error 返回 success=false + message + allMemories', () {
      final result = MemoryPatchResult.error('未找到', ['记忆1', '记忆2']);
      expect(result.success, isFalse);
      expect(result.message, '未找到');
      expect(result.allMemories, ['记忆1', '记忆2']);
    });
  });

  group('patchMemoryToolDefinition', () {
    test('工具定义包含 patch_memory 名称', () {
      final name = patchMemoryToolDefinition['function']['name'];
      expect(name, 'patch_memory');
    });

    test('工具定义参数包含 oldText 和 newText', () {
      final params = patchMemoryToolDefinition['function']['parameters'];
      final props = params['properties'] as Map<String, dynamic>;
      expect(props.containsKey('oldText'), isTrue);
      expect(props.containsKey('newText'), isTrue);
    });

    test('工具定义 required 为空（两个参数都可选）', () {
      final params = patchMemoryToolDefinition['function']['parameters'];
      final required = params['required'] as List<dynamic>;
      expect(required, isEmpty);
    });
  });

  group('AgentMemoryRepository', () {
    late Database db;
    late AgentMemoryRepository repo;

    setUp(() async {
      db = await TestDatabaseSetup.createInMemoryDatabase();
      final connection = DatabaseConnection.forTesting(db);
      repo = AgentMemoryRepository(dbConnection: connection);
    });

    tearDown(() async {
      await db.close();
    });

    test('getAllByScenario 空场景返回空列表', () async {
      final memories = await repo.getAllByScenario('test_scenario');
      expect(memories, isEmpty);
    });

    test('addMemory + getAllByScenario 正常流程', () async {
      await repo.addMemory('test_scenario', '记忆A');
      await repo.addMemory('test_scenario', '记忆B');
      final memories = await repo.getAllByScenario('test_scenario');
      expect(memories, ['记忆A', '记忆B']);
    });

    test('不同场景记忆隔离', () async {
      await repo.addMemory('scenario_a', 'A的记忆');
      await repo.addMemory('scenario_b', 'B的记忆');
      final aMemories = await repo.getAllByScenario('scenario_a');
      final bMemories = await repo.getAllByScenario('scenario_b');
      expect(aMemories, ['A的记忆']);
      expect(bMemories, ['B的记忆']);
    });

    test('findByContent 精确匹配', () async {
      await repo.addMemory('test_scenario', '精确匹配测试');
      final found = await repo.findByContent('test_scenario', '精确匹配测试');
      expect(found, isNotNull);
      expect(found!['content'], '精确匹配测试');
    });

    test('findByContent 不匹配返回 null', () async {
      await repo.addMemory('test_scenario', '记忆A');
      final found = await repo.findByContent('test_scenario', '不存在的记忆');
      expect(found, isNull);
    });

    test('updateMemory 替换内容', () async {
      await repo.addMemory('test_scenario', '旧记忆');
      final all = await repo.getAllWithId('test_scenario');
      final id = all.first['id'] as int;
      await repo.updateMemory(id, '新记忆');
      final memories = await repo.getAllByScenario('test_scenario');
      expect(memories, ['新记忆']);
    });

    test('deleteMemory 删除记忆', () async {
      await repo.addMemory('test_scenario', '待删除');
      final all = await repo.getAllWithId('test_scenario');
      final id = all.first['id'] as int;
      await repo.deleteMemory(id);
      final memories = await repo.getAllByScenario('test_scenario');
      expect(memories, isEmpty);
    });

    test('countByScenario 统计记忆数量', () async {
      expect(await repo.countByScenario('test_scenario'), 0);
      await repo.addMemory('test_scenario', '记忆1');
      await repo.addMemory('test_scenario', '记忆2');
      expect(await repo.countByScenario('test_scenario'), 2);
    });
  });

  group('AgentMemoryRepository patchMemory 逻辑', () {
    late Database db;
    late AgentMemoryRepository repo;
    // 模拟场景 patchMemory 逻辑（不依赖 Ref）
    final scenarioId = 'writing';

    setUp(() async {
      db = await TestDatabaseSetup.createInMemoryDatabase();
      final connection = DatabaseConnection.forTesting(db);
      repo = AgentMemoryRepository(dbConnection: connection);
    });

    tearDown(() async {
      await db.close();
    });

    Future<MemoryPatchResult> patchMemory(String? oldText, String newText) async {
      final all = await repo.getAllWithId(scenarioId);
      final allContents = all.map((r) => r['content'] as String).toList();

      if (allContents.isEmpty) {
        await repo.addMemory(scenarioId, newText);
        return MemoryPatchResult.ok('已添加（首次插入）');
      }
      if (oldText == null || oldText.isEmpty) {
        await repo.addMemory(scenarioId, newText);
        return MemoryPatchResult.ok('新记忆已添加');
      }
      if (newText.isEmpty) {
        final hit = all.firstWhere(
          (r) => r['content'] == oldText,
          orElse: () => <String, dynamic>{},
        );
        if (hit.isEmpty) {
          return MemoryPatchResult.error('未找到要删除的记忆', allContents);
        }
        await repo.deleteMemory(hit['id'] as int);
        return MemoryPatchResult.ok('记忆已删除');
      }
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
      return MemoryPatchResult.ok('记忆已更新');
    }

    test('记忆为空时直接插入', () async {
      final result = await patchMemory(null, '第一条记忆');
      expect(result.success, isTrue);
      expect(result.message, contains('首次插入'));
      final memories = await repo.getAllByScenario(scenarioId);
      expect(memories, ['第一条记忆']);
    });

    test('oldText 为空时新增', () async {
      await patchMemory(null, '记忆1');
      final result = await patchMemory('', '记忆2');
      expect(result.success, isTrue);
      expect(result.message, contains('新记忆已添加'));
      final memories = await repo.getAllByScenario(scenarioId);
      expect(memories, ['记忆1', '记忆2']);
    });

    test('oldText 匹配时替换', () async {
      await patchMemory(null, '旧记忆');
      final result = await patchMemory('旧记忆', '新记忆');
      expect(result.success, isTrue);
      expect(result.message, contains('已更新'));
      final memories = await repo.getAllByScenario(scenarioId);
      expect(memories, ['新记忆']);
    });

    test('oldText 不匹配时报错并返回所有记忆', () async {
      await patchMemory(null, '记忆A');
      await patchMemory('', '记忆B');
      final result = await patchMemory('不存在的记忆', '新记忆');
      expect(result.success, isFalse);
      expect(result.message, contains('未找到匹配'));
      expect(result.allMemories, ['记忆A', '记忆B']);
    });

    test('newText 为空时删除', () async {
      await patchMemory(null, '待删除');
      await patchMemory('', '保留');
      final result = await patchMemory('待删除', '');
      expect(result.success, isTrue);
      expect(result.message, contains('已删除'));
      final memories = await repo.getAllByScenario(scenarioId);
      expect(memories, ['保留']);
    });

    test('删除不存在的记忆报错', () async {
      await patchMemory(null, '记忆A');
      final result = await patchMemory('不存在', '');
      expect(result.success, isFalse);
      expect(result.message, contains('未找到要删除'));
      expect(result.allMemories, ['记忆A']);
    });
  });

  group('SystemPrompt 记忆拼接（使用侧）', () {
    late Database db;
    late AgentMemoryRepository repo;
    final scenarioId = 'writing';

    setUp(() async {
      db = await TestDatabaseSetup.createInMemoryDatabase();
      final connection = DatabaseConnection.forTesting(db);
      repo = AgentMemoryRepository(dbConnection: connection);
    });

    tearDown(() async {
      await db.close();
    });

    /// 模拟 buildSystemPrompt 拼接记忆的逻辑
    Future<String> buildPrompt({String context = ''}) async {
      final memories = await repo.getAllByScenario(scenarioId);
      final buf = StringBuffer();
      buf.writeln('你是 Novel Builder 助手。');
      if (context.isNotEmpty) {
        buf.writeln(context);
      }
      if (memories.isNotEmpty) {
        buf.writeln('## 经验记忆');
        buf.writeln('以下是以往对话中的经验记录，请优先参考：');
        for (final m in memories) {
          buf.writeln('- $m');
        }
      }
      return buf.toString();
    }

    test('无记忆时 prompt 不含经验记忆段', () async {
      final prompt = await buildPrompt();
      expect(prompt.contains('经验记忆'), isFalse);
      expect(prompt.contains('请优先参考'), isFalse);
    });

    test('有一条记忆时 prompt 末尾拼接记忆', () async {
      await repo.addMemory(scenarioId, '章节ID要用 int 类型，不要用 String');
      final prompt = await buildPrompt();
      expect(prompt, contains('## 经验记忆'));
      expect(prompt, contains('请优先参考'));
      expect(prompt, contains('章节ID要用 int 类型'));
    });

    test('多条记忆按插入顺序排列', () async {
      await repo.addMemory(scenarioId, '第一优先级');
      await repo.addMemory(scenarioId, '第二优先级');
      await repo.addMemory(scenarioId, '第三优先级');
      final prompt = await buildPrompt();

      final expIdx = prompt.indexOf('## 经验记忆');
      expect(expIdx, greaterThan(0));
      final idx1 = prompt.indexOf('第一优先级');
      final idx2 = prompt.indexOf('第二优先级');
      final idx3 = prompt.indexOf('第三优先级');
      expect(idx1, lessThan(idx2));
      expect(idx2, lessThan(idx3));
    });

    test('记忆内容不会被场景上下文覆盖', () async {
      await repo.addMemory(scenarioId, '重要经验：修改角色前先查列表');
      final prompt = await buildPrompt(
        context: '当前阅读小说《斗破苍穹》，第100章',
      );
      expect(prompt, contains('斗破苍穹'));
      expect(prompt, contains('重要经验：修改角色前先查列表'));
      // 场景上下文在经验记忆之前
      expect(
        prompt.indexOf('斗破苍穹'),
        lessThan(prompt.indexOf('经验记忆')),
      );
    });

    test('跨场景记忆隔离', () async {
      await repo.addMemory('writing', '写作专用记忆');
      await repo.addMemory('webview_extract', '提取专用记忆');

      // writing 只能用 writing 的记忆
      final writingMemories = await repo.getAllByScenario('writing');
      expect(writingMemories, ['写作专用记忆']);
      expect(writingMemories, isNot(contains('提取专用记忆')));

      // webview_extract 只能用 webview_extract 的记忆
      final extractMemories = await repo.getAllByScenario('webview_extract');
      expect(extractMemories, ['提取专用记忆']);
      expect(extractMemories, isNot(contains('写作专用记忆')));
    });

    test('记忆删除后不再出现在 prompt', () async {
      await repo.addMemory(scenarioId, '过时的经验');
      // 确认在 prompt 中
      final before = await buildPrompt();
      expect(before, contains('过时的经验'));

      // 删除后不应出现
      final all = await repo.getAllWithId(scenarioId);
      await repo.deleteMemory(all.first['id'] as int);
      final after = await buildPrompt();
      expect(after, isNot(contains('过时的经验')));
      expect(after, isNot(contains('经验记忆')));
    });

    test('记忆更新后 prompt 反映最新内容', () async {
      await repo.addMemory(scenarioId, '旧版本经验');
      final all = await repo.getAllWithId(scenarioId);
      await repo.updateMemory(all.first['id'] as int, '新版本经验');

      final prompt = await buildPrompt();
      expect(prompt, isNot(contains('旧版本经验')));
      expect(prompt, contains('新版本经验'));
    });

    test('AgentScenarioContext 当前阅读信息与记忆同时出现', () async {
      await repo.addMemory(scenarioId, '背景设定修改时需包含完整内容');
      await repo.addMemory(scenarioId, '大纲保存使用 Markdown 格式');

      final prompt = await buildPrompt(
        context: '当前阅读小说《完美世界》，正在修改角色石昊',
      );

      // 上下文在记忆之前
      expect(prompt.indexOf('完美世界'), lessThan(prompt.indexOf('经验记忆')));
      // 记忆位于末尾
      expect(prompt, contains('背景设定修改时需包含完整内容'));
      expect(prompt, contains('大纲保存使用 Markdown 格式'));
      // 记忆段在末尾
      expect(prompt, endsWith('- 大纲保存使用 Markdown 格式\n'));
    });
  });
}
