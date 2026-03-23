// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_list_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncListResponse extends NovelSyncListResponse {
  @override
  final bool success;
  @override
  final String message;
  @override
  final BuiltList<NovelSyncData>? novels;
  @override
  final int totalCount;
  @override
  final int? page;
  @override
  final int? pageSize;

  factory _$NovelSyncListResponse(
          [void Function(NovelSyncListResponseBuilder)? updates]) =>
      (NovelSyncListResponseBuilder()..update(updates))._build();

  _$NovelSyncListResponse._(
      {required this.success,
      required this.message,
      this.novels,
      required this.totalCount,
      this.page,
      this.pageSize})
      : super._();
  @override
  NovelSyncListResponse rebuild(
          void Function(NovelSyncListResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NovelSyncListResponseBuilder toBuilder() =>
      NovelSyncListResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NovelSyncListResponse &&
        success == other.success &&
        message == other.message &&
        novels == other.novels &&
        totalCount == other.totalCount &&
        page == other.page &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, success.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jc(_$hash, novels.hashCode);
    _$hash = $jc(_$hash, totalCount.hashCode);
    _$hash = $jc(_$hash, page.hashCode);
    _$hash = $jc(_$hash, pageSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NovelSyncListResponse')
          ..add('success', success)
          ..add('message', message)
          ..add('novels', novels)
          ..add('totalCount', totalCount)
          ..add('page', page)
          ..add('pageSize', pageSize))
        .toString();
  }
}

class NovelSyncListResponseBuilder
    implements Builder<NovelSyncListResponse, NovelSyncListResponseBuilder> {
  _$NovelSyncListResponse? _$v;

  bool? _success;
  bool? get success => _$this._success;
  set success(bool? success) => _$this._success = success;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  ListBuilder<NovelSyncData>? _novels;
  ListBuilder<NovelSyncData> get novels =>
      _$this._novels ??= ListBuilder<NovelSyncData>();
  set novels(ListBuilder<NovelSyncData>? novels) => _$this._novels = novels;

  int? _totalCount;
  int? get totalCount => _$this._totalCount;
  set totalCount(int? totalCount) => _$this._totalCount = totalCount;

  int? _page;
  int? get page => _$this._page;
  set page(int? page) => _$this._page = page;

  int? _pageSize;
  int? get pageSize => _$this._pageSize;
  set pageSize(int? pageSize) => _$this._pageSize = pageSize;

  NovelSyncListResponseBuilder() {
    NovelSyncListResponse._defaults(this);
  }

  NovelSyncListResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _success = $v.success;
      _message = $v.message;
      _novels = $v.novels?.toBuilder();
      _totalCount = $v.totalCount;
      _page = $v.page;
      _pageSize = $v.pageSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NovelSyncListResponse other) {
    _$v = other as _$NovelSyncListResponse;
  }

  @override
  void update(void Function(NovelSyncListResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NovelSyncListResponse build() => _build();

  _$NovelSyncListResponse _build() {
    _$NovelSyncListResponse _$result;
    try {
      _$result = _$v ??
          _$NovelSyncListResponse._(
            success: BuiltValueNullFieldError.checkNotNull(
                success, r'NovelSyncListResponse', 'success'),
            message: BuiltValueNullFieldError.checkNotNull(
                message, r'NovelSyncListResponse', 'message'),
            novels: _novels?.build(),
            totalCount: BuiltValueNullFieldError.checkNotNull(
                totalCount, r'NovelSyncListResponse', 'totalCount'),
            page: page,
            pageSize: pageSize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'novels';
        _novels?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'NovelSyncListResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
