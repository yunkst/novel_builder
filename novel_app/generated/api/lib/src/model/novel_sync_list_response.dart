//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:novel_api/src/model/novel_sync_data.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'novel_sync_list_response.g.dart';

/// 小说同步列表响应模式.
///
/// Properties:
/// * [success] - 是否成功
/// * [message] - 响应消息
/// * [novels] - 小说列表
/// * [totalCount] - 总数
/// * [page] - 当前页码
/// * [pageSize] - 每页数量
@BuiltValue()
abstract class NovelSyncListResponse implements Built<NovelSyncListResponse, NovelSyncListResponseBuilder> {
  /// 是否成功
  @BuiltValueField(wireName: r'success')
  bool get success;

  /// 响应消息
  @BuiltValueField(wireName: r'message')
  String get message;

  /// 小说列表
  @BuiltValueField(wireName: r'novels')
  BuiltList<NovelSyncData>? get novels;

  /// 总数
  @BuiltValueField(wireName: r'total_count')
  int get totalCount;

  /// 当前页码
  @BuiltValueField(wireName: r'page')
  int? get page;

  /// 每页数量
  @BuiltValueField(wireName: r'page_size')
  int? get pageSize;

  NovelSyncListResponse._();

  factory NovelSyncListResponse([void updates(NovelSyncListResponseBuilder b)]) = _$NovelSyncListResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(NovelSyncListResponseBuilder b) => b
      ..novels = ListBuilder()
      ..page = 1
      ..pageSize = 20;

  @BuiltValueSerializer(custom: true)
  static Serializer<NovelSyncListResponse> get serializer => _$NovelSyncListResponseSerializer();
}

class _$NovelSyncListResponseSerializer implements PrimitiveSerializer<NovelSyncListResponse> {
  @override
  final Iterable<Type> types = const [NovelSyncListResponse, _$NovelSyncListResponse];

  @override
  final String wireName = r'NovelSyncListResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    NovelSyncListResponse object, {
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
    if (object.novels != null) {
      yield r'novels';
      yield serializers.serialize(
        object.novels,
        specifiedType: const FullType(BuiltList, [FullType(NovelSyncData)]),
      );
    }
    yield r'total_count';
    yield serializers.serialize(
      object.totalCount,
      specifiedType: const FullType(int),
    );
    if (object.page != null) {
      yield r'page';
      yield serializers.serialize(
        object.page,
        specifiedType: const FullType(int),
      );
    }
    if (object.pageSize != null) {
      yield r'page_size';
      yield serializers.serialize(
        object.pageSize,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    NovelSyncListResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required NovelSyncListResponseBuilder result,
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
        case r'novels':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(NovelSyncData)]),
          ) as BuiltList<NovelSyncData>;
          result.novels.replace(valueDes);
          break;
        case r'total_count':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalCount = valueDes;
          break;
        case r'page':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.page = valueDes;
          break;
        case r'page_size':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.pageSize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  NovelSyncListResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = NovelSyncListResponseBuilder();
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

