import 'package:flutter/foundation.dart';
import '../models/character.dart';
import '../services/database_service.dart';

/// 角色名称匹配工具类
/// 用于分析章节内容中的角色出现情况并准备角色更新数据
class CharacterMatcher {
  static final DatabaseService _databaseService = DatabaseService();

  /// 从章节内容中提取出现的角色名称
  ///
  /// [chapterContent] 章节内容
  /// [existingCharacters] 现有角色列表
  ///
  /// 返回在章节中出现的角色列表
  static List<Character> extractCharactersFromChapter(
    String chapterContent,
    List<Character> existingCharacters,
  ) {
    final foundCharacters = <Character>[];

    for (final character in existingCharacters) {
      // 检查角色名称是否在章节内容中出现
      if (chapterContent.contains(character.name)) {
        foundCharacters.add(character);
      }
    }

    return foundCharacters;
  }

  /// 将角色列表格式化为Dify所需的格式
  ///
  /// [characters] 角色列表
  ///
  /// 返回AI友好的角色信息字符串
  static String formatRolesForDify(List<Character> characters) {
    return Character.formatForAI(characters);
  }

  /// 查找指定小说的所有现有角色
  ///
  /// [novelUrl] 小说URL
  ///
  /// 返回角色列表
  static Future<List<Character>> findExistingCharacters(String novelUrl) async {
    try {
      return await _databaseService.getCharacters(novelUrl);
    } catch (e) {
      debugPrint('获取现有角色失败: $e');
      return [];
    }
  }

  /// 准备角色更新数据
  ///
  /// [novelUrl] 小说URL
  /// [chapterContent] 当前章节内容
  ///
  /// 返回包含chapters_content和roles的Map
  static Future<Map<String, String>> prepareUpdateData(
    String novelUrl,
    String chapterContent,
  ) async {
    // 获取所有现有角色
    final existingCharacters = await findExistingCharacters(novelUrl);

    // 提取章节中出现的角色
    final chapterCharacters = extractCharactersFromChapter(
      chapterContent,
      existingCharacters,
    );

    // 如果章节中没有出现任何角色，包含所有角色作为参考
    final rolesToInclude = chapterCharacters.isNotEmpty
        ? chapterCharacters
        : existingCharacters;

    return {
      'chapters_content': chapterContent,
      'roles': formatRolesForDify(rolesToInclude),
    };
  }

  /// 检查角色是否需要更新
  ///
  /// [character] 要检查的角色
  /// [chapterContent] 章节内容
  ///
  /// 返回角色是否在章节中出现
  static bool isCharacterInChapter(Character character, String chapterContent) {
    return chapterContent.contains(character.name);
  }

  /// 获取章节中所有可能的角色名称（简单启发式方法）
  ///
  /// [chapterContent] 章节内容
  ///
  /// 返回可能的角色名称列表
  static List<String> extractPotentialCharacterNames(String chapterContent) {
    // 简单的启发式方法：查找中文人名模式
    // 这可以作为基础实现，后续可以优化为更复杂的NLP方法
    final names = <String>[];

    // 匹配中文姓名模式（2-4个中文字符）
    final namePattern = RegExp(r'[\u4e00-\u9fff]{2,4}');
    final matches = namePattern.allMatches(chapterContent);

    // 统计名称出现频率
    final nameFrequency = <String, int>{};
    for (final match in matches) {
      final name = match.group(0)!;
      nameFrequency[name] = (nameFrequency[name] ?? 0) + 1;
    }

    // 过滤掉出现频率太低的名称（可能是普通词汇）
    nameFrequency.forEach((name, frequency) {
      if (frequency >= 2 && _isLikelyCharacterName(name)) {
        names.add(name);
      }
    });

    return names.toSet().toList();
  }

  /// 判断字符串是否可能是角色名称
  ///
  /// [name] 要检查的名称
  ///
  /// 返回是否可能是角色名称
  static bool _isLikelyCharacterName(String name) {
    // 排除一些常见的非人名词汇
    final excludeWords = {
      '这个', '那个', '什么', '没有', '可以', '应该', '已经', '还是',
      '因为', '所以', '但是', '然后', '不过', '如果', '虽然', '即使',
      '时候', '地方', '东西', '问题', '办法', '情况', '样子', '感觉',
      '先生', '小姐', '女士', '老板', '经理', '主任', '同学', '朋友',
      '老师', '学生', '医生', '护士', '警察', '司机', '服务员',
    };

    // 如果是排除词汇，不是角色名称
    if (excludeWords.contains(name)) {
      return false;
    }

    // 如果包含非中文字符，不太可能是角色名称
    if (name.contains(RegExp(r'[^\u4e00-\u9fff]'))) {
      return false;
    }

    // 常见的姓氏
    final commonSurnames = {
      '王', '李', '张', '刘', '陈', '杨', '赵', '黄', '周', '吴',
      '徐', '孙', '胡', '朱', '高', '林', '何', '郭', '马', '罗',
      '梁', '宋', '郑', '谢', '韩', '唐', '冯', '于', '董', '萧',
      '程', '曹', '袁', '邓', '许', '傅', '沈', '曾', '彭', '吕',
    };

    // 如果第一个字是常见姓氏，更可能是角色名称
    if (commonSurnames.contains(name.substring(0, 1))) {
      return true;
    }

    // 默认认为2-3个中文字符的是可能的名称
    return name.length >= 2 && name.length <= 3;
  }

  /// 合并新旧角色信息（用于更新逻辑）
  ///
  /// [oldCharacter] 旧的角色信息
  /// [newCharacter] 新的角色信息
  ///
  /// 返回合并后的角色信息
  static Character mergeCharacterInfo(
    Character oldCharacter,
    Character newCharacter,
  ) {
    return oldCharacter.copyWith(
      age: newCharacter.age ?? oldCharacter.age,
      gender: newCharacter.gender ?? oldCharacter.gender,
      occupation: newCharacter.occupation ?? oldCharacter.occupation,
      personality: newCharacter.personality ?? oldCharacter.personality,
      bodyType: newCharacter.bodyType ?? oldCharacter.bodyType,
      clothingStyle: newCharacter.clothingStyle ?? oldCharacter.clothingStyle,
      appearanceFeatures: newCharacter.appearanceFeatures ?? oldCharacter.appearanceFeatures,
      backgroundStory: newCharacter.backgroundStory ?? oldCharacter.backgroundStory,
      updatedAt: DateTime.now(),
    );
  }

  /// 统计角色在章节中的出现次数
  ///
  /// [character] 角色
  /// [chapterContent] 章节内容
  ///
  /// 返回角色在章节中出现的次数
  static int countCharacterOccurrences(Character character, String chapterContent) {
    final pattern = RegExp(RegExp.escape(character.name));
    return pattern.allMatches(chapterContent).length;
  }
}