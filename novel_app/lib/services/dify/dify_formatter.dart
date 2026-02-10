import 'dart:convert';
import '../../models/character.dart';
import '../../models/character_relationship.dart';
import '../../services/logger_service.dart';

/// Dify数据格式化工具
///
/// 负责将各种数据模型转换为Dify API所需的格式
class DifyFormatter {
  /// 格式化角色信息为AI友好的文本格式
  ///
  /// 使用Character.formatForAI方法生成AI友好的角色信息格式
  static String formatCharacters(List<Character> characters) {
    return Character.formatForAI(characters);
  }

  /// 格式化角色信息为AI友好的JSON字符串
  ///
  /// 用于AI伴读等功能，将角色信息转换为JSON数组格式
  static String formatCharactersForAI(List<Character> characters) {
    if (characters.isEmpty) {
      return jsonEncode([]);
    }

    final List<Map<String, dynamic>> charactersData = characters.map((c) {
      return {
        'name': c.name,
        if (c.gender != null) 'gender': c.gender,
        if (c.age != null) 'age': c.age,
        if (c.occupation != null) 'occupation': c.occupation,
        if (c.personality != null) 'personality': c.personality,
        if (c.bodyType != null) 'bodyType': c.bodyType,
        if (c.clothingStyle != null) 'clothingStyle': c.clothingStyle,
        if (c.appearanceFeatures != null)
          'appearanceFeatures': c.appearanceFeatures,
        if (c.backgroundStory != null) 'backgroundStory': c.backgroundStory,
      };
    }).toList();

    return jsonEncode(charactersData);
  }

  /// 格式化关系信息为AI友好的文本格式
  ///
  /// 输出格式：角色A → 关系类型 → 角色B
  /// 例如：
  ///   张三 → 师徒 → 李四
  ///   王五 → 恋人 → 赵六
  ///
  /// 注意：会过滤掉包含未在角色列表中的角色的关系
  static String formatRelationships(
    List<CharacterRelationship> relationships,
    List<Character> characters,
  ) {
    if (relationships.isEmpty) {
      return '';
    }

    // 创建角色ID到名称的映射
    final Map<int, String> characterIdToName = {
      for (var c in characters)
        if (c.id != null) c.id!: c.name,
    };

    // 过滤掉包含未出现角色的关系
    final validRelationships = relationships.where((r) {
      return characterIdToName.containsKey(r.sourceCharacterId) &&
          characterIdToName.containsKey(r.targetCharacterId);
    });

    // 如果有被过滤的关系，记录日志
    if (validRelationships.length < relationships.length) {
      final filteredCount = relationships.length - validRelationships.length;
      LoggerService.instance.i(
        '🔍 AI伴读：过滤了 $filteredCount 条包含未出现角色的关系',
        category: LogCategory.ai,
        tags: ['ai-companion', 'relationships', 'filtered'],
      );
    }

    // 格式化为 "角色A → 关系类型 → 角色B"
    final relations = validRelationships.map((r) {
      final sourceName = characterIdToName[r.sourceCharacterId]!;
      final targetName = characterIdToName[r.targetCharacterId]!;
      return '$sourceName → ${r.relationshipType} → $targetName';
    }).join('\n');

    return relations;
  }

  /// 格式化场景描写输入参数
  ///
  /// 将章节内容和角色列表转换为Dify API所需的输入格式
  static Map<String, dynamic> formatSceneDescriptionInput({
    required String chapterContent,
    required List<Character> characters,
  }) {
    final rolesText = formatCharacters(characters);

    return {
      'current_chapter_content': chapterContent,
      'roles': rolesText,
      'cmd': '场景描写',
    };
  }
}
