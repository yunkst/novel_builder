//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'novel_sync_download_request.g.dart';

/// 小说同步下载请求模式.
///
/// Properties:
/// * [deviceId] - 设备标识
/// * [sourceUrl] - 小说来源URL（作为唯一标识）
/// * [includeChapters] - 是否包含章节内容
/// * [includeCharacters] - 是否包含角色数据
/// * [includeOutlines] - 是否包含大纲数据
@BuiltValue()
abstract class NovelSyncDownloadRequest implements Built<NovelSyncDownloadRequest, NovelSyncDownloadRequestBuilder> {
  /// 设备标识
  @BuiltValueField(wireName: r'device_id')
  String get deviceId;

  /// 小说来源URL（作为唯一标识）
  @BuiltValueField(wireName: r'source_url')
  String get sourceUrl;

  /// 是否包含章节内容
  @BuiltValueField(wireName: r'include_chapters')
  bool? get includeChapters;

  /// 是否包含角色数据
  @BuiltValueField(wireName: r'include_characters')
  bool? get includeCharacters;

  /// 是否包含大纲数据
  @BuiltValueField(wireName: r'include_outlines')
  bool? get includeOutlines;

  NovelSyncDownloadRequest._();

  factory NovelSyncDownloadRequest([void updates(NovelSyncDownloadRequestBuilder b)]) = _$NovelSyncDownloadRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NovelSyncDownloadRequestBuilder b) => b
      ..includeChapters = true
      ..includeCharacters = true
      ..includeOutlines = true;

  @BuiltValueSerializer(custom: true)
  static Serializer<NovelSyncDownloadRequest> get serializer => _$NovelSyncDownloadRequestSerializer();
}

class _$NovelSyncDownloadRequestSerializer implements PrimitiveSerializer<NovelSyncDownloadRequest> {
  @override
  final Iterable<Type> types = const [NovelSyncDownloadRequest, _$NovelSyncDownloadRequest];

  @override
  final String wireName = r'NovelSyncDownloadRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    NovelSyncDownloadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device_id';
    yield serializers.serialize(
      object.deviceId,
      specifiedType: const FullType(String),
    );
    yield r'source_url';
    yield serializers.serialize(
      object.sourceUrl,
      specifiedType: const FullType(String),
    );
    if (object.includeChapters != null) {
      yield r'include_chapters';
      yield serializers.serialize(
        object.includeChapters,
        specifiedType: const FullType(bool),
      );
    }
    if (object.includeCharacters != null) {
      yield r'include_characters';
      yield serializers.serialize(
        object.includeCharacters,
        specifiedType: const FullType(bool),
      );
    }
    if (object.includeOutlines != null) {
      yield r'include_outlines';
      yield serializers.serialize(
        object.includeOutlines,
        specifiedType: const FullType(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    NovelSyncDownloadRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NovelSyncDownloadRequestBuilder result,
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
        case r'source_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.sourceUrl = valueDes;
          break;
        case r'include_chapters':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.includeChapters = valueDes;
          break;
        case r'include_characters':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.includeCharacters = valueDes;
          break;
        case r'include_outlines':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.includeOutlines = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  NovelSyncDownloadRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NovelSyncDownloadRequestBuilder();
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

