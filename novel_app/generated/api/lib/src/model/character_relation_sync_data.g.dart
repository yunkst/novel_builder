// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_relation_sync_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CharacterRelationSyncData extends CharacterRelationSyncData {
  @override
  final int relationId;
  @override
  final int character1Id;
  @override
  final int character2Id;
  @override
  final String relationType;
  @override
  final String? description;
  @override
  final String? createdAt;
  @override
  final String? updatedAt;

  factory _$CharacterRelationSyncData(
          [void Function(CharacterRelationSyncDataBuilder)? updates]) =>
      (CharacterRelationSyncDataBuilder()..update(updates))._build();

  _$CharacterRelationSyncData._(
      {required this.relationId,
      required this.character1Id,
      required this.character2Id,
      required this.relationType,
      this.description,
      this.createdAt,
      this.updatedAt})
      : super._();
  @override
  CharacterRelationSyncData rebuild(
          void Function(CharacterRelationSyncDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CharacterRelationSyncDataBuilder toBuilder() =>
      CharacterRelationSyncDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CharacterRelationSyncData &&
        relationId == other.relationId &&
        character1Id == other.character1Id &&
        character2Id == other.character2Id &&
        relationType == other.relationType &&
        description == other.description &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, relationId.hashCode);
    _$hash = $jc(_$hash, character1Id.hashCode);
    _$hash = $jc(_$hash, character2Id.hashCode);
    _$hash = $jc(_$hash, relationType.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CharacterRelationSyncData')
          ..add('relationId', relationId)
          ..add('character1Id', character1Id)
          ..add('character2Id', character2Id)
          ..add('relationType', relationType)
          ..add('description', description)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class CharacterRelationSyncDataBuilder
    implements
        Builder<CharacterRelationSyncData, CharacterRelationSyncDataBuilder> {
  _$CharacterRelationSyncData? _$v;

  int? _relationId;
  int? get relationId => _$this._relationId;
  set relationId(int? relationId) => _$this._relationId = relationId;

  int? _character1Id;
  int? get character1Id => _$this._character1Id;
  set character1Id(int? character1Id) => _$this._character1Id = character1Id;

  int? _character2Id;
  int? get character2Id => _$this._character2Id;
  set character2Id(int? character2Id) => _$this._character2Id = character2Id;

  String? _relationType;
  String? get relationType => _$this._relationType;
  set relationType(String? relationType) => _$this._relationType = relationType;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  String? _createdAt;
  String? get createdAt => _$this._createdAt;
  set createdAt(String? createdAt) => _$this._createdAt = createdAt;

  String? _updatedAt;
  String? get updatedAt => _$this._updatedAt;
  set updatedAt(String? updatedAt) => _$this._updatedAt = updatedAt;

  CharacterRelationSyncDataBuilder() {
    CharacterRelationSyncData._defaults(this);
  }

  CharacterRelationSyncDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _relationId = $v.relationId;
      _character1Id = $v.character1Id;
      _character2Id = $v.character2Id;
      _relationType = $v.relationType;
      _description = $v.description;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CharacterRelationSyncData other) {
    _$v = other as _$CharacterRelationSyncData;
  }

  @override
  void update(void Function(CharacterRelationSyncDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CharacterRelationSyncData build() => _build();

  _$CharacterRelationSyncData _build() {
    final _$result = _$v ??
        _$CharacterRelationSyncData._(
          relationId: BuiltValueNullFieldError.checkNotNull(
              relationId, r'CharacterRelationSyncData', 'relationId'),
          character1Id: BuiltValueNullFieldError.checkNotNull(
              character1Id, r'CharacterRelationSyncData', 'character1Id'),
          character2Id: BuiltValueNullFieldError.checkNotNull(
              character2Id, r'CharacterRelationSyncData', 'character2Id'),
          relationType: BuiltValueNullFieldError.checkNotNull(
              relationType, r'CharacterRelationSyncData', 'relationType'),
          description: description,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
