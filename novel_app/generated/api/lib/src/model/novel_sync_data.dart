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

/// 小说同步数据模式 - 包含完整的小说数据.
///
/// Properties:
/// * [novelId] - 小说ID
/// * [title] - 小说标题
/// * [author] 
/// * [description] 
/// * [coverUrl] 
/// * [sourceUrl] 
/// * [totalChapters] - 总章节数
/// * [totalWords] - 总字数
/// * [lastReadChapterId] 
/// * [lastReadPosition] - 最后阅读位置
/// * [isFavorite] - 是否收藏
/// * [createdAt] 
/// * [updatedAt] 
/// * [chapters] - 章节列表
/// * [characters] - 角色列表
/// * [characterRelations] - 角色关系列表
/// * [outlines] - 大纲列表
@BuiltValue()
abstract class NovelSyncData implements Built<NovelSyncData, NovelSyncDataBuilder> {
  /// 小说ID
  @BuiltValueField(wireName: r'novel_id')
  int get novelId;

  /// 小说标题
  @BuiltValueField(wireName: r'title')
  String get title;

  @BuiltValueField(wireName: r'author')
  String? get author;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'cover_url')
  String? get coverUrl;

  @BuiltValueField(wireName: r'source_url')
  String? get sourceUrl;

  /// 总章节数
  @BuiltValueField(wireName: r'total_chapters')
  int? get totalChapters;

  /// 总字数
  @BuiltValueField(wireName: r'total_words')
  int? get totalWords;

  @BuiltValueField(wireName: r'last_read_chapter_id')
  int? get lastReadChapterId;

  /// 最后阅读位置
  @BuiltValueField(wireName: r'last_read_position')
  int? get lastReadPosition;

  /// 是否收藏
  @BuiltValueField(wireName: r'is_favorite')
  bool? get isFavorite;

  @BuiltValueField(wireName: r'created_at')
  String? get createdAt;

  @BuiltValueField(wireName: r'updated_at')
  String? get updatedAt;

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
      ..totalChapters = 0
      ..totalWords = 0
      ..lastReadPosition = 0
      ..isFavorite = false
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
    yield r'novel_id';
    yield serializers.serialize(
      object.novelId,
      specifiedType: const FullType(int),
    );
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
    if (object.sourceUrl != null) {
      yield r'source_url';
      yield serializers.serialize(
        object.sourceUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.totalChapters != null) {
      yield r'total_chapters';
      yield serializers.serialize(
        object.totalChapters,
        specifiedType: const FullType(int),
      );
    }
    if (object.totalWords != null) {
      yield r'total_words';
      yield serializers.serialize(
        object.totalWords,
        specifiedType: const FullType(int),
      );
    }
    if (object.lastReadChapterId != null) {
      yield r'last_read_chapter_id';
      yield serializers.serialize(
        object.lastReadChapterId,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.lastReadPosition != null) {
      yield r'last_read_position';
      yield serializers.serialize(
        object.lastReadPosition,
        specifiedType: const FullType(int),
      );
    }
    if (object.isFavorite != null) {
      yield r'is_favorite';
      yield serializers.serialize(
        object.isFavorite,
        specifiedType: const FullType(bool),
      );
    }
    if (object.createdAt != null) {
      yield r'created_at';
      yield serializers.serialize(
        object.createdAt,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.updatedAt != null) {
      yield r'updated_at';
      yield serializers.serialize(
        object.updatedAt,
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
        case r'novel_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.novelId = valueDes;
          break;
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
        case r'source_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.sourceUrl = valueDes;
          break;
        case r'total_chapters':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalChapters = valueDes;
          break;
        case r'total_words':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalWords = valueDes;
          break;
        case r'last_read_chapter_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.lastReadChapterId = valueDes;
          break;
        case r'last_read_position':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.lastReadPosition = valueDes;
          break;
        case r'is_favorite':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isFavorite = valueDes;
          break;
        case r'created_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.createdAt = valueDes;
          break;
        case r'updated_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.updatedAt = valueDes;
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

