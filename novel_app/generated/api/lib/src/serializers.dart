//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:novel_api/src/date_serializer.dart';
import 'package:novel_api/src/model/date.dart';

import 'package:novel_api/src/model/chapter.dart';
import 'package:novel_api/src/model/chapter_content.dart';
import 'package:novel_api/src/model/enhanced_scene_illustration_request.dart';
import 'package:novel_api/src/model/http_validation_error.dart';
import 'package:novel_api/src/model/image_to_video_request.dart';
import 'package:novel_api/src/model/image_to_video_response.dart';
import 'package:novel_api/src/model/image_to_video_task_status_response.dart';
import 'package:novel_api/src/model/novel.dart';
import 'package:novel_api/src/model/role_card_generate_request.dart';
import 'package:novel_api/src/model/role_card_task_status_response.dart';
import 'package:novel_api/src/model/role_gallery_response.dart';
import 'package:novel_api/src/model/role_image_delete_request.dart';
import 'package:novel_api/src/model/role_info.dart';
import 'package:novel_api/src/model/role_regenerate_request.dart';
import 'package:novel_api/src/model/scene_gallery_response.dart';
import 'package:novel_api/src/model/scene_image_delete_request.dart';
import 'package:novel_api/src/model/scene_regenerate_request.dart';
import 'package:novel_api/src/model/source_site.dart';
import 'package:novel_api/src/model/validation_error.dart';
import 'package:novel_api/src/model/validation_error_loc_inner.dart';
import 'package:novel_api/src/model/video_status_response.dart';

part 'serializers.g.dart';

@SerializersFor([
  Chapter,
  ChapterContent,
  EnhancedSceneIllustrationRequest,
  HTTPValidationError,
  ImageToVideoRequest,
  ImageToVideoResponse,
  ImageToVideoTaskStatusResponse,
  Novel,
  RoleCardGenerateRequest,
  RoleCardTaskStatusResponse,
  RoleGalleryResponse,
  RoleImageDeleteRequest,
  RoleInfo,
  RoleRegenerateRequest,
  SceneGalleryResponse,
  SceneImageDeleteRequest,
  SceneRegenerateRequest,
  SourceSite,
  ValidationError,
  ValidationErrorLocInner,
  VideoStatusResponse,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType(String)]),
        () => MapBuilder<String, String>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(SourceSite)]),
        () => ListBuilder<SourceSite>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Chapter)]),
        () => ListBuilder<Chapter>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Novel)]),
        () => ListBuilder<Novel>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType(JsonObject)]),
        () => MapBuilder<String, JsonObject>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
