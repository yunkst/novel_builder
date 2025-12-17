enum IllustrationStatus {
  pending,
  processing,
  completed,
  failed,
}

extension IllustrationStatusExtension on IllustrationStatus {
  String get value {
    switch (this) {
      case IllustrationStatus.pending:
        return 'pending';
      case IllustrationStatus.processing:
        return 'processing';
      case IllustrationStatus.completed:
        return 'completed';
      case IllustrationStatus.failed:
        return 'failed';
    }
  }

  static IllustrationStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return IllustrationStatus.pending;
      case 'processing':
        return IllustrationStatus.processing;
      case 'completed':
        return IllustrationStatus.completed;
      case 'failed':
        return IllustrationStatus.failed;
      default:
        return IllustrationStatus.pending;
    }
  }
}

class IllustrationDebugItem {
  final String id;
  final String prompt;
  final int imageCount;
  final DateTime requestTime;
  final DateTime? completedTime;
  final IllustrationStatus status;
  final List<String> imageUrls;
  final String? errorMessage;
  final String? taskId;

  IllustrationDebugItem({
    required this.id,
    required this.prompt,
    required this.imageCount,
    required this.requestTime,
    this.completedTime,
    required this.status,
    this.imageUrls = const [],
    this.errorMessage,
    this.taskId,
  });

  // 从JSON创建对象
  factory IllustrationDebugItem.fromJson(Map<String, dynamic> json) {
    return IllustrationDebugItem(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      imageCount: json['imageCount'] as int,
      requestTime: DateTime.parse(json['requestTime'] as String),
      completedTime: json['completedTime'] != null
          ? DateTime.parse(json['completedTime'] as String)
          : null,
      status: IllustrationStatusExtension.fromString(json['status'] as String),
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      errorMessage: json['errorMessage'] as String?,
      taskId: json['taskId'] as String?,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'imageCount': imageCount,
      'requestTime': requestTime.toIso8601String(),
      'completedTime': completedTime?.toIso8601String(),
      'status': status.value,
      'imageUrls': imageUrls,
      'errorMessage': errorMessage,
      'taskId': taskId,
    };
  }

  // 转换为Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prompt': prompt,
      'image_count': imageCount,
      'request_time': requestTime.millisecondsSinceEpoch,
      'completed_time': completedTime?.millisecondsSinceEpoch,
      'status': status.value,
      'image_urls': imageUrls.join(','), // 将列表存储为逗号分隔的字符串
      'error_message': errorMessage,
      'task_id': taskId,
    };
  }

  // 从Map创建对象（用于数据库读取）
  factory IllustrationDebugItem.fromMap(Map<String, dynamic> map) {
    return IllustrationDebugItem(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      imageCount: map['image_count'] as int,
      requestTime: DateTime.fromMillisecondsSinceEpoch(map['request_time'] as int),
      completedTime: map['completed_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_time'] as int)
          : null,
      status: IllustrationStatusExtension.fromString(map['status'] as String),
      imageUrls: (map['image_urls'] as String? ?? '')
          .split(',')
          .where((url) => url.isNotEmpty)
          .toList(),
      errorMessage: map['error_message'] as String?,
      taskId: map['task_id'] as String?,
    );
  }

  // 复制对象并修改部分属性
  IllustrationDebugItem copyWith({
    String? id,
    String? prompt,
    int? imageCount,
    DateTime? requestTime,
    DateTime? completedTime,
    IllustrationStatus? status,
    List<String>? imageUrls,
    String? errorMessage,
    String? taskId,
  }) {
    return IllustrationDebugItem(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      imageCount: imageCount ?? this.imageCount,
      requestTime: requestTime ?? this.requestTime,
      completedTime: completedTime ?? this.completedTime,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      errorMessage: errorMessage ?? this.errorMessage,
      taskId: taskId ?? this.taskId,
    );
  }

  // 计算完成时间间隔
  Duration? get completionDuration {
    if (completedTime == null) return null;
    return completedTime!.difference(requestTime);
  }

  // 是否正在处理中
  bool get isProcessing =>
      status == IllustrationStatus.pending || status == IllustrationStatus.processing;

  // 是否已完成（成功或失败）
  bool get isFinished =>
      status == IllustrationStatus.completed || status == IllustrationStatus.failed;

  // 是否成功
  bool get isSuccess => status == IllustrationStatus.completed;

  // 是否失败
  bool get isFailed => status == IllustrationStatus.failed;

  // 获取已生成的图片数量
  int get generatedImageCount => imageUrls.length;

  // 是否所有图片都已生成
  bool get areAllImagesGenerated => generatedImageCount >= imageCount;

  @override
  String toString() {
    return 'IllustrationDebugItem('
        'id: $id, '
        'prompt: $prompt, '
        'imageCount: $imageCount, '
        'status: $status, '
        'generatedImages: $generatedImageCount, '
        'requestTime: $requestTime'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IllustrationDebugItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}