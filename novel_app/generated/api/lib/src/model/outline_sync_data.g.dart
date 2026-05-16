// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outline_sync_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$OutlineSyncData extends OutlineSyncData {
  @override
  final String title;
  @override
  final String content;

  factory _$OutlineSyncData([void Function(OutlineSyncDataBuilder)? updates]) =>
      (OutlineSyncDataBuilder()..update(updates))._build();

  _$OutlineSyncData._({required this.title, required this.content}) : super._();
  @override
  OutlineSyncData rebuild(void Function(OutlineSyncDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OutlineSyncDataBuilder toBuilder() => OutlineSyncDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is OutlineSyncData &&
        title == other.title &&
        content == other.content;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, content.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'OutlineSyncData')
          ..add('title', title)
          ..add('content', content))
        .toString();
  }
}

class OutlineSyncDataBuilder
    implements Builder<OutlineSyncData, OutlineSyncDataBuilder> {
  _$OutlineSyncData? _$v;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _content;
  String? get content => _$this._content;
  set content(String? content) => _$this._content = content;

  OutlineSyncDataBuilder() {
    OutlineSyncData._defaults(this);
  }

  OutlineSyncDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _title = $v.title;
      _content = $v.content;
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
          title: BuiltValueNullFieldError.checkNotNull(
              title, r'OutlineSyncData', 'title'),
          content: BuiltValueNullFieldError.checkNotNull(
              content, r'OutlineSyncData', 'content'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
