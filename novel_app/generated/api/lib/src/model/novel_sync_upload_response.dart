//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'novel_sync_upload_response.g.dart';

/// 小说同步上传响应模式.
///
/// Properties:
/// * [success] - 是否成功
/// * [message] - 响应消息
/// * [novelId] - 小说ID
/// * [syncVersion] - 同步版本号
/// * [syncedAt] - 同步时间(ISO格式)
@BuiltValue()
abstract class NovelSyncUploadResponse implements Built<NovelSyncUploadResponse, NovelSyncUploadResponseBuilder> {
  /// 是否成功
  @BuiltValueField(wireName: r'success')
  bool get success;

  /// 响应消息
  @BuiltValueField(wireName: r'message')
  String get message;

  /// 小说ID
  @BuiltValueField(wireName: r'novel_id')
  int get novelId;

  /// 同步版本号
  @BuiltValueField(wireName: r'sync_version')
  int get syncVersion;

  /// 同步时间(ISO格式)
  @BuiltValueField(wireName: r'synced_at')
  String get syncedAt;

  NovelSyncUploadResponse._();

  factory NovelSyncUploadResponse([void updates(NovelSyncUploadResponseBuilder b)]) = _$NovelSyncUploadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NovelSyncUploadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<NovelSyncUploadResponse> get serializer => _$NovelSyncUploadResponseSerializer();
}

class _$NovelSyncUploadResponseSerializer implements PrimitiveSerializer<NovelSyncUploadResponse> {
  @override
  final Iterable<Type> types = const [NovelSyncUploadResponse, _$NovelSyncUploadResponse];

  @override
  final String wireName = r'NovelSyncUploadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    NovelSyncUploadResponse object, {
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
    yield r'novel_id';
    yield serializers.serialize(
      object.novelId,
      specifiedType: const FullType(int),
    );
    yield r'sync_version';
    yield serializers.serialize(
      object.syncVersion,
      specifiedType: const FullType(int),
    );
    yield r'synced_at';
    yield serializers.serialize(
      object.syncedAt,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    NovelSyncUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NovelSyncUploadResponseBuilder result,
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
        case r'novel_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.novelId = valueDes;
          break;
        case r'sync_version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.syncVersion = valueDes;
          break;
        case r'synced_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.syncedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  NovelSyncUploadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NovelSyncUploadResponseBuilder();
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

