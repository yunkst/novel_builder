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
/// * [title] - 大纲标题
/// * [content] - 大纲内容
@BuiltValue()
abstract class OutlineSyncData implements Built<OutlineSyncData, OutlineSyncDataBuilder> {
  /// 大纲标题
  @BuiltValueField(wireName: r'title')
  String get title;

  /// 大纲内容
  @BuiltValueField(wireName: r'content')
  String get content;

  OutlineSyncData._();

  factory OutlineSyncData([void updates(OutlineSyncDataBuilder b)]) = _$OutlineSyncData;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OutlineSyncDataBuilder b) => b;

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

