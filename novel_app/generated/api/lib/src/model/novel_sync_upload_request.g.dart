// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_upload_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncUploadRequest extends NovelSyncUploadRequest {
  @override
  final NovelSyncData novelData;
  @override
  final bool? forceOverwrite;

  factory _$NovelSyncUploadRequest(
          [void Function(NovelSyncUploadRequestBuilder)? updates]) =>
      (NovelSyncUploadRequestBuilder()..update(updates))._build();

  _$NovelSyncUploadRequest._({required this.novelData, this.forceOverwrite})
      : super._();
  @override
  NovelSyncUploadRequest rebuild(
          void Function(NovelSyncUploadRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NovelSyncUploadRequestBuilder toBuilder() =>
      NovelSyncUploadRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NovelSyncUploadRequest &&
        novelData == other.novelData &&
        forceOverwrite == other.forceOverwrite;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, novelData.hashCode);
    _$hash = $jc(_$hash, forceOverwrite.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NovelSyncUploadRequest')
          ..add('novelData', novelData)
          ..add('forceOverwrite', forceOverwrite))
        .toString();
  }
}

class NovelSyncUploadRequestBuilder
    implements Builder<NovelSyncUploadRequest, NovelSyncUploadRequestBuilder> {
  _$NovelSyncUploadRequest? _$v;

  NovelSyncDataBuilder? _novelData;
  NovelSyncDataBuilder get novelData =>
      _$this._novelData ??= NovelSyncDataBuilder();
  set novelData(NovelSyncDataBuilder? novelData) =>
      _$this._novelData = novelData;

  bool? _forceOverwrite;
  bool? get forceOverwrite => _$this._forceOverwrite;
  set forceOverwrite(bool? forceOverwrite) =>
      _$this._forceOverwrite = forceOverwrite;

  NovelSyncUploadRequestBuilder() {
    NovelSyncUploadRequest._defaults(this);
  }

  NovelSyncUploadRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _novelData = $v.novelData.toBuilder();
      _forceOverwrite = $v.forceOverwrite;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NovelSyncUploadRequest other) {
    _$v = other as _$NovelSyncUploadRequest;
  }

  @override
  void update(void Function(NovelSyncUploadRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NovelSyncUploadRequest build() => _build();

  _$NovelSyncUploadRequest _build() {
    _$NovelSyncUploadRequest _$result;
    try {
      _$result = _$v ??
          _$NovelSyncUploadRequest._(
            novelData: novelData.build(),
            forceOverwrite: forceOverwrite,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'novelData';
        novelData.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'NovelSyncUploadRequest', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
