import '../models/chapter.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../models/outline.dart';

/// 章节导出数据模型
///
/// 用于JSON序列化，包含章节的所有必要信息
class ChapterExportData {
  final String title;
  final String url;
  final String? content;
  final int? chapterIndex;
  final bool isUserInserted;
  final int? readAt;

  const ChapterExportData({
    required this.title,
    required this.url,
    this.content,
    this.chapterIndex,
    this.isUserInserted = false,
    this.readAt,
  });

  /// 从Chapter模型创建
  factory ChapterExportData.fromChapter(Chapter chapter) {
    return ChapterExportData(
      title: chapter.title,
      url: chapter.url,
      content: chapter.content,
      chapterIndex: chapter.chapterIndex,
      isUserInserted: chapter.isUserInserted,
      readAt: chapter.readAt,
    );
  }

  /// 转换为Chapter模型
  Chapter toChapter() {
    return Chapter(
      title: title,
      url: url,
      content: content,
      isCached: content != null && content!.isNotEmpty,
      chapterIndex: chapterIndex,
      isUserInserted: isUserInserted,
      readAt: readAt,
    );
  }

  /// 转换为JSON Map
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'content': content,
      'chapterIndex': chapterIndex,
      'isUserInserted': isUserInserted,
      'readAt': readAt,
    };
  }

  /// 从JSON Map创建
  factory ChapterExportData.fromJson(Map<String, dynamic> json) {
    return ChapterExportData(
      title: json['title'] as String,
      url: json['url'] as String,
      content: json['content'] as String?,
      chapterIndex: json['chapterIndex'] as int?,
      isUserInserted: json['isUserInserted'] as bool? ?? false,
      readAt: json['readAt'] as int?,
    );
  }
}

/// 角色导出数据模型
///
/// 用于JSON序列化，包含角色的所有必要信息
class CharacterExportData {
  final String name;
  final int? age;
  final String? gender;
  final String? occupation;
  final String? personality;
  final String? bodyType;
  final String? clothingStyle;
  final String? appearanceFeatures;
  final String? backgroundStory;
  final String? facePrompts;
  final String? bodyPrompts;
  final String? cachedImageUrl;
  final List<String>? aliases;
  final int? originalId;

  const CharacterExportData({
    required this.name,
    this.age,
    this.gender,
    this.occupation,
    this.personality,
    this.bodyType,
    this.clothingStyle,
    this.appearanceFeatures,
    this.backgroundStory,
    this.facePrompts,
    this.bodyPrompts,
    this.cachedImageUrl,
    this.aliases,
    this.originalId,
  });

  /// 从Character模型创建
  factory CharacterExportData.fromCharacter(Character character) {
    return CharacterExportData(
      name: character.name,
      age: character.age,
      gender: character.gender,
      occupation: character.occupation,
      personality: character.personality,
      bodyType: character.bodyType,
      clothingStyle: character.clothingStyle,
      appearanceFeatures: character.appearanceFeatures,
      backgroundStory: character.backgroundStory,
      facePrompts: character.facePrompts,
      bodyPrompts: character.bodyPrompts,
      cachedImageUrl: character.cachedImageUrl,
      aliases: character.aliases,
      originalId: character.id,
    );
  }

  /// 转换为Character模型
  Character toCharacter(String novelUrl) {
    return Character(
      novelUrl: novelUrl,
      name: name,
      age: age,
      gender: gender,
      occupation: occupation,
      personality: personality,
      bodyType: bodyType,
      clothingStyle: clothingStyle,
      appearanceFeatures: appearanceFeatures,
      backgroundStory: backgroundStory,
      facePrompts: facePrompts,
      bodyPrompts: bodyPrompts,
      cachedImageUrl: cachedImageUrl,
      aliases: aliases,
    );
  }

  /// 转换为JSON Map
  Map<String, dynamic> toJson() {
    return {
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
      'aliases': aliases,
      'originalId': originalId,
    };
  }

  /// 从JSON Map创建
  factory CharacterExportData.fromJson(Map<String, dynamic> json) {
    return CharacterExportData(
      name: json['name'] as String,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String?,
      personality: json['personality'] as String?,
      bodyType: json['bodyType'] as String?,
      clothingStyle: json['clothingStyle'] as String?,
      appearanceFeatures: json['appearanceFeatures'] as String?,
      backgroundStory: json['backgroundStory'] as String?,
      facePrompts: json['facePrompts'] as String?,
      bodyPrompts: json['bodyPrompts'] as String?,
      cachedImageUrl: json['cachedImageUrl'] as String?,
      aliases: (json['aliases'] as List<dynamic>?)?.cast<String>().toList(),
      originalId: json['originalId'] as int?,
    );
  }
}

