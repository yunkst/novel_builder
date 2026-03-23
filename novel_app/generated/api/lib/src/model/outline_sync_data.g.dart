// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outline_sync_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OutlineSyncData extends OutlineSyncData {
  @override
  final int outlineId;
  @override
  final String title;
  @override
  final String content;
  @override
  final String outlineType;
  @override
  final int? parentId;
  @override
  final int? sortOrder;
  @override
  final String? createdAt;
  @override
  final String? updatedAt;

  factory _$OutlineSyncData([void Function(OutlineSyncDataBuilder)? updates]) =>
      (OutlineSyncDataBuilder()..update(updates))._build();

  _$OutlineSyncData._(
      {required this.outlineId,
      required this.title,
      required this.content,
      required this.outlineType,
      this.parentId,
      this.sortOrder,
      this.createdAt,
      this.updatedAt})
      : super._();
  @override
  OutlineSyncData rebuild(void Function(OutlineSyncDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OutlineSyncDataBuilder toBuilder() => OutlineSyncDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OutlineSyncData &&
        outlineId == other.outlineId &&
        title == other.title &&
        content == other.content &&
        outlineType == other.outlineType &&
        parentId == other.parentId &&
        sortOrder == other.sortOrder &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, outlineId.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, content.hashCode);
    _$hash = $jc(_$hash, outlineType.hashCode);
    _$hash = $jc(_$hash, parentId.hashCode);
    _$hash = $jc(_$hash, sortOrder.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OutlineSyncData')
          ..add('outlineId', outlineId)
          ..add('title', title)
          ..add('content', content)
          ..add('outlineType', outlineType)
          ..add('parentId', parentId)
          ..add('sortOrder', sortOrder)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class OutlineSyncDataBuilder
    implements Builder<OutlineSyncData, OutlineSyncDataBuilder> {
  _$OutlineSyncData? _$v;

  int? _outlineId;
  int? get outlineId => _$this._outlineId;
  set outlineId(int? outlineId) => _$this._outlineId = outlineId;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _content;
  String? get content => _$this._content;
  set content(String? content) => _$this._content = content;

  String? _outlineType;
  String? get outlineType => _$this._outlineType;
  set outlineType(String? outlineType) => _$this._outlineType = outlineType;

  int? _parentId;
  int? get parentId => _$this._parentId;
  set parentId(int? parentId) => _$this._parentId = parentId;

  int? _sortOrder;
  int? get sortOrder => _$this._sortOrder;
  set sortOrder(int? sortOrder) => _$this._sortOrder = sortOrder;

  String? _createdAt;
  String? get createdAt => _$this._createdAt;
  set createdAt(String? createdAt) => _$this._createdAt = createdAt;

  String? _updatedAt;
  String? get updatedAt => _$this._updatedAt;
  set updatedAt(String? updatedAt) => _$this._updatedAt = updatedAt;

  OutlineSyncDataBuilder() {
    OutlineSyncData._defaults(this);
  }

  OutlineSyncDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _outlineId = $v.outlineId;
      _title = $v.title;
      _content = $v.content;
      _outlineType = $v.outlineType;
      _parentId = $v.parentId;
      _sortOrder = $v.sortOrder;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(OutlineSyncData other) {
    _$v = other as _$OutlineSyncData;
  }

  @override
  void update(void Function(OutlineSyncDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  OutlineSyncData build() => _build();

  _$OutlineSyncData _build() {
    final _$result = _$v ??
        _$OutlineSyncData._(
          outlineId: BuiltValueNullFieldError.checkNotNull(
              outlineId, r'OutlineSyncData', 'outlineId'),
          title: BuiltValueNullFieldError.checkNotNull(
              title, r'OutlineSyncData', 'title'),
          content: BuiltValueNullFieldError.checkNotNull(
              content, r'OutlineSyncData', 'content'),
          outlineType: BuiltValueNullFieldError.checkNotNull(
              outlineType, r'OutlineSyncData', 'outlineType'),
          parentId: parentId,
          sortOrder: sortOrder,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
