//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:novel_api/src/model/novel_sync_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'novel_sync_download_response.g.dart';

/// 小说同步下载响应模式.
///
/// Properties:
/// * [success] - 是否成功
/// * [message] - 响应消息
/// * [novelData] 
/// * [syncVersion] - 同步版本号
/// * [syncedAt] - 同步时间(ISO格式)
@BuiltValue()
abstract class NovelSyncDownloadResponse implements Built<NovelSyncDownloadResponse, NovelSyncDownloadResponseBuilder> {
  /// 是否成功
  @BuiltValueField(wireName: r'success')
  bool get success;

  /// 响应消息
  @BuiltValueField(wireName: r'message')
  String get message;

  @BuiltValueField(wireName: r'novel_data')
  NovelSyncData? get novelData;

  /// 同步版本号
  @BuiltValueField(wireName: r'sync_version')
  int get syncVersion;

  /// 同步时间(ISO格式)
  @BuiltValueField(wireName: r'synced_at')
  String get syncedAt;

  NovelSyncDownloadResponse._();

  factory NovelSyncDownloadResponse([void updates(NovelSyncDownloadResponseBuilder b)]) = _$NovelSyncDownloadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NovelSyncDownloadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<NovelSyncDownloadResponse> get serializer => _$NovelSyncDownloadResponseSerializer();
}

class _$NovelSyncDownloadResponseSerializer implements PrimitiveSerializer<NovelSyncDownloadResponse> {
  @override
  final Iterable<Type> types = const [NovelSyncDownloadResponse, _$NovelSyncDownloadResponse];

  @override
  final String wireName = r'NovelSyncDownloadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    NovelSyncDownloadResponse object, {
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
    if (object.novelData != null) {
      yield r'novel_data';
      yield serializers.serialize(
        object.novelData,
        specifiedType: const FullType.nullable(NovelSyncData),
      );
    }
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
    NovelSyncDownloadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NovelSyncDownloadResponseBuilder result,
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
        case r'novel_data':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(NovelSyncData),
          ) as NovelSyncData?;
          if (valueDes == null) continue;
          result.novelData.replace(valueDes);
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
  NovelSyncDownloadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NovelSyncDownloadResponseBuilder();
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

