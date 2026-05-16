//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'chapter_sync_data.g.dart';

/// 章节同步数据模式.
///
/// Properties:
/// * [title] - 章节标题
/// * [content] - 章节内容
/// * [chapterIndex] - 章节序号
/// * [isUserInserted] - 是否为用户插入章节
/// * [url] 
@BuiltValue()
abstract class ChapterSyncData implements Built<ChapterSyncData, ChapterSyncDataBuilder> {
  /// 章节标题
  @BuiltValueField(wireName: r'title')
  String get title;

  /// 章节内容
  @BuiltValueField(wireName: r'content')
  String get content;

  /// 章节序号
  @BuiltValueField(wireName: r'chapter_index')
  int get chapterIndex;

  /// 是否为用户插入章节
  @BuiltValueField(wireName: r'is_user_inserted')
  bool? get isUserInserted;

  @BuiltValueField(wireName: r'url')
  String? get url;

  ChapterSyncData._();

  factory ChapterSyncData([void updates(ChapterSyncDataBuilder b)]) = _$ChapterSyncData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ChapterSyncDataBuilder b) => b
      ..isUserInserted = false;

  @BuiltValueSerializer(custom: true)
  static Serializer<ChapterSyncData> get serializer => _$ChapterSyncDataSerializer();
}

class _$ChapterSyncDataSerializer implements PrimitiveSerializer<ChapterSyncData> {
  @override
  final Iterable<Type> types = const [ChapterSyncData, _$ChapterSyncData];

  @override
  final String wireName = r'ChapterSyncData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ChapterSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'title';
    yield serializers.serialize(
      object.title,
      specifiedType: const FullType(String),
    );
    yield r'content';
    yield serializers.serialize(
      object.content,
      specifiedType: const FullType(String),
    );
    yield r'chapter_index';
    yield serializers.serialize(
      object.chapterIndex,
      specifiedType: const FullType(int),
    );
    if (object.isUserInserted != null) {
      yield r'is_user_inserted';
      yield serializers.serialize(
        object.isUserInserted,
        specifiedType: const FullType(bool),
      );
    }
    if (object.url != null) {
      yield r'url';
      yield serializers.serialize(
        object.url,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ChapterSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ChapterSyncDataBuilder result,
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
        case r'content':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.content = valueDes;
          break;
        case r'chapter_index':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.chapterIndex = valueDes;
          break;
        case r'is_user_inserted':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isUserInserted = valueDes;
          break;
        case r'url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.url = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ChapterSyncData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ChapterSyncDataBuilder();
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

