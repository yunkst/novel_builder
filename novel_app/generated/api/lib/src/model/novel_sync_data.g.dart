// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel_sync_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$NovelSyncData extends NovelSyncData {
  @override
  final String title;
  @override
  final String? author;
  @override
  final String? description;
  @override
  final String? coverUrl;
  @override
  final String? backgroundSetting;
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
      {required this.title,
      this.author,
      this.description,
      this.coverUrl,
      this.backgroundSetting,
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
        title == other.title &&
        author == other.author &&
        description == other.description &&
        coverUrl == other.coverUrl &&
        backgroundSetting == other.backgroundSetting &&
        chapters == other.chapters &&
        characters == other.characters &&
        characterRelations == other.characterRelations &&
        outlines == other.outlines;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, author.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, coverUrl.hashCode);
    _$hash = $jc(_$hash, backgroundSetting.hashCode);
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
          ..add('title', title)
          ..add('author', author)
          ..add('description', description)
          ..add('coverUrl', coverUrl)
          ..add('backgroundSetting', backgroundSetting)
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

  String? _backgroundSetting;
  String? get backgroundSetting => _$this._backgroundSetting;
  set backgroundSetting(String? backgroundSetting) =>
      _$this._backgroundSetting = backgroundSetting;

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
      _title = $v.title;
      _author = $v.author;
      _description = $v.description;
      _coverUrl = $v.coverUrl;
      _backgroundSetting = $v.backgroundSetting;
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
            title: BuiltValueNullFieldError.checkNotNull(
                title, r'NovelSyncData', 'title'),
            author: author,
            description: description,
            coverUrl: coverUrl,
            backgroundSetting: backgroundSetting,
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
