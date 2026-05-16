//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:novel_api/src/model/character_sync_data.dart';
import 'package:built_collection/built_collection.dart';
import 'package:novel_api/src/model/outline_sync_data.dart';
import 'package:novel_api/src/model/chapter_sync_data.dart';
import 'package:novel_api/src/model/character_relation_sync_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'novel_sync_data.g.dart';

/// 小说同步数据模式 - 仅保留创作编辑相关字段.
///
/// Properties:
/// * [title] - 小说标题
/// * [author] 
/// * [description] 
/// * [coverUrl] 
/// * [backgroundSetting] 
/// * [chapters] - 章节列表
/// * [characters] - 角色列表
/// * [characterRelations] - 角色关系列表
/// * [outlines] - 大纲列表
@BuiltValue()
abstract class NovelSyncData implements Built<NovelSyncData, NovelSyncDataBuilder> {
  /// 小说标题
  @BuiltValueField(wireName: r'title')
  String get title;

  @BuiltValueField(wireName: r'author')
  String? get author;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'cover_url')
  String? get coverUrl;

  @BuiltValueField(wireName: r'background_setting')
  String? get backgroundSetting;

  /// 章节列表
  @BuiltValueField(wireName: r'chapters')
  BuiltList<ChapterSyncData>? get chapters;

  /// 角色列表
  @BuiltValueField(wireName: r'characters')
  BuiltList<CharacterSyncData>? get characters;

  /// 角色关系列表
  @BuiltValueField(wireName: r'character_relations')
  BuiltList<CharacterRelationSyncData>? get characterRelations;

  /// 大纲列表
  @BuiltValueField(wireName: r'outlines')
  BuiltList<OutlineSyncData>? get outlines;

  NovelSyncData._();

  factory NovelSyncData([void updates(NovelSyncDataBuilder b)]) = _$NovelSyncData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NovelSyncDataBuilder b) => b
      ..chapters = ListBuilder()
      ..characters = ListBuilder()
      ..characterRelations = ListBuilder()
      ..outlines = ListBuilder();

  @BuiltValueSerializer(custom: true)
  static Serializer<NovelSyncData> get serializer => _$NovelSyncDataSerializer();
}

class _$NovelSyncDataSerializer implements PrimitiveSerializer<NovelSyncData> {
  @override
  final Iterable<Type> types = const [NovelSyncData, _$NovelSyncData];

  @override
  final String wireName = r'NovelSyncData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    NovelSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'title';
    yield serializers.serialize(
      object.title,
      specifiedType: const FullType(String),
    );
    if (object.author != null) {
      yield r'author';
      yield serializers.serialize(
        object.author,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.description != null) {
      yield r'description';
      yield serializers.serialize(
        object.description,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.coverUrl != null) {
      yield r'cover_url';
      yield serializers.serialize(
        object.coverUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.backgroundSetting != null) {
      yield r'background_setting';
      yield serializers.serialize(
        object.backgroundSetting,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.chapters != null) {
      yield r'chapters';
      yield serializers.serialize(
        object.chapters,
        specifiedType: const FullType(BuiltList, [FullType(ChapterSyncData)]),
      );
    }
    if (object.characters != null) {
      yield r'characters';
      yield serializers.serialize(
        object.characters,
        specifiedType: const FullType(BuiltList, [FullType(CharacterSyncData)]),
      );
    }
    if (object.characterRelations != null) {
      yield r'character_relations';
      yield serializers.serialize(
        object.characterRelations,
        specifiedType: const FullType(BuiltList, [FullType(CharacterRelationSyncData)]),
      );
    }
    if (object.outlines != null) {
      yield r'outlines';
      yield serializers.serialize(
        object.outlines,
        specifiedType: const FullType(BuiltList, [FullType(OutlineSyncData)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    NovelSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NovelSyncDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'title':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.title = valueDes;
          break;
        case r'author':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.author = valueDes;
          break;
        case r'description':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.description = valueDes;
          break;
        case r'cover_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.coverUrl = valueDes;
          break;
        case r'background_setting':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.backgroundSetting = valueDes;
          break;
        case r'chapters':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ChapterSyncData)]),
          ) as BuiltList<ChapterSyncData>;
          result.chapters.replace(valueDes);
          break;
        case r'characters':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(CharacterSyncData)]),
          ) as BuiltList<CharacterSyncData>;
          result.characters.replace(valueDes);
          break;
        case r'character_relations':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(CharacterRelationSyncData)]),
          ) as BuiltList<CharacterRelationSyncData>;
          result.characterRelations.replace(valueDes);
          break;
        case r'outlines':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(OutlineSyncData)]),
          ) as BuiltList<OutlineSyncData>;
          result.outlines.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  NovelSyncData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NovelSyncDataBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

