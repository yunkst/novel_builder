// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_to_video_task_status_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ImageToVideoTaskStatusResponse extends ImageToVideoTaskStatusResponse {
  @override
  final int taskId;
  @override
  final String imgName;
  @override
  final String status;
  @override
  final String? modelName;
  @override
  final String userInput;
  @override
  final String? videoPrompt;
  @override
  final String? videoFilename;
  @override
  final String? resultMessage;
  @override
  final String? errorMessage;
  @override
  final String createdAt;
  @override
  final String? startedAt;
  @override
  final String? completedAt;

  factory _$ImageToVideoTaskStatusResponse(
          [void Function(ImageToVideoTaskStatusResponseBuilder)? updates]) =>
      (ImageToVideoTaskStatusResponseBuilder()..update(updates))._build();

  _$ImageToVideoTaskStatusResponse._(
      {required this.taskId,
      required this.imgName,
      required this.status,
      this.modelName,
      required this.userInput,
      this.videoPrompt,
      this.videoFilename,
      this.resultMessage,
      this.errorMessage,
      required this.createdAt,
      this.startedAt,
      this.completedAt})
      : super._();
  @override
  ImageToVideoTaskStatusResponse rebuild(
          void Function(ImageToVideoTaskStatusResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ImageToVideoTaskStatusResponseBuilder toBuilder() =>
      ImageToVideoTaskStatusResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ImageToVideoTaskStatusResponse &&
        taskId == other.taskId &&
        imgName == other.imgName &&
        status == other.status &&
        modelName == other.modelName &&
        userInput == other.userInput &&
        videoPrompt == other.videoPrompt &&
        videoFilename == other.videoFilename &&
        resultMessage == other.resultMessage &&
        errorMessage == other.errorMessage &&
        createdAt == other.createdAt &&
        startedAt == other.startedAt &&
        completedAt == other.completedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, taskId.hashCode);
    _$hash = $jc(_$hash, imgName.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, modelName.hashCode);
    _$hash = $jc(_$hash, userInput.hashCode);
    _$hash = $jc(_$hash, videoPrompt.hashCode);
    _$hash = $jc(_$hash, videoFilename.hashCode);
    _$hash = $jc(_$hash, resultMessage.hashCode);
    _$hash = $jc(_$hash, errorMessage.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, startedAt.hashCode);
    _$hash = $jc(_$hash, completedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ImageToVideoTaskStatusResponse')
          ..add('taskId', taskId)
          ..add('imgName', imgName)
          ..add('status', status)
          ..add('modelName', modelName)
          ..add('userInput', userInput)
          ..add('videoPrompt', videoPrompt)
          ..add('videoFilename', videoFilename)
          ..add('resultMessage', resultMessage)
          ..add('errorMessage', errorMessage)
          ..add('createdAt', createdAt)
          ..add('startedAt', startedAt)
          ..add('completedAt', completedAt))
        .toString();
  }
}

class ImageToVideoTaskStatusResponseBuilder
    implements
        Builder<ImageToVideoTaskStatusResponse,
            ImageToVideoTaskStatusResponseBuilder> {
  _$ImageToVideoTaskStatusResponse? _$v;

  int? _taskId;
  int? get taskId => _$this._taskId;
  set taskId(int? taskId) => _$this._taskId = taskId;

  String? _imgName;
  String? get imgName => _$this._imgName;
  set imgName(String? imgName) => _$this._imgName = imgName;

  String? _status;
  String? get status => _$this._status;
  set status(String? status) => _$this._status = status;

  String? _modelName;
  String? get modelName => _$this._modelName;
  set modelName(String? modelName) => _$this._modelName = modelName;

  String? _userInput;
  String? get userInput => _$this._userInput;
  set userInput(String? userInput) => _$this._userInput = userInput;

  String? _videoPrompt;
  String? get videoPrompt => _$this._videoPrompt;
  set videoPrompt(String? videoPrompt) => _$this._videoPrompt = videoPrompt;

  String? _videoFilename;
  String? get videoFilename => _$this._videoFilename;
  set videoFilename(String? videoFilename) =>
      _$this._videoFilename = videoFilename;

  String? _resultMessage;
  String? get resultMessage => _$this._resultMessage;
  set resultMessage(String? resultMessage) =>
      _$this._resultMessage = resultMessage;

  String? _errorMessage;
  String? get errorMessage => _$this._errorMessage;
  set errorMessage(String? errorMessage) => _$this._errorMessage = errorMessage;

  String? _createdAt;
  String? get createdAt => _$this._createdAt;
  set createdAt(String? createdAt) => _$this._createdAt = createdAt;

  String? _startedAt;
  String? get startedAt => _$this._startedAt;
  set startedAt(String? startedAt) => _$this._startedAt = startedAt;

  String? _completedAt;
  String? get completedAt => _$this._completedAt;
  set completedAt(String? completedAt) => _$this._completedAt = completedAt;

  ImageToVideoTaskStatusResponseBuilder() {
    ImageToVideoTaskStatusResponse._defaults(this);
  }

  ImageToVideoTaskStatusResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _taskId = $v.taskId;
      _imgName = $v.imgName;
      _status = $v.status;
      _modelName = $v.modelName;
      _userInput = $v.userInput;
      _videoPrompt = $v.videoPrompt;
      _videoFilename = $v.videoFilename;
      _resultMessage = $v.resultMessage;
      _errorMessage = $v.errorMessage;
      _createdAt = $v.createdAt;
      _startedAt = $v.startedAt;
      _completedAt = $v.completedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ImageToVideoTaskStatusResponse other) {
    _$v = other as _$ImageToVideoTaskStatusResponse;
  }

  @override
  void update(void Function(ImageToVideoTaskStatusResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ImageToVideoTaskStatusResponse build() => _build();

  _$ImageToVideoTaskStatusResponse _build() {
    final _$result = _$v ??
        _$ImageToVideoTaskStatusResponse._(
          taskId: BuiltValueNullFieldError.checkNotNull(
              taskId, r'ImageToVideoTaskStatusResponse', 'taskId'),
          imgName: BuiltValueNullFieldError.checkNotNull(
              imgName, r'ImageToVideoTaskStatusResponse', 'imgName'),
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'ImageToVideoTaskStatusResponse', 'status'),
          modelName: modelName,
          userInput: BuiltValueNullFieldError.checkNotNull(
              userInput, r'ImageToVideoTaskStatusResponse', 'userInput'),
          videoPrompt: videoPrompt,
          videoFilename: videoFilename,
          resultMessage: resultMessage,
          errorMessage: errorMessage,
          createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt, r'ImageToVideoTaskStatusResponse', 'createdAt'),
          startedAt: startedAt,
          completedAt: completedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
