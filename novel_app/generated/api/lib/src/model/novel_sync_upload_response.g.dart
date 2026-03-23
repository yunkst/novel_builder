// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_upload_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncUploadResponse extends NovelSyncUploadResponse {
  @override
  final bool success;
  @override
  final String message;
  @override
  final int novelId;
  @override
  final int syncVersion;
  @override
  final String syncedAt;

  factory _$NovelSyncUploadResponse(
          [void Function(NovelSyncUploadResponseBuilder)? updates]) =>
      (NovelSyncUploadResponseBuilder()..update(updates))._build();

  _$NovelSyncUploadResponse._(
      {required this.success,
      required this.message,
      required this.novelId,
      required this.syncVersion,
      required this.syncedAt})
      : super._();
  @override
  NovelSyncUploadResponse rebuild(
          void Function(NovelSyncUploadResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NovelSyncUploadResponseBuilder toBuilder() =>
      NovelSyncUploadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NovelSyncUploadResponse &&
        success == other.success &&
        message == other.message &&
        novelId == other.novelId &&
        syncVersion == other.syncVersion &&
        syncedAt == other.syncedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, success.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, novelId.hashCode);
    _$hash = $jc(_$hash, syncVersion.hashCode);
    _$hash = $jc(_$hash, syncedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NovelSyncUploadResponse')
          ..add('success', success)
          ..add('message', message)
          ..add('novelId', novelId)
          ..add('syncVersion', syncVersion)
          ..add('syncedAt', syncedAt))
        .toString();
  }
}

class NovelSyncUploadResponseBuilder
    implements
        Builder<NovelSyncUploadResponse, NovelSyncUploadResponseBuilder> {
  _$NovelSyncUploadResponse? _$v;

  bool? _success;
  bool? get success => _$this._success;
  set success(bool? success) => _$this._success = success;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  int? _novelId;
  int? get novelId => _$this._novelId;
  set novelId(int? novelId) => _$this._novelId = novelId;

  int? _syncVersion;
  int? get syncVersion => _$this._syncVersion;
  set syncVersion(int? syncVersion) => _$this._syncVersion = syncVersion;

  String? _syncedAt;
  String? get syncedAt => _$this._syncedAt;
  set syncedAt(String? syncedAt) => _$this._syncedAt = syncedAt;

  NovelSyncUploadResponseBuilder() {
    NovelSyncUploadResponse._defaults(this);
  }

  NovelSyncUploadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _success = $v.success;
      _message = $v.message;
      _novelId = $v.novelId;
      _syncVersion = $v.syncVersion;
      _syncedAt = $v.syncedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NovelSyncUploadResponse other) {
    _$v = other as _$NovelSyncUploadResponse;
  }

  @override
  void update(void Function(NovelSyncUploadResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NovelSyncUploadResponse build() => _build();

  _$NovelSyncUploadResponse _build() {
    final _$result = _$v ??
        _$NovelSyncUploadResponse._(
          success: BuiltValueNullFieldError.checkNotNull(
              success, r'NovelSyncUploadResponse', 'success'),
          message: BuiltValueNullFieldError.checkNotNull(
              message, r'NovelSyncUploadResponse', 'message'),
          novelId: BuiltValueNullFieldError.checkNotNull(
              novelId, r'NovelSyncUploadResponse', 'novelId'),
          syncVersion: BuiltValueNullFieldError.checkNotNull(
              syncVersion, r'NovelSyncUploadResponse', 'syncVersion'),
          syncedAt: BuiltValueNullFieldError.checkNotNull(
              syncedAt, r'NovelSyncUploadResponse', 'syncedAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
