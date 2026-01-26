/// 角色关系模型
///
/// 表示两个角色之间的有向关系。
/// 例如：A是B的师父（source=A, target=B, type="师父"）
class CharacterRelationship {
  final int? id;
  final int sourceCharacterId; // 关系发起者ID
  final int targetCharacterId; // 关系目标者ID
  final String relationshipType; // 关系类型（用户自定义，如"师父"、"徒弟"）
  final String? description; // 关系详细描述
  final DateTime createdAt;
  final DateTime? updatedAt;

  CharacterRelationship({
    this.id,
    required this.sourceCharacterId,
    required this.targetCharacterId,
    required this.relationshipType,
    this.description,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 转换为数据库存储的Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_character_id': sourceCharacterId,
      'target_character_id': targetCharacterId,
      'relationship_type': relationshipType,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// 从数据库Map创建实例
  factory CharacterRelationship.fromMap(Map<String, dynamic> map) {
    return CharacterRelationship(
      id: map['id']?.toInt(),
      sourceCharacterId: map['source_character_id'] as int,
      targetCharacterId: map['target_character_id'] as int,
      relationshipType: map['relationship_type'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
    );
  }

  /// 创建副本并支持部分字段更新
  CharacterRelationship copyWith({
    int? id,
    int? sourceCharacterId,
    int? targetCharacterId,
    String? relationshipType,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CharacterRelationship(
      id: id ?? this.id,
      sourceCharacterId: sourceCharacterId ?? this.sourceCharacterId,
      targetCharacterId: targetCharacterId ?? this.targetCharacterId,
      relationshipType: relationshipType ?? this.relationshipType,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 判断是否为同一个关系
  bool isSameRelationship(CharacterRelationship other) {
    return id != null && id == other.id;
  }

  /// 获取关系的反向类型描述
  ///
  /// 例如："师父" -> "徒弟"
  /// 注意：这是启发式方法，不一定准确
  String getReverseTypeHint() {
    final type = relationshipType.toLowerCase();
    if (type.contains('师父') || type.contains('老师') || type.contains('师傅')) {
      return '徒弟';
    } else if (type.contains('徒弟') || type.contains('学生')) {
      return '师父';
    } else if (type.contains('父')) {
      return relationshipType.replaceAll('父', '子');
    } else if (type.contains('母')) {
      return relationshipType.replaceAll('母', '女');
    } else if (type.contains('夫')) {
      return relationshipType.replaceAll('夫', '妻');
    } else if (type.contains('妻')) {
      return relationshipType.replaceAll('妻', '夫');
    } else if (type.contains('兄')) {
      return relationshipType.replaceAll('兄', '弟');
    } else if (type.contains('姐')) {
      return relationshipType.replaceAll('姐', '妹');
    }
    // 无法推断，返回原类型
    return relationshipType;
  }

  @override
  String toString() {
    return 'CharacterRelationship(id: $id, source: $sourceCharacterId, target: $targetCharacterId, type: $relationshipType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CharacterRelationship &&
        other.id == id &&
        other.sourceCharacterId == sourceCharacterId &&
        other.targetCharacterId == targetCharacterId &&
        other.relationshipType == relationshipType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        sourceCharacterId.hashCode ^
        targetCharacterId.hashCode ^
        relationshipType.hashCode;
  }
}
