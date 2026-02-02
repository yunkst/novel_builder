/// AI伴读响应数据模型
///
/// 用于解析Dify工作流返回的结构化数据
///
/// 返回格式：
/// ```json
/// {
///   "content": {
///     "roles": [...],
///     "background": "...",
///     "summery": "...",
///     "relations": [...]
///   }
/// }
/// ```
///
/// {@category AIModels}
library;

import 'character.dart';
import 'character_update.dart';

/// 角色信息
///
/// 包含角色的各种属性，如姓名、性别、年龄、职业等
class AICompanionRole {
  /// 角色姓名
  final String name;

  /// 性别
  final String? gender;

  /// 年龄
  final int? age;

  /// 职业
  final String? occupation;

  /// 性格
  final String? personality;

  /// 身材
  final String? bodyType;

  /// 穿衣风格
  final String? clothingStyle;

  /// 外貌特点
  final String? appearanceFeatures;

  /// 经历简述
  final String? backgroundStory;

  const AICompanionRole({
    required this.name,
    this.gender,
    this.age,
    this.occupation,
    this.personality,
    this.bodyType,
    this.clothingStyle,
    this.appearanceFeatures,
    this.backgroundStory,
  });

  /// 从JSON创建实例
  factory AICompanionRole.fromJson(Map<String, dynamic> json) {
    return AICompanionRole(
      name: json['name']?.toString() ?? '',
      gender: json['gender']?.toString(),
      age: json['age'] is String
          ? int.tryParse(json['age'])
          : json['age']?.toInt(),
      occupation: json['occupation']?.toString(),
      personality: json['personality']?.toString(),
      bodyType: json['bodyType']?.toString(),
      clothingStyle: json['clothingStyle']?.toString(),
      appearanceFeatures: json['appearanceFeatures']?.toString(),
      backgroundStory: json['backgroundStory']?.toString(),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      'age': age,
      'occupation': occupation,
      'personality': personality,
      'bodyType': bodyType,
      'clothingStyle': clothingStyle,
      'appearanceFeatures': appearanceFeatures,
      'backgroundStory': backgroundStory,
    };
  }

  @override
  String toString() {
    return 'AICompanionRole(name: $name, gender: $gender, age: $age)';
  }

  /// 转换为Character对象
  ///
  /// 将AI伴读返回的角色信息转换为应用的Character模型
  ///
  /// [novelUrl] 小说的URL，必需字段
  ///
  /// 返回Character对象，用于角色预览对话框展示和数据库更新
  Character toCharacter(String novelUrl) {
    return Character(
      novelUrl: novelUrl,
      name: name,
      gender: gender,
      age: age,
      occupation: occupation,
      personality: personality,
      bodyType: bodyType,
      clothingStyle: clothingStyle,
      appearanceFeatures: appearanceFeatures,
      backgroundStory: backgroundStory,
    );
  }

  /// 转换为CharacterUpdate对象
  ///
  /// 将AI伴读返回的角色信息包装为CharacterUpdate，
  /// 用于角色预览对话框展示
  ///
  /// [novelUrl] 小说的URL，必需字段
  ///
  /// 返回CharacterUpdate对象，oldCharacter为null表示这是新增或AI建议的更新
  CharacterUpdate toCharacterUpdate(String novelUrl) {
    return CharacterUpdate(
      newCharacter: toCharacter(novelUrl),
      oldCharacter: null,
    );
  }
}

class AICompanionRelation {
  /// 关系的起点人物名
  ///
  /// 例如：A是B的徒弟，则此字段为A
  final String source;

  /// 关系的终点人物名
  ///
  /// 例如：A是B的徒弟，则此字段为B
  final String target;

  /// 关系类型
  ///
  /// 例如：A是B的徒弟，则此字段为"徒弟"
  final String type;

  const AICompanionRelation({
    required this.source,
    required this.target,
    required this.type,
  });

  /// 从JSON创建实例
  factory AICompanionRelation.fromJson(Map<String, dynamic> json) {
    return AICompanionRelation(
      source: json['source']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'target': target,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'AICompanionRelation(source: $source, target: $target, type: $type)';
  }
}

class AICompanionResponse {
  /// 需要更新的角色信息
  ///
  /// AI返回的角色卡，需要结合旧角色卡的信息进行更新，不要覆盖旧角色卡信息
  final List<AICompanionRole> roles;

  /// 新增的背景设定
  ///
  /// 不需要重复旧的背景设定，就把当前章节新增的背景设定输出即可
  final String background;

  /// 本章内容总结
  final String summery;

  /// 人物之间的关系
  final List<AICompanionRelation> relations;

  const AICompanionResponse({
    required this.roles,
    required this.background,
    required this.summery,
    required this.relations,
  });

  /// 从Dify返回的outputs解析
  ///
  /// Dify返回格式：
  /// ```json
  /// {
  ///   "data": {
  ///     "outputs": {
  ///       "content": {
  ///         "roles": [...],
  ///         "background": "...",
  ///         "summery": "...",
  ///         "relations": [...]
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  factory AICompanionResponse.fromOutputs(Map<String, dynamic> outputs) {
    // 获取content字段
    final content = outputs['content'];

    if (content == null) {
      throw Exception('返回数据缺少content字段');
    }

    if (content is! Map<String, dynamic>) {
      throw Exception('content字段类型错误，期望Map<String, dynamic>');
    }

    // 解析roles数组
    final List<dynamic> rolesData = content['roles'] ?? [];
    final List<AICompanionRole> roles = rolesData
        .map((e) => AICompanionRole.fromJson(e as Map<String, dynamic>))
        .toList();

    // 解析background字段
    final String background = content['background']?.toString() ?? '';

    // 解析summery字段
    final String summery = content['summery']?.toString() ?? '';

    // 解析relations数组
    final List<dynamic> relationsData = content['relations'] ?? [];
    final List<AICompanionRelation> relations = relationsData
        .map((e) => AICompanionRelation.fromJson(e as Map<String, dynamic>))
        .toList();

    return AICompanionResponse(
      roles: roles,
      background: background,
      summery: summery,
      relations: relations,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'roles': roles.map((e) => e.toJson()).toList(),
      'background': background,
      'summery': summery,
      'relations': relations.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'AICompanionResponse(roles: ${roles.length}, background: ${background.length > 50 ? background.substring(0, 50) : background}, summery: ${summery.length > 50 ? summery.substring(0, 50) : summery}, relations: ${relations.length})';
  }
}
