//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'character_relation_sync_data.g.dart';

/// 角色关系同步数据模式.
///
/// Properties:
/// * [relationId] - 关系ID
/// * [character1Id] - 角色1的ID
/// * [character2Id] - 角色2的ID
/// * [relationType] - 关系类型
/// * [description] 
/// * [createdAt] 
/// * [updatedAt] 
@BuiltValue()
abstract class CharacterRelationSyncData implements Built<CharacterRelationSyncData, CharacterRelationSyncDataBuilder> {
  /// 关系ID
  @BuiltValueField(wireName: r'relation_id')
  int get relationId;

  /// 角色1的ID
  @BuiltValueField(wireName: r'character1_id')
  int get character1Id;

  /// 角色2的ID
  @BuiltValueField(wireName: r'character2_id')
  int get character2Id;

  /// 关系类型
  @BuiltValueField(wireName: r'relation_type')
  String get relationType;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'created_at')
  String? get createdAt;

  @BuiltValueField(wireName: r'updated_at')
  String? get updatedAt;

  CharacterRelationSyncData._();

  factory CharacterRelationSyncData([void updates(CharacterRelationSyncDataBuilder b)]) = _$CharacterRelationSyncData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CharacterRelationSyncDataBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CharacterRelationSyncData> get serializer => _$CharacterRelationSyncDataSerializer();
}

class _$CharacterRelationSyncDataSerializer implements PrimitiveSerializer<CharacterRelationSyncData> {
  @override
  final Iterable<Type> types = const [CharacterRelationSyncData, _$CharacterRelationSyncData];

  @override
  final String wireName = r'CharacterRelationSyncData';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CharacterRelationSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'relation_id';
    yield serializers.serialize(
      object.relationId,
      specifiedType: const FullType(int),
    );
    yield r'character1_id';
    yield serializers.serialize(
      object.character1Id,
      specifiedType: const FullType(int),
    );
    yield r'character2_id';
    yield serializers.serialize(
      object.character2Id,
      specifiedType: const FullType(int),
    );
    yield r'relation_type';
    yield serializers.serialize(
      object.relationType,
      specifiedType: const FullType(String),
    );
    if (object.description != null) {
      yield r'description';
      yield serializers.serialize(
        object.description,
        specifiedType: const FullType.nullable(String),
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
    CharacterRelationSyncData object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CharacterRelationSyncDataBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'relation_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.relationId = valueDes;
          break;
        case r'character1_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.character1Id = valueDes;
          break;
        case r'character2_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.character2Id = valueDes;
          break;
        case r'relation_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.relationType = valueDes;
          break;
        case r'description':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.description = valueDes;
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
  CharacterRelationSyncData deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CharacterRelationSyncDataBuilder();
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

