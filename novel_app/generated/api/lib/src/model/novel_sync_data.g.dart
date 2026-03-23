// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncData extends NovelSyncData {
  @override
  final int novelId;
  @override
  final String title;
  @override
  final String? author;
  @override
  final String? description;
  @override
  final String? coverUrl;
  @override
  final String? sourceUrl;
  @override
  final int? totalChapters;
  @override
  final int? totalWords;
  @override
  final int? lastReadChapterId;
  @override
  final int? lastReadPosition;
  @override
  final bool? isFavorite;
  @override
  final String? createdAt;
  @override
  final String? updatedAt;
  @override
  final BuiltList<ChapterSyncData>? chapters;
  @override
  final BuiltList<CharacterSyncData>? characters;
  @override
  final BuiltList<CharacterRelationSyncData>? characterRelations;
  @override
  final BuiltList<OutlineSyncData>? outlines;

  factory _$NovelSyncData([void Function(NovelSyncDataBuilder)? updates]) =>
      (NovelSyncDataBuilder()..update(updates))._build();

  _$NovelSyncData._(
      {required this.novelId,
      required this.title,
      this.author,
      this.description,
      this.coverUrl,
      this.sourceUrl,
      this.totalChapters,
      this.totalWords,
      this.lastReadChapterId,
      this.lastReadPosition,
      this.isFavorite,
      this.createdAt,
      this.updatedAt,
      this.chapters,
      this.characters,
      this.characterRelations,
      this.outlines})
      : super._();
  @override
  NovelSyncData rebuild(void Function(NovelSyncDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  NovelSyncDataBuilder toBuilder() => NovelSyncDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is NovelSyncData &&
        novelId == other.novelId &&
        title == other.title &&
        author == other.author &&
        description == other.description &&
        coverUrl == other.coverUrl &&
        sourceUrl == other.sourceUrl &&
        totalChapters == other.totalChapters &&
        totalWords == other.totalWords &&
        lastReadChapterId == other.lastReadChapterId &&
        lastReadPosition == other.lastReadPosition &&
        isFavorite == other.isFavorite &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        chapters == other.chapters &&
        characters == other.characters &&
        characterRelations == other.characterRelations &&
        outlines == other.outlines;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, novelId.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, author.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, coverUrl.hashCode);
    _$hash = $jc(_$hash, sourceUrl.hashCode);
    _$hash = $jc(_$hash, totalChapters.hashCode);
    _$hash = $jc(_$hash, totalWords.hashCode);
    _$hash = $jc(_$hash, lastReadChapterId.hashCode);
    _$hash = $jc(_$hash, lastReadPosition.hashCode);
    _$hash = $jc(_$hash, isFavorite.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, chapters.hashCode);
    _$hash = $jc(_$hash, characters.hashCode);
    _$hash = $jc(_$hash, characterRelations.hashCode);
    _$hash = $jc(_$hash, outlines.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'NovelSyncData')
          ..add('novelId', novelId)
          ..add('title', title)
          ..add('author', author)
          ..add('description', description)
          ..add('coverUrl', coverUrl)
          ..add('sourceUrl', sourceUrl)
          ..add('totalChapters', totalChapters)
          ..add('totalWords', totalWords)
          ..add('lastReadChapterId', lastReadChapterId)
          ..add('lastReadPosition', lastReadPosition)
          ..add('isFavorite', isFavorite)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt)
          ..add('chapters', chapters)
          ..add('characters', characters)
          ..add('characterRelations', characterRelations)
          ..add('outlines', outlines))
        .toString();
  }
}

