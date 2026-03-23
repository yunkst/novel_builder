// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_sync_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ChapterSyncData extends ChapterSyncData {
  @override
  final int chapterId;
  @override
  final String title;
  @override
  final String content;
  @override
  final int chapterIndex;
  @override
  final bool? isUserInserted;
  @override
  final String? createdAt;
  @override
  final String? updatedAt;

  factory _$ChapterSyncData([void Function(ChapterSyncDataBuilder)? updates]) =>
      (ChapterSyncDataBuilder()..update(updates))._build();

  _$ChapterSyncData._(
      {required this.chapterId,
      required this.title,
      required this.content,
      required this.chapterIndex,
      this.isUserInserted,
      this.createdAt,
      this.updatedAt})
      : super._();
  @override
  ChapterSyncData rebuild(void Function(ChapterSyncDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ChapterSyncDataBuilder toBuilder() => ChapterSyncDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ChapterSyncData &&
        chapterId == other.chapterId &&
        title == other.title &&
        content == other.content &&
        chapterIndex == other.chapterIndex &&
        isUserInserted == other.isUserInserted &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, chapterId.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, content.hashCode);
    _$hash = $jc(_$hash, chapterIndex.hashCode);
    _$hash = $jc(_$hash, isUserInserted.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ChapterSyncData')
          ..add('chapterId', chapterId)
          ..add('title', title)
          ..add('content', content)
          ..add('chapterIndex', chapterIndex)
          ..add('isUserInserted', isUserInserted)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class ChapterSyncDataBuilder
    implements Builder<ChapterSyncData, ChapterSyncDataBuilder> {
  _$ChapterSyncData? _$v;

  int? _chapterId;
  int? get chapterId => _$this._chapterId;
  set chapterId(int? chapterId) => _$this._chapterId = chapterId;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _content;
  String? get content => _$this._content;
  set content(String? content) => _$this._content = content;

  int? _chapterIndex;
  int? get chapterIndex => _$this._chapterIndex;
  set chapterIndex(int? chapterIndex) => _$this._chapterIndex = chapterIndex;

  bool? _isUserInserted;
  bool? get isUserInserted => _$this._isUserInserted;
  set isUserInserted(bool? isUserInserted) =>
      _$this._isUserInserted = isUserInserted;

  String? _createdAt;
  String? get createdAt => _$this._createdAt;
  set createdAt(String? createdAt) => _$this._createdAt = createdAt;

  String? _updatedAt;
  String? get updatedAt => _$this._updatedAt;
  set updatedAt(String? updatedAt) => _$this._updatedAt = updatedAt;

  ChapterSyncDataBuilder() {
    ChapterSyncData._defaults(this);
  }

  ChapterSyncDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _chapterId = $v.chapterId;
      _title = $v.title;
      _content = $v.content;
      _chapterIndex = $v.chapterIndex;
      _isUserInserted = $v.isUserInserted;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ChapterSyncData other) {
    _$v = other as _$ChapterSyncData;
  }

  @override
  void update(void Function(ChapterSyncDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ChapterSyncData build() => _build();

  _$ChapterSyncData _build() {
    final _$result = _$v ??
        _$ChapterSyncData._(
          chapterId: BuiltValueNullFieldError.checkNotNull(
              chapterId, r'ChapterSyncData', 'chapterId'),
          title: BuiltValueNullFieldError.checkNotNull(
              title, r'ChapterSyncData', 'title'),
          content: BuiltValueNullFieldError.checkNotNull(
              content, r'ChapterSyncData', 'content'),
          chapterIndex: BuiltValueNullFieldError.checkNotNull(
              chapterIndex, r'ChapterSyncData', 'chapterIndex'),
          isUserInserted: isUserInserted,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
