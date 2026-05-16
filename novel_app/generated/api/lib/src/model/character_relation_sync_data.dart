//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'character_relation_sync_data.g.dart';

/// 角色关系同步数据模式 - 使用角色名称而非ID.
///
/// Properties:
/// * [character1] - 角色1名称
/// * [character2] - 角色2名称
/// * [relationType] - 关系类型
/// * [description] 
@BuiltValue()
abstract class CharacterRelationSyncData implements Built<CharacterRelationSyncData, CharacterRelationSyncDataBuilder> {
  /// 角色1名称
  @BuiltValueField(wireName: r'character1')
  String get character1;

  /// 角色2名称
  @BuiltValueField(wireName: r'character2')
  String get character2;

  /// 关系类型
  @BuiltValueField(wireName: r'relation_type')
  String get relationType;

  @BuiltValueField(wireName: r'description')
  String? get description;

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
    yield r'character1';
    yield serializers.serialize(
      object.character1,
      specifiedType: const FullType(String),
    );
    yield r'character2';
    yield serializers.serialize(
      object.character2,
      specifiedType: const FullType(String),
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
        case r'character1':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.character1 = valueDes;
          break;
        case r'character2':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.character2 = valueDes;
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

