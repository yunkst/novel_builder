//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'novel_sync_delete_response.g.dart';

/// 小说同步删除响应模式.
///
/// Properties:
/// * [success] - 是否成功
/// * [message] - 响应消息
@BuiltValue()
abstract class NovelSyncDeleteResponse implements Built<NovelSyncDeleteResponse, NovelSyncDeleteResponseBuilder> {
  /// 是否成功
  @BuiltValueField(wireName: r'success')
  bool get success;

  /// 响应消息
  @BuiltValueField(wireName: r'message')
  String get message;

  NovelSyncDeleteResponse._();

  factory NovelSyncDeleteResponse([void updates(NovelSyncDeleteResponseBuilder b)]) = _$NovelSyncDeleteResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NovelSyncDeleteResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<NovelSyncDeleteResponse> get serializer => _$NovelSyncDeleteResponseSerializer();
}

class _$NovelSyncDeleteResponseSerializer implements PrimitiveSerializer<NovelSyncDeleteResponse> {
  @override
  final Iterable<Type> types = const [NovelSyncDeleteResponse, _$NovelSyncDeleteResponse];

  @override
  final String wireName = r'NovelSyncDeleteResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    NovelSyncDeleteResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'success';
    yield serializers.serialize(
      object.success,
      specifiedType: const FullType(bool),
    );
    yield r'message';
    yield serializers.serialize(
      object.message,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    NovelSyncDeleteResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NovelSyncDeleteResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'success':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.success = valueDes;
          break;
        case r'message':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.message = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  NovelSyncDeleteResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NovelSyncDeleteResponseBuilder();
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

