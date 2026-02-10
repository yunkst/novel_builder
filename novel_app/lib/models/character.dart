import 'dart:convert';
import 'package:novel_api/novel_api.dart';

class Character {
  final int? id;
  final String novelUrl;
  final String name;
  final int? age;
  final String? gender;
  final String? occupation;
  final String? personality;
  final String? bodyType;
  final String? clothingStyle;
  final String? appearanceFeatures;
  final String? backgroundStory;
  final String? facePrompts; // 面部提示词
  final String? bodyPrompts; // 身材提示词
  final String? cachedImageUrl; // 缓存的图集第一张图片路径
  final List<String>? aliases; // 别名列表，上限10个
  final DateTime createdAt;
  final DateTime? updatedAt;

  Character({
    this.id,
    required this.novelUrl,
    required this.name,
    this.age,
    this.gender,
    this.occupation,
    this.personality,
    this.bodyType,
    this.clothingStyle,
    this.appearanceFeatures,
    this.backgroundStory,
    this.facePrompts, // 面部提示词
    this.bodyPrompts, // 身材提示词
    this.cachedImageUrl, // 缓存的图集第一张图片路径
    this.aliases, // 别名列表
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'novelUrl': novelUrl,
      'name': name,
      'age': age,
      'gender': gender,
      'occupation': occupation,
      'personality': personality,
      'bodyType': bodyType,
      'clothingStyle': clothingStyle,
      'appearanceFeatures': appearanceFeatures,
      'backgroundStory': backgroundStory,
      'facePrompts': facePrompts,
      'bodyPrompts': bodyPrompts,
      'cachedImageUrl': cachedImageUrl,
      'aliases': aliases?.isEmpty ?? true ? null : jsonEncode(aliases),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory Character.fromMap(Map<String, dynamic> map) {
    List<String>? parseAliases(String? aliasesJson) {
      if (aliasesJson == null || aliasesJson.isEmpty) return null;
      try {
        final decoded = jsonDecode(aliasesJson) as List;
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return null;
      }
    }

    return Character(
      id: map['id']?.toInt(),
      novelUrl: map['novelUrl'] as String,
      name: map['name'] as String,
      age: map['age']?.toInt(),
      gender: map['gender'] as String?,
      occupation: map['occupation'] as String?,
      personality: map['personality'] as String?,
      bodyType: map['bodyType'] as String?,
      clothingStyle: map['clothingStyle'] as String?,
      appearanceFeatures: map['appearanceFeatures'] as String?,
      backgroundStory: map['backgroundStory'] as String?,
      facePrompts: map['facePrompts'] as String?,
      bodyPrompts: map['bodyPrompts'] as String?,
      cachedImageUrl: map['cachedImageUrl'] as String?,
      aliases: parseAliases(map['aliases'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }

  Character copyWith({
    int? id,
    String? novelUrl,
    String? name,
    int? age,
    String? gender,
    String? occupation,
    String? personality,
    String? bodyType,
    String? clothingStyle,
    String? appearanceFeatures,
    String? backgroundStory,
    String? facePrompts,
    String? bodyPrompts,
    String? cachedImageUrl,
    List<String>? aliases,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Character(
      id: id ?? this.id,
      novelUrl: novelUrl ?? this.novelUrl,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      personality: personality ?? this.personality,
      bodyType: bodyType ?? this.bodyType,
      clothingStyle: clothingStyle ?? this.clothingStyle,
      appearanceFeatures: appearanceFeatures ?? this.appearanceFeatures,
      backgroundStory: backgroundStory ?? this.backgroundStory,
      facePrompts: facePrompts ?? this.facePrompts,
      bodyPrompts: bodyPrompts ?? this.bodyPrompts,
      cachedImageUrl: cachedImageUrl ?? this.cachedImageUrl,
      aliases: aliases ?? this.aliases,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // AI友好的格式化文本输出
  static String formatForAI(List<Character> characters) {
    if (characters.isEmpty) return '无特定角色出场';

    String rolesInfo = '【出场人物】\n';

    for (int i = 0; i < characters.length; i++) {
      final char = characters[i];
      rolesInfo += '''
${i + 1}. ${char.name}
   基本信息：${char.gender ?? '未知'}，${char.age ?? '未知'}岁，${char.occupation ?? '未知职业'}
   性格特点：${char.personality ?? '待补充'}
   外貌特征：${char.appearanceFeatures ?? '待补充'}
   身材体型：${char.bodyType ?? '待补充'}
   穿衣风格：${char.clothingStyle ?? '待补充'}
   背景经历：${char.backgroundStory ?? '待补充'}
''';
    }

    return rolesInfo;
  }

  /// 将角色列表转换为JSON数组字符串
  ///
  /// 用于传递给Dify等服务，提供结构化的角色数据。
  /// 返回标准JSON数组格式的字符串，包含角色的完整信息。
  ///
  /// [characters] 要转换的Character对象列表
  ///
  /// 返回JSON数组字符串，例如：[{"name":"张三","age":25,"gender":"男"}]
  ///
  /// 注意：
  /// - 空列表返回 "[]"
  /// - 包含所有角色字段，null值会被保留为JSON null
  /// - aliases列表直接包含在JSON中（非字符串）
  static String toJsonArray(List<Character> characters) {
    if (characters.isEmpty) return '[]';

    final jsonList = characters
        .map((c) => {
              'name': c.name,
              'gender': c.gender,
              'age': c.age,
              'occupation': c.occupation,
              'personality': c.personality,
              'bodyType': c.bodyType,
              'clothingStyle': c.clothingStyle,
              'appearanceFeatures': c.appearanceFeatures,
              'backgroundStory': c.backgroundStory,
              'aliases': c.aliases,
            })
        .toList();

    return jsonEncode(jsonList);
  }

  /// 转换为API客户端的RoleInfo列表
  ///
  /// 将Character对象列表转换为RoleInfo对象列表，用于API调用。
  /// 此方法主要用于场景插图生成和角色卡生成功能。
  ///
  /// [characters] 要转换的Character对象列表
  ///
  /// 返回包含所有角色信息的RoleInfo列表
  ///
  /// 注意：
  /// - 如果Character.id为null，将使用0作为默认值
  /// - 所有可选字段将原样传递，null值会被保留
  /// - 建议在调用前确保Character对象的数据完整性
  static List<RoleInfo> toRoleInfoList(List<Character> characters) {
    if (characters.isEmpty) return [];

    return characters.map((char) {
      return RoleInfo((b) => b
        ..id = char.id ?? 0 // 使用0作为默认值，实际应该确保id不为空
        ..name = char.name
        ..gender = char.gender
        ..age = char.age
        ..occupation = char.occupation
        ..personality = char.personality
        ..appearanceFeatures = char.appearanceFeatures
        ..bodyType = char.bodyType
        ..clothingStyle = char.clothingStyle
        ..backgroundStory = char.backgroundStory
        ..facePrompts = char.facePrompts
        ..bodyPrompts = char.bodyPrompts);
    }).toList();
  }
}
