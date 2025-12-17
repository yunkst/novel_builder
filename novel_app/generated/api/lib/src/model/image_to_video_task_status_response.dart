//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'image_to_video_task_status_response.g.dart';

/// 图生视频任务状态响应模式.
///
/// Properties:
/// * [taskId] - 任务ID
/// * [imgName] - 图片名称
/// * [status] - 任务状态: pending/running/completed/failed
/// * [modelName] 
/// * [userInput] - 用户要求
/// * [videoPrompt] 
/// * [videoFilename] 
/// * [resultMessage] 
/// * [errorMessage] 
/// * [createdAt] - 创建时间
/// * [startedAt] 
/// * [completedAt] 
@BuiltValue()
abstract class ImageToVideoTaskStatusResponse implements Built<ImageToVideoTaskStatusResponse, ImageToVideoTaskStatusResponseBuilder> {
  /// 任务ID
  @BuiltValueField(wireName: r'task_id')
  int get taskId;

  /// 图片名称
  @BuiltValueField(wireName: r'img_name')
  String get imgName;

  /// 任务状态: pending/running/completed/failed
  @BuiltValueField(wireName: r'status')
  String get status;

  @BuiltValueField(wireName: r'model_name')
  String? get modelName;

  /// 用户要求
  @BuiltValueField(wireName: r'user_input')
  String get userInput;

  @BuiltValueField(wireName: r'video_prompt')
  String? get videoPrompt;

  @BuiltValueField(wireName: r'video_filename')
  String? get videoFilename;

  @BuiltValueField(wireName: r'result_message')
  String? get resultMessage;

  @BuiltValueField(wireName: r'error_message')
  String? get errorMessage;

  /// 创建时间
  @BuiltValueField(wireName: r'created_at')
  String get createdAt;

  @BuiltValueField(wireName: r'started_at')
  String? get startedAt;

  @BuiltValueField(wireName: r'completed_at')
  String? get completedAt;

  ImageToVideoTaskStatusResponse._();

  factory ImageToVideoTaskStatusResponse([void updates(ImageToVideoTaskStatusResponseBuilder b)]) = _$ImageToVideoTaskStatusResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ImageToVideoTaskStatusResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ImageToVideoTaskStatusResponse> get serializer => _$ImageToVideoTaskStatusResponseSerializer();
}

class _$ImageToVideoTaskStatusResponseSerializer implements PrimitiveSerializer<ImageToVideoTaskStatusResponse> {
  @override
  final Iterable<Type> types = const [ImageToVideoTaskStatusResponse, _$ImageToVideoTaskStatusResponse];

  @override
  final String wireName = r'ImageToVideoTaskStatusResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ImageToVideoTaskStatusResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'task_id';
    yield serializers.serialize(
      object.taskId,
      specifiedType: const FullType(int),
    );
    yield r'img_name';
    yield serializers.serialize(
      object.imgName,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(String),
    );
    if (object.modelName != null) {
      yield r'model_name';
      yield serializers.serialize(
        object.modelName,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'user_input';
    yield serializers.serialize(
      object.userInput,
      specifiedType: const FullType(String),
    );
    if (object.videoPrompt != null) {
      yield r'video_prompt';
      yield serializers.serialize(
        object.videoPrompt,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.videoFilename != null) {
      yield r'video_filename';
      yield serializers.serialize(
        object.videoFilename,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.resultMessage != null) {
      yield r'result_message';
      yield serializers.serialize(
        object.resultMessage,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.errorMessage != null) {
      yield r'error_message';
      yield serializers.serialize(
        object.errorMessage,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'created_at';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(String),
    );
    if (object.startedAt != null) {
      yield r'started_at';
      yield serializers.serialize(
        object.startedAt,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.completedAt != null) {
      yield r'completed_at';
      yield serializers.serialize(
        object.completedAt,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ImageToVideoTaskStatusResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ImageToVideoTaskStatusResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'task_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.taskId = valueDes;
          break;
        case r'img_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.imgName = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        case r'model_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.modelName = valueDes;
          break;
        case r'user_input':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userInput = valueDes;
          break;
        case r'video_prompt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.videoPrompt = valueDes;
          break;
        case r'video_filename':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.videoFilename = valueDes;
          break;
        case r'result_message':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.resultMessage = valueDes;
          break;
        case r'error_message':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.errorMessage = valueDes;
          break;
        case r'created_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.createdAt = valueDes;
          break;
        case r'started_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.startedAt = valueDes;
          break;
        case r'completed_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.completedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ImageToVideoTaskStatusResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ImageToVideoTaskStatusResponseBuilder();
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

