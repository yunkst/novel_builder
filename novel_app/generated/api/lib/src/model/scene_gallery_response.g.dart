// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene_gallery_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SceneGalleryResponse extends SceneGalleryResponse {
  @override
  final String taskId;
  @override
  final BuiltList<String> images;

  factory _$SceneGalleryResponse(
          [void Function(SceneGalleryResponseBuilder)? updates]) =>
      (SceneGalleryResponseBuilder()..update(updates))._build();

  _$SceneGalleryResponse._({required this.taskId, required this.images})
      : super._();
  @override
  SceneGalleryResponse rebuild(
          void Function(SceneGalleryResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SceneGalleryResponseBuilder toBuilder() =>
      SceneGalleryResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SceneGalleryResponse &&
        taskId == other.taskId &&
        images == other.images;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, taskId.hashCode);
    _$hash = $jc(_$hash, images.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SceneGalleryResponse')
          ..add('taskId', taskId)
          ..add('images', images))
        .toString();
  }
}

class SceneGalleryResponseBuilder
    implements Builder<SceneGalleryResponse, SceneGalleryResponseBuilder> {
  _$SceneGalleryResponse? _$v;

  String? _taskId;
  String? get taskId => _$this._taskId;
  set taskId(String? taskId) => _$this._taskId = taskId;

  ListBuilder<String>? _images;
  ListBuilder<String> get images => _$this._images ??= ListBuilder<String>();
  set images(ListBuilder<String>? images) => _$this._images = images;

  SceneGalleryResponseBuilder() {
    SceneGalleryResponse._defaults(this);
  }

  SceneGalleryResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _taskId = $v.taskId;
      _images = $v.images.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SceneGalleryResponse other) {
    _$v = other as _$SceneGalleryResponse;
  }

  @override
  void update(void Function(SceneGalleryResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SceneGalleryResponse build() => _build();

  _$SceneGalleryResponse _build() {
    _$SceneGalleryResponse _$result;
    try {
      _$result = _$v ??
          _$SceneGalleryResponse._(
            taskId: BuiltValueNullFieldError.checkNotNull(
                taskId, r'SceneGalleryResponse', 'taskId'),
            images: images.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'images';
        images.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'SceneGalleryResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
