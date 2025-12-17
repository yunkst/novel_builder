import 'package:json_annotation/json_annotation.dart';
import 'dart:math';

part 'scene_illustration.g.dart';

@JsonSerializable()
class SceneIllustration {
  final int id;
  @JsonKey(name: 'novel_url')
  final String novelUrl;
  @JsonKey(name: 'chapter_id')
  final String chapterId;
  @JsonKey(name: 'task_id')
  final String taskId; // 添加 taskId 字段到数据库
  final String content;
  final String roles;
  @JsonKey(name: 'image_count')
  final int imageCount;
  final String status;
  final List<String> images;
  final String? prompts;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;

  SceneIllustration({
    required this.id,
    required this.novelUrl,
    required this.chapterId,
    required this.taskId,
    required this.content,
    required this.roles,
    required this.imageCount,
    required this.status,
    required this.images,
    this.prompts,
    required this.createdAt,
    this.completedAt,
  });

  // 从数据库Map创建实例
  factory SceneIllustration.fromMap(Map<String, dynamic> map) {
    return SceneIllustration(
      id: map['id'] as int,
      novelUrl: map['novel_url'] as String,
      chapterId: map['chapter_id'] as String,
      taskId: map['task_id'] as String,
      content: map['content'] as String,
      roles: map['roles'] as String,
      imageCount: map['image_count'] as int,
      status: map['status'] as String,
      images: map['images'] != null ? List<String>.from(map['images'].split(',')) : [],
      prompts: map['prompts'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
    );
  }

  // 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      // 'id': id, // SQLite AUTOINCREMENT 字段不需要显式设置
      'novel_url': novelUrl,
      'chapter_id': chapterId,
      'task_id': taskId, // 添加 taskId 字段
      'content': content,
      'roles': roles,
      'image_count': imageCount,
      'status': status,
      'images': images.join(','),
      'prompts': prompts,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  // 生成唯一任务ID（静态方法，在创建前调用）
  static String generateTaskId() {
    return '${Random().nextInt(0xFFFFFFFF)}-${Random().nextInt(0xFFFF)}';
  }

  // 是否已完成
  bool get isCompleted => status == 'completed';

  // 是否正在处理
  bool get isProcessing => status == 'processing' || status == 'pending';

  // 是否失败
  bool get isFailed => status == 'failed';

  // 获取主要图片（第一张）
  String? get primaryImage => images.isNotEmpty ? images.first : null;

  // 复制并更新状态
  SceneIllustration copyWith({
    int? id,
    String? novelUrl,
    String? chapterId,
    String? taskId,
    String? content,
    String? roles,
    int? imageCount,
    String? status,
    List<String>? images,
    String? prompts,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return SceneIllustration(
      id: id ?? this.id,
      novelUrl: novelUrl ?? this.novelUrl,
      chapterId: chapterId ?? this.chapterId,
      taskId: taskId ?? this.taskId,
      content: content ?? this.content,
      roles: roles ?? this.roles,
      imageCount: imageCount ?? this.imageCount,
      status: status ?? this.status,
      images: images ?? this.images,
      prompts: prompts ?? this.prompts,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory SceneIllustration.fromJson(Map<String, dynamic> json) => _$SceneIllustrationFromJson(json);
  Map<String, dynamic> toJson() => _$SceneIllustrationToJson(this);
}