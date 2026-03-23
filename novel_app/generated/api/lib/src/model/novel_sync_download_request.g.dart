// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_download_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncDownloadRequest extends NovelSyncDownloadRequest {
  @override
  final String deviceId;
  @override
  final String sourceUrl;
  @override
  final bool? includeChapters;
  @override
  final bool? includeCharacters;
  @override
  final bool? includeOutlines;

  factory _$NovelSyncDownloadRequest(
          [void Function(NovelSyncDownloadRequestBuilder)? updates]) =>
      (NovelSyncDownloadRequestBuilder()..update(updates))._build();

  _$NovelSyncDownloadRequest._(
      {required this.deviceId,
      required this.sourceUrl,
      this.includeChapters,
      this.includeCharacters,
      this.includeOutlines})
      : super._();
  @override
  NovelSyncDownloadRequest rebuild(
          void Function(NovelSyncDownloadRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NovelSyncDownloadRequestBuilder toBuilder() =>
      NovelSyncDownloadRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NovelSyncDownloadRequest &&
        deviceId == other.deviceId &&
        sourceUrl == other.sourceUrl &&
        includeChapters == other.includeChapters &&
        includeCharacters == other.includeCharacters &&
        includeOutlines == other.includeOutlines;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jc(_$hash, sourceUrl.hashCode);
    _$hash = $jc(_$hash, includeChapters.hashCode);
    _$hash = $jc(_$hash, includeCharacters.hashCode);
    _$hash = $jc(_$hash, includeOutlines.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NovelSyncDownloadRequest')
          ..add('deviceId', deviceId)
          ..add('sourceUrl', sourceUrl)
          ..add('includeChapters', includeChapters)
          ..add('includeCharacters', includeCharacters)
          ..add('includeOutlines', includeOutlines))
        .toString();
  }
}

class NovelSyncDownloadRequestBuilder
    implements
        Builder<NovelSyncDownloadRequest, NovelSyncDownloadRequestBuilder> {
  _$NovelSyncDownloadRequest? _$v;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  String? _sourceUrl;
  String? get sourceUrl => _$this._sourceUrl;
  set sourceUrl(String? sourceUrl) => _$this._sourceUrl = sourceUrl;

  bool? _includeChapters;
  bool? get includeChapters => _$this._includeChapters;
  set includeChapters(bool? includeChapters) =>
      _$this._includeChapters = includeChapters;

  bool? _includeCharacters;
  bool? get includeCharacters => _$this._includeCharacters;
  set includeCharacters(bool? includeCharacters) =>
      _$this._includeCharacters = includeCharacters;

  bool? _includeOutlines;
  bool? get includeOutlines => _$this._includeOutlines;
  set includeOutlines(bool? includeOutlines) =>
      _$this._includeOutlines = includeOutlines;

  NovelSyncDownloadRequestBuilder() {
    NovelSyncDownloadRequest._defaults(this);
  }

  NovelSyncDownloadRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceId = $v.deviceId;
      _sourceUrl = $v.sourceUrl;
      _includeChapters = $v.includeChapters;
      _includeCharacters = $v.includeCharacters;
      _includeOutlines = $v.includeOutlines;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NovelSyncDownloadRequest other) {
    _$v = other as _$NovelSyncDownloadRequest;
  }

  @override
  void update(void Function(NovelSyncDownloadRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NovelSyncDownloadRequest build() => _build();

  _$NovelSyncDownloadRequest _build() {
    final _$result = _$v ??
        _$NovelSyncDownloadRequest._(
          deviceId: BuiltValueNullFieldError.checkNotNull(
              deviceId, r'NovelSyncDownloadRequest', 'deviceId'),
          sourceUrl: BuiltValueNullFieldError.checkNotNull(
              sourceUrl, r'NovelSyncDownloadRequest', 'sourceUrl'),
          includeChapters: includeChapters,
          includeCharacters: includeCharacters,
          includeOutlines: includeOutlines,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
