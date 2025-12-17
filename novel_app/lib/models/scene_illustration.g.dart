// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene_illustration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SceneIllustration _$SceneIllustrationFromJson(Map<String, dynamic> json) =>
    SceneIllustration(
      id: (json['id'] as num).toInt(),
      novelUrl: json['novel_url'] as String,
      chapterId: json['chapter_id'] as String,
      taskId: json['task_id'] as String,
      content: json['content'] as String,
      roles: json['roles'] as String,
      imageCount: (json['image_count'] as num).toInt(),
      status: json['status'] as String,
      images:
          (json['images'] as List<dynamic>).map((e) => e as String).toList(),
      prompts: json['prompts'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );

Map<String, dynamic> _$SceneIllustrationToJson(SceneIllustration instance) =>
    <String, dynamic>{
      'id': instance.id,
      'novel_url': instance.novelUrl,
      'chapter_id': instance.chapterId,
      'task_id': instance.taskId,
      'content': instance.content,
      'roles': instance.roles,
      'image_count': instance.imageCount,
      'status': instance.status,
      'images': instance.images,
      'prompts': instance.prompts,
      'created_at': instance.createdAt.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
    };
