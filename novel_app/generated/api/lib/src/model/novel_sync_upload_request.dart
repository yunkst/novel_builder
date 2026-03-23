//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:novel_api/src/model/novel_sync_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'novel_sync_upload_request.g.dart';

/// 小说同步上传请求模式.
///
/// Properties:
/// * [deviceId] - 设备标识
/// * [novelData] - 小说数据
/// * [forceOverwrite] - 是否强制覆盖服务器数据
@BuiltValue()
abstract class NovelSyncUploadRequest implements Built<NovelSyncUploadRequest, NovelSyncUploadRequestBuilder> {
  /// 设备标识
  @BuiltValueField(wireName: r'device_id')
  String get deviceId;

  /// 小说数据
  @BuiltValueField(wireName: r'novel_data')
  NovelSyncData get novelData;

  /// 是否强制覆盖服务器数据
  @BuiltValueField(wireName: r'force_overwrite')
  bool? get forceOverwrite;

  NovelSyncUploadRequest._();

  factory NovelSyncUploadRequest([void updates(NovelSyncUploadRequestBuilder b)]) = _$NovelSyncUploadRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NovelSyncUploadRequestBuilder b) => b
      ..forceOverwrite = false;

  @BuiltValueSerializer(custom: true)
  static Serializer<NovelSyncUploadRequest> get serializer => _$NovelSyncUploadRequestSerializer();
}

class _$NovelSyncUploadRequestSerializer implements PrimitiveSerializer<NovelSyncUploadRequest> {
  @override
  final Iterable<Type> types = const [NovelSyncUploadRequest, _$NovelSyncUploadRequest];

  @override
  final String wireName = r'NovelSyncUploadRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    NovelSyncUploadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device_id';
    yield serializers.serialize(
      object.deviceId,
      specifiedType: const FullType(String),
    );
    yield r'novel_data';
    yield serializers.serialize(
      object.novelData,
      specifiedType: const FullType(NovelSyncData),
    );
    if (object.forceOverwrite != null) {
      yield r'force_overwrite';
      yield serializers.serialize(
        object.forceOverwrite,
        specifiedType: const FullType(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    NovelSyncUploadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NovelSyncUploadRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'device_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.deviceId = valueDes;
          break;
        case r'novel_data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(NovelSyncData),
          ) as NovelSyncData;
          result.novelData.replace(valueDes);
          break;
        case r'force_overwrite':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.forceOverwrite = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  NovelSyncUploadRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NovelSyncUploadRequestBuilder();
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