class NovelSyncDataBuilder
    implements Builder<NovelSyncData, NovelSyncDataBuilder> {
  _$NovelSyncData? _$v;

  int? _novelId;
  int? get novelId => _$this._novelId;
  set novelId(int? novelId) => _$this._novelId = novelId;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _author;
  String? get author => _$this._author;
  set author(String? author) => _$this._author = author;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  String? _coverUrl;
  String? get coverUrl => _$this._coverUrl;
  set coverUrl(String? coverUrl) => _$this._coverUrl = coverUrl;

  String? _sourceUrl;
  String? get sourceUrl => _$this._sourceUrl;
  set sourceUrl(String? sourceUrl) => _$this._sourceUrl = sourceUrl;

  int? _totalChapters;
  int? get totalChapters => _$this._totalChapters;
  set totalChapters(int? totalChapters) =>
      _$this._totalChapters = totalChapters;

  int? _totalWords;
  int? get totalWords => _$this._totalWords;
  set totalWords(int? totalWords) => _$this._totalWords = totalWords;

  int? _lastReadChapterId;
  int? get lastReadChapterId => _$this._lastReadChapterId;
  set lastReadChapterId(int? lastReadChapterId) =>
      _$this._lastReadChapterId = lastReadChapterId;

  int? _lastReadPosition;
  int? get lastReadPosition => _$this._lastReadPosition;
  set lastReadPosition(int? lastReadPosition) =>
      _$this._lastReadPosition = lastReadPosition;

  bool? _isFavorite;
  bool? get isFavorite => _$this._isFavorite;
  set isFavorite(bool? isFavorite) => _$this._isFavorite = isFavorite;

  String? _createdAt;
  String? get createdAt => _$this._createdAt;
  set createdAt(String? createdAt) => _$this._createdAt = createdAt;

  String? _updatedAt;
  String? get updatedAt => _$this._updatedAt;
  set updatedAt(String? updatedAt) => _$this._updatedAt = updatedAt;

  ListBuilder<ChapterSyncData>? _chapters;
  ListBuilder<ChapterSyncData> get chapters =>
      _$this._chapters ??= ListBuilder<ChapterSyncData>();
  set chapters(ListBuilder<ChapterSyncData>? chapters) =>
      _$this._chapters = chapters;

  ListBuilder<CharacterSyncData>? _characters;
  ListBuilder<CharacterSyncData> get characters =>
      _$this._characters ??= ListBuilder<CharacterSyncData>();
  set characters(ListBuilder<CharacterSyncData>? characters) =>
      _$this._characters = characters;

  ListBuilder<CharacterRelationSyncData>? _characterRelations;
  ListBuilder<CharacterRelationSyncData> get characterRelations =>
      _$this._characterRelations ??= ListBuilder<CharacterRelationSyncData>();
  set characterRelations(
          ListBuilder<CharacterRelationSyncData>? characterRelations) =>
      _$this._characterRelations = characterRelations;

  ListBuilder<OutlineSyncData>? _outlines;
  ListBuilder<OutlineSyncData> get outlines =>
      _$this._outlines ??= ListBuilder<OutlineSyncData>();
  set outlines(ListBuilder<OutlineSyncData>? outlines) =>
      _$this._outlines = outlines;

  NovelSyncDataBuilder() {
    NovelSyncData._defaults(this);
  }

  NovelSyncDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _novelId = $v.novelId;
      _title = $v.title;
      _author = $v.author;
      _description = $v.description;
      _coverUrl = $v.coverUrl;
      _sourceUrl = $v.sourceUrl;
      _totalChapters = $v.totalChapters;
      _totalWords = $v.totalWords;
      _lastReadChapterId = $v.lastReadChapterId;
      _lastReadPosition = $v.lastReadPosition;
      _isFavorite = $v.isFavorite;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _chapters = $v.chapters?.toBuilder();
      _characters = $v.characters?.toBuilder();
      _characterRelations = $v.characterRelations?.toBuilder();
      _outlines = $v.outlines?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(NovelSyncData other) {
    _$v = other as _$NovelSyncData;
  }

  @override
  void update(void Function(NovelSyncDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  NovelSyncData build() => _build();

  _$NovelSyncData _build() {
    _$NovelSyncData _$result;
    try {
      _$result = _$v ??
          _$NovelSyncData._(
            novelId: BuiltValueNullFieldError.checkNotNull(
                novelId, r'NovelSyncData', 'novelId'),
            title: BuiltValueNullFieldError.checkNotNull(
                title, r'NovelSyncData', 'title'),
            author: author,
            description: description,
            coverUrl: coverUrl,
            sourceUrl: sourceUrl,
            totalChapters: totalChapters,
            totalWords: totalWords,
            lastReadChapterId: lastReadChapterId,
            lastReadPosition: lastReadPosition,
            isFavorite: isFavorite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            chapters: _chapters?.build(),
            characters: _characters?.build(),
            characterRelations: _characterRelations?.build(),
            outlines: _outlines?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'chapters';
        _chapters?.build();
        _$failedField = 'characters';
        _characters?.build();
        _$failedField = 'characterRelations';
        _characterRelations?.build();
        _$failedField = 'outlines';
        _outlines?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'NovelSyncData', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
