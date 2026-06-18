/// AgentTools 工具定义单元测试
///
/// 验证 14 个工具的 OpenAI Function Calling schema：
/// - 工具总数正确
/// - 每个工具的 name、description、parameters 结构合法
/// - required 参数列表正确
/// - findTool 查找功能
/// - isDestructive 判定（当前所有工具均非破坏性 — 已禁用确认）
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/agent_tools.dart';

void main() {
  group('AgentTools.allTools — 基础验证', () {
    test('应该有 14 个工具', () {
      expect(AgentTools.allTools.length, 14);
    });

    test('每个工具都有 type=function', () {
      for (final tool in AgentTools.allTools) {
        expect(tool['type'], 'function',
            reason: '${tool['function']['name']} 应该 type=function');
      }
    });

    test('每个工具都有 function.name', () {
      for (final tool in AgentTools.allTools) {
        final func = tool['function'] as Map<String, dynamic>;
        expect(func['name'], isA<String>());
        expect((func['name'] as String).isNotEmpty, true);
      }
    });

    test('每个工具都有非空 description', () {
      for (final tool in AgentTools.allTools) {
        final func = tool['function'] as Map<String, dynamic>;
        final desc = func['description'] as String?;
        expect(desc, isNotNull,
            reason: '${func['name']} 缺少 description');
        expect(desc!.isNotEmpty, true,
            reason: '${func['name']} description 为空');
      }
    });

    test('每个工具都有 parameters.type=object', () {
      for (final tool in AgentTools.allTools) {
        final func = tool['function'] as Map<String, dynamic>;
        final params = func['parameters'] as Map<String, dynamic>?;
        expect(params, isNotNull,
            reason: '${func['name']} 缺少 parameters');
        expect(params!['type'], 'object',
            reason: '${func['name']} parameters.type 应为 object');
      }
    });

    test('工具名不重复', () {
      final names =
          AgentTools.allTools.map((t) => t['function']['name'] as String).toList();
      expect(names.toSet().length, names.length,
          reason: '工具名有重复: ${names.where((n) => names.where((x) => x == n).length > 1).toSet()}');
    });
  });

  group('AgentTools — 各工具 schema 详细验证', () {
    /// 辅助：验证工具 schema
    void verifyToolSchema(
      String name, {
      List<String> required = const [],
      List<String> optional = const [],
    }) {
      final tool = AgentTools.findTool(name);
      expect(tool, isNotNull, reason: '工具 $name 未找到');

      final params =
          tool!['function']['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>? ?? {};
      final requiredList = params['required'] as List? ?? [];

      // 验证 required 参数都在 properties 中
      for (final r in required) {
        expect(properties.containsKey(r), true,
            reason: '$name: required 参数 "$r" 不在 properties 中');
        expect(requiredList.contains(r), true,
            reason: '$name: "$r" 应在 required 列表中');
      }

      // 验证 optional 参数都在 properties 中但不在 required 中
      for (final o in optional) {
        expect(properties.containsKey(o), true,
            reason: '$name: optional 参数 "$o" 不在 properties 中');
        expect(requiredList.contains(o), false,
            reason: '$name: "$o" 不应在 required 列表中');
      }

      // 验证 required 长度
      expect(requiredList.length, required.length,
          reason: '$name: required 列表长度不匹配，期望 ${required.length}，实际 ${requiredList.length}');
    }

    test('list_novels — 无参数', () {
      verifyToolSchema('list_novels');
    });

    test('select_novel — 需要 novelId', () {
      verifyToolSchema('select_novel', required: ['novelId']);
    });

    test('create_novel — 需要 title, description 可选', () {
      verifyToolSchema('create_novel',
          required: ['title'], optional: ['description']);
    });

    test('read_chapter_content — 需要 position', () {
      verifyToolSchema('read_chapter_content', required: ['position']);
    });

    test('list_chapters — 无参数（从上下文读取当前小说）', () {
      verifyToolSchema('list_chapters');
    });

    test('search_in_chapters — 需要 keyword', () {
      verifyToolSchema('search_in_chapters', required: ['keyword']);
    });

    test('update_chapter_content — 需要 position + content', () {
      verifyToolSchema('update_chapter_content',
          required: ['position', 'content']);
    });

    test('create_custom_chapter — 需要 title + content, position 可选', () {
      verifyToolSchema('create_custom_chapter',
          required: ['title', 'content'], optional: ['position']);
    });

    test('list_characters — 无参数（从上下文读取当前小说）', () {
      verifyToolSchema('list_characters');
    });

    test('update_character — 需要 name, description/avatarUrl 可选', () {
      verifyToolSchema('update_character',
          required: ['name'],
          optional: ['description', 'avatarUrl']);
    });

    test('create_character — 需要 name, description 可选', () {
      verifyToolSchema('create_character',
          required: ['name'], optional: ['description']);
    });

    test('update_background_setting — 需要 setting', () {
      verifyToolSchema('update_background_setting', required: ['setting']);
    });

    test('update_outline — 需要 title + content', () {
      verifyToolSchema('update_outline',
          required: ['title', 'content']);
    });

    test('get_outline — 无参数（从上下文读取当前小说）', () {
      verifyToolSchema('get_outline');
    });
  });

  group('AgentTools — 参数类型验证', () {
    test('position 参数应为 integer 类型', () {
      final tools = [
        'read_chapter_content',
        'update_chapter_content',
      ];
      for (final name in tools) {
        final tool = AgentTools.findTool(name);
        final props = tool!['function']['parameters']['properties']
            as Map<String, dynamic>;
        final position = props['position'] as Map<String, dynamic>?;
        expect(position, isNotNull, reason: '$name 缺少 position');
        expect(position!['type'], 'integer',
            reason: '$name position 应为 integer 类型');
      }
    });

    test('novelId 参数（仅 select_novel 有）应为 integer 类型', () {
      final tool = AgentTools.findTool('select_novel');
      final props = tool!['function']['parameters']['properties']
          as Map<String, dynamic>;
      final novelId = props['novelId'] as Map<String, dynamic>?;
      expect(novelId, isNotNull, reason: 'select_novel 缺少 novelId');
      expect(novelId!['type'], 'integer',
          reason: 'select_novel novelId 应为 integer 类型');
    });

    test('任何工具都不应有 chapterId 参数（已改为 position）', () {
      for (final tool in AgentTools.allTools) {
        final props = tool['function']['parameters']['properties']
            as Map<String, dynamic>;
        expect(props.containsKey('chapterId'), false,
            reason: '${tool['function']['name']} 不应再有 chapterId 参数');
      }
    });

    test('任何工具都不应有 chapterUrl 参数', () {
      for (final tool in AgentTools.allTools) {
        final props = tool['function']['parameters']['properties']
            as Map<String, dynamic>;
        expect(props.containsKey('chapterUrl'), false,
            reason: '${tool['function']['name']} 不应再有 chapterUrl 参数');
      }
    });

    test('任何工具都不应有 novelUrl 参数', () {
      for (final tool in AgentTools.allTools) {
        final props = tool['function']['parameters']['properties']
            as Map<String, dynamic>;
        expect(props.containsKey('novelUrl'), false,
            reason: '${tool['function']['name']} 不应再有 novelUrl 参数');
      }
    });

    test('除 select_novel 外，任何工具都不应有 novelId 参数', () {
      for (final tool in AgentTools.allTools) {
        final name = tool['function']['name'] as String;
        if (name == 'select_novel') continue;
        final props = tool['function']['parameters']['properties']
            as Map<String, dynamic>;
        expect(props.containsKey('novelId'), false,
            reason: '$name 不应再有 novelId 参数（已改为上下文驱动）');
      }
    });

    test('create_novel 不暴露 author 字段（硬编码为"原创"）', () {
      final tool = AgentTools.findTool('create_novel');
      final props = tool!['function']['parameters']['properties']
          as Map<String, dynamic>;
      expect(props.containsKey('author'), false,
          reason: 'create_novel 不应暴露 author 字段，固定为"原创"');
    });
  });

  group('AgentTools.findTool', () {
    test('找到存在的工具', () {
      final tool = AgentTools.findTool('list_novels');
      expect(tool, isNotNull);
      expect(tool!['function']['name'], 'list_novels');
    });

    test('找到新增的 select_novel', () {
      final tool = AgentTools.findTool('select_novel');
      expect(tool, isNotNull);
      expect(tool!['function']['name'], 'select_novel');
    });

    test('找不到不存在的工具 → 返回 null', () {
      final tool = AgentTools.findTool('non_existent_tool');
      expect(tool, isNull);
    });

    test('所有 14 个工具都能被 findTool 找到', () {
      final names =
          AgentTools.allTools.map((t) => t['function']['name'] as String).toList();
      for (final name in names) {
        expect(AgentTools.findTool(name), isNotNull,
            reason: 'findTool("$name") 应该能找到');
      }
    });
  });

  group('AgentTools.isDestructive', () {
    test('当前已禁用工具确认 — 所有工具均非破坏性', () {
      final allToolNames = [
        'select_novel',
        'update_chapter_content',
        'create_custom_chapter',
        'update_character',
        'create_character',
        'update_background_setting',
        'update_outline',
        'list_novels',
        'read_chapter_content',
        'list_chapters',
        'search_in_chapters',
        'list_characters',
        'get_outline',
      ];
      for (final name in allToolNames) {
        expect(AgentTools.isDestructive(name), false,
            reason: '$name 当前不应该被标记为破坏性工具（已禁用确认）');
      }
    });

    test('不存在的工具 → 非破坏性', () {
      expect(AgentTools.isDestructive('non_existent'), false);
    });

    test('destructiveTools 集合当前为空（已禁用确认）', () {
      expect(AgentTools.destructiveTools.length, 0);
    });
  });

  group('AgentTools — 工具 JSON 序列化兼容性', () {
    test('每个工具定义都能被 jsonEncode 序列化', () {
      for (final tool in AgentTools.allTools) {
        expect(
          () => jsonEncode(tool),
          returnsNormally,
          reason: '${tool['function']['name']} 无法序列化为 JSON',
        );
      }
    });

    test('序列化后能被反序列化回来', () {
      for (final tool in AgentTools.allTools) {
        final json = jsonEncode(tool);
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        expect(decoded['function']['name'],
            tool['function']['name']);
      }
    });
  });
}
