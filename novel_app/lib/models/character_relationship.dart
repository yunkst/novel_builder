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
