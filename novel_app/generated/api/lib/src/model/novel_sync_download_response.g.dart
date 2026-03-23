// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_download_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncDownloadResponse extends NovelSyncDownloadResponse {
  @override
  final bool success;
  @override
  final String message;
  @override
  final NovelSyncData? novelData;
  @override
  final int syncVersion;
  @override
  final String syncedAt;

  factory _$NovelSyncDownloadResponse(
          [void Function(NovelSyncDownloadResponseBuilder)? updates]) =>
      (NovelSyncDownloadResponseBuilder()..update(updates))._build();

  _$NovelSyncDownloadResponse._(
      {required this.success,
      required this.message,
      this.novelData,
      required this.syncVersion,
      required this.syncedAt})
      : super._();
  @override
  NovelSyncDownloadResponse rebuild(
          void Function(NovelSyncDownloadResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NovelSyncDownloadResponseBuilder toBuilder() =>
      NovelSyncDownloadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NovelSyncDownloadResponse &&
        success == other.success &&
        message == other.message &&
        novelData == other.novelData &&
        syncVersion == other.syncVersion &&
        syncedAt == other.syncedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, success.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, novelData.hashCode);
    _$hash = $jc(_$hash, syncVersion.hashCode);
    _$hash = $jc(_$hash, syncedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NovelSyncDownloadResponse')
          ..add('success', success)
          ..add('message', message)
          ..add('novelData', novelData)
          ..add('syncVersion', syncVersion)
          ..add('syncedAt', syncedAt))
        .toString();
  }
}

class NovelSyncDownloadResponseBuilder
    implements
        Builder<NovelSyncDownloadResponse, NovelSyncDownloadResponseBuilder> {
  _$NovelSyncDownloadResponse? _$v;

  bool? _success;
  bool? get success => _$this._success;
  set success(bool? success) => _$this._success = success;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  NovelSyncDataBuilder? _novelData;
  NovelSyncDataBuilder get novelData =>
      _$this._novelData ??= NovelSyncDataBuilder();
  set novelData(NovelSyncDataBuilder? novelData) =>
      _$this._novelData = novelData;

  int? _syncVersion;
  int? get syncVersion => _$this._syncVersion;
  set syncVersion(int? syncVersion) => _$this._syncVersion = syncVersion;

  String? _syncedAt;
  String? get syncedAt => _$this._syncedAt;
  set syncedAt(String? syncedAt) => _$this._syncedAt = syncedAt;

  NovelSyncDownloadResponseBuilder() {
    NovelSyncDownloadResponse._defaults(this);
  }

  NovelSyncDownloadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _success = $v.success;
      _message = $v.message;
      _novelData = $v.novelData?.toBuilder();
      _syncVersion = $v.syncVersion;
      _syncedAt = $v.syncedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NovelSyncDownloadResponse other) {
    _$v = other as _$NovelSyncDownloadResponse;
  }

  @override
  void update(void Function(NovelSyncDownloadResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NovelSyncDownloadResponse build() => _build();

  _$NovelSyncDownloadResponse _build() {
    _$NovelSyncDownloadResponse _$result;
    try {
      _$result = _$v ??
          _$NovelSyncDownloadResponse._(
            success: BuiltValueNullFieldError.checkNotNull(
                success, r'NovelSyncDownloadResponse', 'success'),
            message: BuiltValueNullFieldError.checkNotNull(
                message, r'NovelSyncDownloadResponse', 'message'),
            novelData: _novelData?.build(),
            syncVersion: BuiltValueNullFieldError.checkNotNull(
                syncVersion, r'NovelSyncDownloadResponse', 'syncVersion'),
            syncedAt: BuiltValueNullFieldError.checkNotNull(
                syncedAt, r'NovelSyncDownloadResponse', 'syncedAt'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'novelData';
        _novelData?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'NovelSyncDownloadResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
