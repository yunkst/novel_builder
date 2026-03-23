//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'outline_sync_data.g.dart';

/// 大纲同步数据模式.
///
/// Properties:
/// * [outlineId] - 大纲ID
/// * [title] - 大纲标题
/// * [content] - 大纲内容
/// * [outlineType] - 大纲类型(如: main, volume, chapter)
/// * [parentId] 
/// * [sortOrder] - 排序顺序
/// * [createdAt] 
/// * [updatedAt] 
@BuiltValue()
abstract class OutlineSyncData implements Built<OutlineSyncData, OutlineSyncDataBuilder> {
  /// 大纲ID
  @BuiltValueField(wireName: r'outline_id')
  int get outlineId;

  /// 大纲标题
  @BuiltValueField(wireName: r'title')
  String get title;

  /// 大纲内容
  @BuiltValueField(wireName: r'content')
  String get content;

  /// 大纲类型(如: main, volume, chapter)
  @BuiltValueField(wireName: r'outline_type')
  String get outlineType;

  @BuiltValueField(wireName: r'parent_id')
  int? get parentId;

  /// 排序顺序
  @BuiltValueField(wireName: r'sort_order')
  int? get sortOrder;

  @BuiltValueField(wireName: r'created_at')
  String? get createdAt;

  @BuiltValueField(wireName: r'updated_at')
  String? get updatedAt;

  OutlineSyncData._();

  factory OutlineSyncData([void updates(OutlineSyncDataBuilder b)]) = _$OutlineSyncData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OutlineSyncDataBuilder b) => b
      ..sortOrder = 0;

  @BuiltValueSerializer(custom: true)
  static Serializer<OutlineSyncData> get serializer => _$OutlineSyncDataSerializer();
}

class _$OutlineSyncDataSerializer implements PrimitiveSerializer<OutlineSyncData> {
  @override
  final Iterable<Type> types = const [OutlineSyncData, _$OutlineSyncData];

  @override
  final String wireName = r'OutlineSyncData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    OutlineSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'outline_id';
    yield serializers.serialize(
      object.outlineId,
      specifiedType: const FullType(int),
    );
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
    yield r'outline_type';
    yield serializers.serialize(
      object.outlineType,
      specifiedType: const FullType(String),
    );
    if (object.parentId != null) {
      yield r'parent_id';
      yield serializers.serialize(
        object.parentId,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.sortOrder != null) {
      yield r'sort_order';
      yield serializers.serialize(
        object.sortOrder,
        specifiedType: const FullType(int),
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
  }

  @override
  Object serialize(
    Serializers serializers,
    OutlineSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required OutlineSyncDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'outline_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.outlineId = valueDes;
          break;
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
        case r'outline_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.outlineType = valueDes;
          break;
        case r'parent_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.parentId = valueDes;
          break;
        case r'sort_order':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.sortOrder = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  OutlineSyncData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OutlineSyncDataBuilder();
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

