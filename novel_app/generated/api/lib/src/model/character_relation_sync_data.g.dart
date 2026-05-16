// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_relation_sync_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CharacterRelationSyncData extends CharacterRelationSyncData {
  @override
  final String character1;
  @override
  final String character2;
  @override
  final String relationType;
  @override
  final String? description;

  factory _$CharacterRelationSyncData(
          [void Function(CharacterRelationSyncDataBuilder)? updates]) =>
      (CharacterRelationSyncDataBuilder()..update(updates))._build();

  _$CharacterRelationSyncData._(
      {required this.character1,
      required this.character2,
      required this.relationType,
      this.description})
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
        character1 == other.character1 &&
        character2 == other.character2 &&
        relationType == other.relationType &&
        description == other.description;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, character1.hashCode);
    _$hash = $jc(_$hash, character2.hashCode);
    _$hash = $jc(_$hash, relationType.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CharacterRelationSyncData')
          ..add('character1', character1)
          ..add('character2', character2)
          ..add('relationType', relationType)
          ..add('description', description))
        .toString();
  }
}

class CharacterRelationSyncDataBuilder
    implements
        Builder<CharacterRelationSyncData, CharacterRelationSyncDataBuilder> {
  _$CharacterRelationSyncData? _$v;

  String? _character1;
  String? get character1 => _$this._character1;
  set character1(String? character1) => _$this._character1 = character1;

  String? _character2;
  String? get character2 => _$this._character2;
  set character2(String? character2) => _$this._character2 = character2;

  String? _relationType;
  String? get relationType => _$this._relationType;
  set relationType(String? relationType) => _$this._relationType = relationType;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  CharacterRelationSyncDataBuilder() {
    CharacterRelationSyncData._defaults(this);
  }

  CharacterRelationSyncDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _character1 = $v.character1;
      _character2 = $v.character2;
      _relationType = $v.relationType;
      _description = $v.description;
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
          character1: BuiltValueNullFieldError.checkNotNull(
              character1, r'CharacterRelationSyncData', 'character1'),
          character2: BuiltValueNullFieldError.checkNotNull(
              character2, r'CharacterRelationSyncData', 'character2'),
          relationType: BuiltValueNullFieldError.checkNotNull(
              relationType, r'CharacterRelationSyncData', 'relationType'),
          description: description,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