/// 角色关系导出数据模型
///
/// 用于JSON序列化，使用角色名称而非ID，便于跨设备导入
class CharacterRelationExportData {
  final String sourceCharacterName;
  final String targetCharacterName;
  final String relationshipType;
  final String? description;

  const CharacterRelationExportData({
    required this.sourceCharacterName,
    required this.targetCharacterName,
    required this.relationshipType,
    this.description,
  });

  /// 从CharacterRelationship模型创建
  factory CharacterRelationExportData.fromRelationship(
    CharacterRelationship relationship, {
    required String sourceName,
    required String targetName,
  }) {
    return CharacterRelationExportData(
      sourceCharacterName: sourceName,
      targetCharacterName: targetName,
      relationshipType: relationship.relationshipType,
      description: relationship.description,
    );
  }

  /// 转换为JSON Map
  Map<String, dynamic> toJson() {
    return {
      'sourceCharacterName': sourceCharacterName,
      'targetCharacterName': targetCharacterName,
      'relationshipType': relationshipType,
      'description': description,
    };
  }

  /// 从JSON Map创建
  factory CharacterRelationExportData.fromJson(Map<String, dynamic> json) {
    return CharacterRelationExportData(
      sourceCharacterName: json['sourceCharacterName'] as String,
      targetCharacterName: json['targetCharacterName'] as String,
      relationshipType: json['relationshipType'] as String,
      description: json['description'] as String?,
    );
  }
}

/// 大纲导出数据模型
///
/// 用于JSON序列化，包含大纲的所有信息
class OutlineExportData {
  final String title;
  final String content;

  const OutlineExportData({
    required this.title,
    required this.content,
  });

  /// 从Outline模型创建
  factory OutlineExportData.fromOutline(Outline outline) {
    return OutlineExportData(
      title: outline.title,
      content: outline.content,
    );
  }

  /// 转换为Outline模型
  Outline toOutline(String novelUrl) {
    return Outline(
      novelUrl: novelUrl,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 转换为JSON Map
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
    };
  }

  /// 从JSON Map创建
  factory OutlineExportData.fromJson(Map<String, dynamic> json) {
    return OutlineExportData(
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }
}

/// 小说导出数据模型
///
/// 包含小说的所有关联数据：章节、角色、关系、大纲
class NovelExportData {
  final String novelUrl;
  final String title;
  final String author;
  final String? coverUrl;
  final String? description;
  final String? backgroundSetting;
  final List<ChapterExportData> chapters;
  final List<CharacterExportData> characters;
  final List<CharacterRelationExportData> relationships;
  final OutlineExportData? outline;
  final String exportVersion;
  final DateTime exportedAt;

  NovelExportData({
    required this.novelUrl,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description,
    this.backgroundSetting,
    this.chapters = const [],
    this.characters = const [],
    this.relationships = const [],
    this.outline,
    this.exportVersion = '1.0.0',
    DateTime? exportedAt,
  }) : exportedAt = exportedAt ?? DateTime.now();

  /// 转换为JSON Map
  Map<String, dynamic> toJson() {
    return {
      'novelUrl': novelUrl,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'description': description,
      'backgroundSetting': backgroundSetting,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'characters': characters.map((c) => c.toJson()).toList(),
      'relationships': relationships.map((r) => r.toJson()).toList(),
      'outline': outline?.toJson(),
      'exportVersion': exportVersion,
      'exportedAt': exportedAt.millisecondsSinceEpoch,
    };
  }

  /// 从JSON Map创建
  factory NovelExportData.fromJson(Map<String, dynamic> json) {
    return NovelExportData(
      novelUrl: json['novelUrl'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['coverUrl'] as String?,
      description: json['description'] as String?,
      backgroundSetting: json['backgroundSetting'] as String?,
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((c) => ChapterExportData.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      characters: (json['characters'] as List<dynamic>?)
              ?.map((c) => CharacterExportData.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      relationships: (json['relationships'] as List<dynamic>?)
              ?.map((r) => CharacterRelationExportData.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      outline: json['outline'] != null
          ? OutlineExportData.fromJson(json['outline'] as Map<String, dynamic>)
          : null,
      exportVersion: json['exportVersion'] as String? ?? '1.0.0',
      exportedAt: json['exportedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['exportedAt'] as int)
          : null,
    );
  }

}
