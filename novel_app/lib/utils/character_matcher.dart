import 'package:flutter/foundation.dart';
import '../models/character.dart';
import '../services/database_service.dart';

/// 角色名称匹配工具类
/// 用于分析章节内容中的角色出现情况并准备角色更新数据
class CharacterMatcher {
  static final DatabaseService _databaseService = DatabaseService();
  CharacterMatcher._();

  /// 从章节内容中提取出现的角色ID列表（支持别名，不区分大小写）
  ///
  /// [content] 文本内容
  /// [characters] 角色列表
  ///
  /// 返回在内容中出现的角色ID列表
  static List<int> findAppearingCharacterIds(
    String content,
    List<Character> characters,
  ) {
    if (content.isEmpty || characters.isEmpty) {
      return [];
    }

    final appearingIds = <int>{};
    final lowerContent = content.toLowerCase();

    for (final character in characters) {
      if (character.name.isEmpty) continue;

      // 检查正式名称
      final lowerName = character.name.toLowerCase();
      if (lowerContent.contains(lowerName) && character.id != null) {
        appearingIds.add(character.id!);
        continue;
      }

      // 检查别名
      final aliases = character.aliases ?? [];
      for (final alias in aliases) {
        if (alias.isEmpty) continue;
        final lowerAlias = alias.toLowerCase();
        if (lowerContent.contains(lowerAlias) && character.id != null) {
          appearingIds.add(character.id!);
          break;
        }
      }
    }

    return appearingIds.toList();
  }

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
      // 检查角色名称或别名是否在章节内容中出现
      if (_isCharacterOrAliasInChapter(character, chapterContent)) {
        foundCharacters.add(character);
      }
    }

    return foundCharacters;
  }

  /// 检查角色名称或别名是否在章节中出现
  ///
  /// [character] 角色
  /// [chapterContent] 章节内容
  ///
  /// 返回是否匹配到角色
  static bool _isCharacterOrAliasInChapter(
    Character character,
    String chapterContent,
  ) {
    // 检查正式名称
    if (chapterContent.contains(character.name)) {
      return true;
    }

    // 检查别名
    final aliases = character.aliases ?? [];
    for (final alias in aliases) {
      if (chapterContent.contains(alias)) {
        return true;
      }
    }

    return false;
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
    final rolesToInclude =
        chapterCharacters.isNotEmpty ? chapterCharacters : existingCharacters;

    return {
      'chapters_content': chapterContent,
      'roles': Character.toJsonArray(rolesToInclude), // 使用Character类的JSON格式化方法
    };
  }

  /// 检查角色是否需要更新
  ///
  /// [character] 要检查的角色
  /// [chapterContent] 章节内容
  ///
  /// 返回角色是否在章节中出现
  static bool isCharacterInChapter(Character character, String chapterContent) {
    return _isCharacterOrAliasInChapter(character, chapterContent);
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
      '这个',
      '那个',
      '什么',
      '没有',
      '可以',
      '应该',
      '已经',
      '还是',
      '因为',
      '所以',
      '但是',
      '然后',
      '不过',
      '如果',
      '虽然',
      '即使',
      '时候',
      '地方',
      '东西',
      '问题',
      '办法',
      '情况',
      '样子',
      '感觉',
      '先生',
      '小姐',
      '女士',
      '老板',
      '经理',
      '主任',
      '同学',
      '朋友',
      '老师',
      '学生',
      '医生',
      '护士',
      '警察',
      '司机',
      '服务员',
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
      '王',
      '李',
      '张',
      '刘',
      '陈',
      '杨',
      '赵',
      '黄',
      '周',
      '吴',
      '徐',
      '孙',
      '胡',
      '朱',
      '高',
      '林',
      '何',
      '郭',
      '马',
      '罗',
      '梁',
      '宋',
      '郑',
      '谢',
      '韩',
      '唐',
      '冯',
      '于',
      '董',
      '萧',
      '程',
      '曹',
      '袁',
      '邓',
      '许',
      '傅',
      '沈',
      '曾',
      '彭',
      '吕',
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
      appearanceFeatures:
          newCharacter.appearanceFeatures ?? oldCharacter.appearanceFeatures,
      backgroundStory:
          newCharacter.backgroundStory ?? oldCharacter.backgroundStory,
      updatedAt: DateTime.now(),
    );
  }

  /// 统计角色在章节中的出现次数
  ///
  /// [character] 角色
  /// [chapterContent] 章节内容
  ///
  /// 返回角色在章节中出现的次数（包括正式名称和所有别名）
  static int countCharacterOccurrences(
      Character character, String chapterContent) {
    int count = 0;

    // 统计正式名称出现次数
    final namePattern = RegExp(RegExp.escape(character.name));
    count += namePattern.allMatches(chapterContent).length;

    // 统计所有别名出现次数
    final aliases = character.aliases ?? [];
    for (final alias in aliases) {
      final aliasPattern = RegExp(RegExp.escape(alias));
      count += aliasPattern.allMatches(chapterContent).length;
    }

    return count;
  }

  /// 检查别名冲突
  ///
  /// [newAlias] 要添加的新别名
  /// [currentCharacter] 当前角色
  /// [allCharacters] 同一小说的所有角色
  ///
  /// 返回冲突信息，如果没有冲突返回null
  static String? checkAliasConflict(
    String newAlias,
    Character currentCharacter,
    List<Character> allCharacters,
  ) {
    for (final character in allCharacters) {
      // 跳过自己
      if (character.id == currentCharacter.id) continue;

      // 检查新别名是否与其他角色的正式名称冲突
      if (character.name == newAlias) {
        return '别名 "$newAlias" 与角色 "${character.name}" 的正式名称相同';
      }

      // 检查新别名是否与其他角色的别名冲突
      final existingAliases = character.aliases ?? [];
      if (existingAliases.contains(newAlias)) {
        return '别名 "$newAlias" 与角色 "${character.name}" 的别名重复';
      }
    }

    return null;
  }
}
