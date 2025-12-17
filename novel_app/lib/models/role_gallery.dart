/// 角色图片数据模型
class RoleImage {
  final String filename; // 文件名
  final DateTime createdAt;
  final String? thumbnailUrl;

  const RoleImage({
    required this.filename,
    required this.createdAt,
    this.thumbnailUrl,
  });

  factory RoleImage.fromJson(Map<String, dynamic> json) {
    return RoleImage(
      filename: json['url'] ?? json['filename'] ?? '', // 支持两种字段名
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.fromMillisecondsSinceEpoch(1640000000000), // 如果没有时间信息，使用固定基准时间
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'created_at': createdAt.toIso8601String(),
      'thumbnail_url': thumbnailUrl,
    };
  }

  RoleImage copyWith({
    String? filename,
    DateTime? createdAt,
    String? thumbnailUrl,
  }) {
    return RoleImage(
      filename: filename ?? this.filename,
      createdAt: createdAt ?? this.createdAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleImage &&
          runtimeType == other.runtimeType &&
          filename == other.filename;

  @override
  int get hashCode => filename.hashCode;

  @override
  String toString() {
    return 'RoleImage{filename: $filename, createdAt: $createdAt}';
  }
}

/// 角色图集数据模型
class RoleGallery {
  final String roleId;
  final List<RoleImage> images;

  const RoleGallery({
    required this.roleId,
    required this.images,
  });

  factory RoleGallery.fromJson(Map<String, dynamic> json) {
    final List<dynamic> imagesList = json['images'] ?? [];
    return RoleGallery(
      roleId: json['role_id'] ?? '',
      images: imagesList.map((img) {
        if (img is String) {
          // API返回的是文件名字符串数组
          return RoleImage(
            filename: img,
            createdAt: DateTime.now(), // 使用当前时间即可，因为排序不依赖时间了
          );
        } else if (img is Map<String, dynamic>) {
          // 完整的对象格式
          return RoleImage.fromJson(img);
        } else {
          // 兜底处理
          return RoleImage(
            filename: img.toString(),
            createdAt: DateTime.now(),
          );
        }
      }).toList(),
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'images': images.map((img) => img.toJson()).toList(),
    };
  }

  /// 获取排序后的图片列表（按文件名逆序）
  List<RoleImage> get sortedImages {
    final sorted = List<RoleImage>.from(images);
    sorted.sort((a, b) => b.filename.compareTo(a.filename)); // 文件名逆序（Z-A）
    return sorted;
  }

  /// 获取首张图片（按文件名逆序的第一张）
  RoleImage? get firstImage {
    final sorted = sortedImages;
    return sorted.isNotEmpty ? sorted.first : null;
  }

  /// 获取图片总数
  int get imageCount => images.length;

  /// 添加新图片
  RoleGallery addImage(RoleImage image) {
    return RoleGallery(
      roleId: roleId,
      images: [...images, image],
    );
  }

  /// 移除图片
  RoleGallery removeImage(String filename) {
    return RoleGallery(
      roleId: roleId,
      images: images.where((img) => img.filename != filename).toList(),
    );
  }

  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleGallery &&
          runtimeType == other.runtimeType &&
          roleId == other.roleId;

  @override
  int get hashCode => roleId.hashCode;

  @override
  String toString() {
    return 'RoleGallery{roleId: $roleId, imageCount: $imageCount}';
  }
}