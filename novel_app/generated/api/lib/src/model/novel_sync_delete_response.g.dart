// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_delete_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncDeleteResponse extends NovelSyncDeleteResponse {
  @override
  final bool success;
  @override
  final String message;

  factory _$NovelSyncDeleteResponse(
          [void Function(NovelSyncDeleteResponseBuilder)? updates]) =>
      (NovelSyncDeleteResponseBuilder()..update(updates))._build();

  _$NovelSyncDeleteResponse._({required this.success, required this.message})
      : super._();
  @override
  NovelSyncDeleteResponse rebuild(
          void Function(NovelSyncDeleteResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NovelSyncDeleteResponseBuilder toBuilder() =>
      NovelSyncDeleteResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NovelSyncDeleteResponse &&
        success == other.success &&
        message == other.message;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, success.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NovelSyncDeleteResponse')
          ..add('success', success)
          ..add('message', message))
        .toString();
  }
}

class NovelSyncDeleteResponseBuilder
    implements
        Builder<NovelSyncDeleteResponse, NovelSyncDeleteResponseBuilder> {
  _$NovelSyncDeleteResponse? _$v;

  bool? _success;
  bool? get success => _$this._success;
  set success(bool? success) => _$this._success = success;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  NovelSyncDeleteResponseBuilder() {
    NovelSyncDeleteResponse._defaults(this);
  }

  NovelSyncDeleteResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _success = $v.success;
      _message = $v.message;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NovelSyncDeleteResponse other) {
    _$v = other as _$NovelSyncDeleteResponse;
  }

  @override
  void update(void Function(NovelSyncDeleteResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NovelSyncDeleteResponse build() => _build();

  _$NovelSyncDeleteResponse _build() {
    final _$result = _$v ??
        _$NovelSyncDeleteResponse._(
          success: BuiltValueNullFieldError.checkNotNull(
              success, r'NovelSyncDeleteResponse', 'success'),
          message: BuiltValueNullFieldError.checkNotNull(
              message, r'NovelSyncDeleteResponse', 'message'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
