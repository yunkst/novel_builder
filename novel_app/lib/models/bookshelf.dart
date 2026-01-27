/// 书架模型
///
/// 用于多书架管理功能，支持用户创建自定义书架对小说进行分类
class Bookshelf {
  /// 书架唯一ID
  final int id;

  /// 书架名称
  final String name;

  /// 创建时间（Unix时间戳）
  final int createdAt;

  /// 排序字段，用于自定义书架显示顺序
  final int sortOrder;

  /// 书架图标（可选）
  final String? icon;

  /// 书架颜色（可选，ARGB格式整数）
  final int? color;

  /// 是否为系统书架
  ///
  /// 系统书架包括：
  /// - ID=1: "全部小说" - 显示所有小说，不可删除
  /// - ID=2: "我的收藏" - 默认收藏书架，不可删除
  ///
  /// 用户创建的书架：isSystem=false，可以编辑和删除
  final bool isSystem;

  Bookshelf({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sortOrder = 0,
    this.icon,
    this.color,
    this.isSystem = false,
  });

  /// 从JSON创建Bookshelf实例
  factory Bookshelf.fromJson(Map<String, dynamic> json) {
    return Bookshelf(
      id: json['id'] as int,
      name: json['name'] as String,
      createdAt: json['created_at'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
      icon: json['icon'] as String?,
      color: json['color'] as int?,
      isSystem: (json['is_system'] as int? ?? 0) == 1,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'sort_order': sortOrder,
      'icon': icon,
      'color': color,
      'is_system': isSystem ? 1 : 0,
    };
  }

  /// 创建副本，可选择性地修改某些字段
  Bookshelf copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? sortOrder,
    String? icon,
    int? color,
    bool? isSystem,
  }) {
    return Bookshelf(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  String toString() {
    return 'Bookshelf(id: $id, name: $name, isSystem: $isSystem)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bookshelf &&
        other.id == id &&
        other.name == name &&
        other.isSystem == isSystem;
  }

  @override
  int get hashCode => id.hashCode;
}
