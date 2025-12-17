//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'scene_gallery_response.g.dart';

/// 场面图片列表响应模式.
///
/// Properties:
/// * [taskId] - 场面绘制任务ID
/// * [images] - 图片文件名列表
@BuiltValue()
abstract class SceneGalleryResponse implements Built<SceneGalleryResponse, SceneGalleryResponseBuilder> {
  /// 场面绘制任务ID
  @BuiltValueField(wireName: r'task_id')
  String get taskId;

  /// 图片文件名列表
  @BuiltValueField(wireName: r'images')
  BuiltList<String> get images;

  SceneGalleryResponse._();

  factory SceneGalleryResponse([void updates(SceneGalleryResponseBuilder b)]) = _$SceneGalleryResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SceneGalleryResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SceneGalleryResponse> get serializer => _$SceneGalleryResponseSerializer();
}

class _$SceneGalleryResponseSerializer implements PrimitiveSerializer<SceneGalleryResponse> {
  @override
  final Iterable<Type> types = const [SceneGalleryResponse, _$SceneGalleryResponse];

  @override
  final String wireName = r'SceneGalleryResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SceneGalleryResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'task_id';
    yield serializers.serialize(
      object.taskId,
      specifiedType: const FullType(String),
    );
    yield r'images';
    yield serializers.serialize(
      object.images,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SceneGalleryResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SceneGalleryResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'task_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.taskId = valueDes;
          break;
        case r'images':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.images.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SceneGalleryResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SceneGalleryResponseBuilder();
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

