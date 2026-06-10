/// AgentTools 工具定义单元测试
///
/// 验证 14 个工具的 OpenAI Function Calling schema：
/// - 工具总数正确
/// - 每个工具的 name、description、parameters 结构合法
/// - required 参数列表正确
/// - findTool 查找功能
/// - isDestructive 判定（9 个破坏性 + 5 个非破坏性）
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/agent_tools.dart';

void main() {
  group('AgentTools.allTools — 基础验证', () {
    test('应该有 15 个工具', () {
      expect(AgentTools.allTools.length, 15);
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

    test('read_chapter_content — 需要 chapterId', () {
      verifyToolSchema('read_chapter_content', required: ['chapterId']);
    });

    test('list_chapters — 需要 novelId', () {
      verifyToolSchema('list_chapters', required: ['novelId']);
    });

    test('search_in_chapters — 需要 novelId + keyword', () {
      verifyToolSchema('search_in_chapters',
          required: ['novelId', 'keyword']);
    });

    test('update_chapter_content — 需要 chapterId + content', () {
      verifyToolSchema('update_chapter_content',
          required: ['chapterId', 'content']);
    });

    test('rewrite_chapter_paragraph — 需要 chapterId + paragraphIndex + instruction', () {
      verifyToolSchema('rewrite_chapter_paragraph',
          required: ['chapterId', 'paragraphIndex', 'instruction']);
    });

    test('insert_paragraph — 需要 chapterId + afterParagraphIndex + newParagraph', () {
      verifyToolSchema('insert_paragraph',
          required: ['chapterId', 'afterParagraphIndex', 'newParagraph']);
    });

    test('delete_paragraph — 需要 chapterId + paragraphIndex', () {
      verifyToolSchema('delete_paragraph',
          required: ['chapterId', 'paragraphIndex']);
    });

    test('create_custom_chapter — 需要 novelId + title + content, index 可选', () {
      verifyToolSchema('create_custom_chapter',
          required: ['novelId', 'title', 'content'], optional: ['index']);
    });

    test('list_characters — 需要 novelId', () {
      verifyToolSchema('list_characters', required: ['novelId']);
    });

    test('update_character — 需要 novelId + name, description/avatarUrl 可选', () {
      verifyToolSchema('update_character',
          required: ['novelId', 'name'],
          optional: ['description', 'avatarUrl']);
    });

    test('create_character — 需要 novelId + name, description 可选', () {
      verifyToolSchema('create_character',
          required: ['novelId', 'name'], optional: ['description']);
    });

    test('update_background_setting — 需要 novelId + setting', () {
      verifyToolSchema('update_background_setting',
          required: ['novelId', 'setting']);
    });

    test('update_outline — 需要 novelId + title + content', () {
      verifyToolSchema('update_outline',
          required: ['novelId', 'title', 'content']);
    });

    test('get_outline — 需要 novelId', () {
      verifyToolSchema('get_outline', required: ['novelId']);
    });
  });

  group('AgentTools — ID 类型验证', () {
    test('chapterId 参数应为 integer 类型', () {
      final tools = [
        'read_chapter_content',
        'update_chapter_content',
        'rewrite_chapter_paragraph',
        'insert_paragraph',
        'delete_paragraph',
      ];
      for (final name in tools) {
        final tool = AgentTools.findTool(name);
        final props = tool!['function']['parameters']['properties']
            as Map<String, dynamic>;
        final chapterId = props['chapterId'] as Map<String, dynamic>?;
        expect(chapterId, isNotNull, reason: '$name 缺少 chapterId');
        expect(chapterId!['type'], 'integer',
            reason: '$name chapterId 应为 integer 类型');
      }
    });

    test('novelId 参数应为 integer 类型', () {
      final tools = [
        'list_chapters',
        'search_in_chapters',
        'create_custom_chapter',
        'list_characters',
        'update_character',
        'create_character',
        'update_background_setting',
        'update_outline',
        'get_outline',
      ];
      for (final name in tools) {
        final tool = AgentTools.findTool(name);
        final props = tool!['function']['parameters']['properties']
            as Map<String, dynamic>;
        final novelId = props['novelId'] as Map<String, dynamic>?;
        expect(novelId, isNotNull, reason: '$name 缺少 novelId');
        expect(novelId!['type'], 'integer',
            reason: '$name novelId 应为 integer 类型');
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
  });

  group('AgentTools.findTool', () {
    test('找到存在的工具', () {
      final tool = AgentTools.findTool('list_novels');
      expect(tool, isNotNull);
      expect(tool!['function']['name'], 'list_novels');
    });

    test('找不到不存在的工具 → 返回 null', () {
      final tool = AgentTools.findTool('non_existent_tool');
      expect(tool, isNull);
    });

    test('所有 15 个工具都能被 findTool 找到', () {
      final names =
          AgentTools.allTools.map((t) => t['function']['name'] as String).toList();
      for (final name in names) {
        expect(AgentTools.findTool(name), isNotNull,
            reason: 'findTool("$name") 应该能找到');
      }
    });
  });

  group('AgentTools.isDestructive', () {
    test('破坏性工具 (9个)', () {
      final destructive = [
        'update_chapter_content',
        'rewrite_chapter_paragraph',
        'delete_paragraph',
        'insert_paragraph',
        'create_custom_chapter',
        'update_character',
        'create_character',
        'update_background_setting',
        'update_outline',
      ];
      for (final name in destructive) {
        expect(AgentTools.isDestructive(name), true,
            reason: '$name 应该是破坏性工具');
      }
    });

    test('非破坏性工具 (5个)', () {
      final nonDestructive = [
        'list_novels',
        'read_chapter_content',
        'list_chapters',
        'search_in_chapters',
        'list_characters',
        'get_outline',
      ];
      for (final name in nonDestructive) {
        expect(AgentTools.isDestructive(name), false,
            reason: '$name 不应该是破坏性工具');
      }
    });

    test('不存在的工具 → 非破坏性', () {
      expect(AgentTools.isDestructive('non_existent'), false);
    });

    test('destructiveTools 集合大小正确', () {
      expect(AgentTools.destructiveTools.length, 9);
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
