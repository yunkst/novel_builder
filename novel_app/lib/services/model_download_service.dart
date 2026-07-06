import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/model_download_task.dart';
import 'api_service_wrapper.dart';
import '../repositories/model_download_repository.dart';

/// 模型下载/上传服务
///
/// 负责：
/// - 从外站 URL 下载文件到本地（支持 Range 续传 + 取消）
/// - 分块上传到 backend `/app/models/<subdir>/`（支持断点续传 + 取消）
/// - 任务状态持久化到 SQLite，跨 app 重启续传
///
/// 调用方通过 [ModelDownloadNotifier] 间接使用本服务。
class ModelDownloadService {
  static const int _chunkSize = 5 * 1024 * 1024; // 5MB

  final ApiServiceWrapper _apiService;
  final ModelDownloadRepository _repository;
  final Dio _downloadDio;

  /// 进行中的下载 CancelToken（taskId -> token）
  final Map<String, CancelToken> _downloadCancelTokens = {};

  /// 进行中的上传 CancelToken（taskId -> token）
  final Map<String, CancelToken> _uploadCancelTokens = {};

  /// 上传任务的暂停标志（taskId -> 是否请求暂停）
  final Map<String, bool> _uploadPauseFlags = {};

  /// 下载字节数落库节流：{taskId -> 上次落库时间ms, 上次字节数}
  final Map<String, _DownloadProgressTracker> _downloadTrackers = {};

  /// 下载完成回调（Notifier 监听用）
  final StreamController<ModelDownloadTask> _taskChangedController =
      StreamController<ModelDownloadTask>.broadcast();
  Stream<ModelDownloadTask> get taskChanged => _taskChangedController.stream;

  /// 单调递增计数器，用于生成任务 id
  int _idCounter = 0;

  ModelDownloadService({
    required ApiServiceWrapper apiService,
    required ModelDownloadRepository repository,
    Dio? downloadDio,
  })  : _apiService = apiService,
        _repository = repository,
        _downloadDio = downloadDio ?? Dio();

  String _newId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    _idCounter += 1;
    return 'mdl_${ts}_$_idCounter';
  }

  /// 模型下载文件本地存储目录
  Future<Directory> _storageDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'model_downloads'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 创建一个新任务并立即开始下载
  Future<ModelDownloadTask> createTask({
    required String url,
    required String filename,
    required String targetSubdir,
    String? sourcePage,
  }) async {
    final dir = await _storageDir();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _newId();
    final localPath = p.join(dir.path, '$id.part');
    final task = ModelDownloadTask(
      id: id,
      url: url,
      filename: filename,
      targetSubdir: targetSubdir,
      status: ModelDownloadStatus.downloading,
      localPath: localPath,
      sourcePage: sourcePage,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.insert(task);
    _emit(task);
    // 异步启动下载
    _startDownload(task);
    return task;
  }

  /// 启动/继续下载（Range 续传）
  Future<void> _startDownload(ModelDownloadTask task) async {
    final cancelToken = CancelToken();
    _downloadCancelTokens[task.id] = cancelToken;
    _downloadTrackers[task.id] = _DownloadProgressTracker();

    try {
      final file = File(task.localPath);
      final startByte = task.downloadedBytes;

      // 获取文件总大小（如果还没有），并确定 Range 头
      final headers = <String, dynamic>{};
      if (startByte > 0) {
        headers['Range'] = 'bytes=$startByte-';
      }

      final response = await _downloadDio.get(
        task.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          receiveTimeout: const Duration(minutes: 30),
        ),
        cancelToken: cancelToken,
      );

      // 解析总大小
      int totalSize = task.totalSize;
      final contentRange =
          response.headers.value('content-range');
      final contentLength =
          response.headers.value('content-length');
      if (contentRange != null) {
        // bytes start-end/total
        final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
        if (match != null) {
          totalSize = int.parse(match.group(1)!);
        }
      } else if (contentLength != null && startByte == 0) {
        totalSize = int.tryParse(contentLength) ?? 0;
      }

      // 更新 totalSize（首次拿到）
      var current = task.copyWith(totalSize: totalSize > 0 ? totalSize : task.totalSize);
      await _repository.update(current);
      _emit(current);

      final sink = file.openWrite(mode: FileMode.append);
      int received = startByte;
      final completer = Completer<void>();

      response.data?.stream.listen(
        (List<int> chunk) {
          sink.add(chunk);
          received += chunk.length;
          final tracker = _downloadTrackers[task.id];
          if (tracker != null && tracker.shouldFlush(received)) {
            // 异步落库，避免阻塞下载循环
            _repository.updateDownloadedBytes(
              task.id,
              received,
              DateTime.now().millisecondsSinceEpoch,
            );
            _emit(current.copyWith(downloadedBytes: received));
          }
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;

      // 下载完成
      _downloadCancelTokens.remove(task.id);
      _downloadTrackers.remove(task.id);

      // 去掉 .part 后缀，作为最终文件名
      final finalPath = task.localPath.replaceAll('.part', '');
      await file.rename(finalPath);
      final done = current.copyWith(
        downloadedBytes: received,
        totalSize: totalSize > 0 ? totalSize : received,
        status: ModelDownloadStatus.downloaded,
        localPath: finalPath,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repository.update(done);
      _emit(done);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // pause 或 cancel：状态已由调用方设置，无需再改
        return;
      }
      await _markFailed(task, e.message ?? '下载失败');
    } catch (e) {
      await _markFailed(task, e.toString());
    } finally {
      _downloadCancelTokens.remove(task.id);
      _downloadTrackers.remove(task.id);
    }
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    final token = _downloadCancelTokens[taskId];
    token?.cancel('pause');
    final task = await _repository.getById(taskId);
    if (task != null && task.status == ModelDownloadStatus.downloading) {
      final paused = task.copyWith(
        status: ModelDownloadStatus.downloadPaused,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repository.update(paused);
      _emit(paused);
    }
  }

  /// 继续下载
  Future<void> resumeDownload(String taskId) async {
    final task = await _repository.getById(taskId);
    if (task == null) return;
    if (task.status != ModelDownloadStatus.downloadPaused &&
        task.status != ModelDownloadStatus.failed) {
      return;
    }
    final running = task.copyWith(
      status: ModelDownloadStatus.downloading,
      errorMessage: null,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repository.update(running);
    _emit(running);
    _startDownload(running);
  }

  /// 开始上传（从已下载状态进入上传）
  Future<void> startUpload(String taskId) async {
    final task = await _repository.getById(taskId);
    if (task == null) return;
    if (task.status != ModelDownloadStatus.downloaded &&
        task.status != ModelDownloadStatus.uploadPaused &&
        task.status != ModelDownloadStatus.failed) {
      return;
    }

    final file = File(task.localPath);
    if (!await file.exists()) {
      await _markFailed(task, '本地文件不存在');
      return;
    }
    final totalSize = await file.length();
    final totalChunks =
        (totalSize / _chunkSize).ceil().clamp(1, 100000).toInt();

    // 初始化 backend 上传任务（若没有）
    String? uploadId = task.backendUploadId;
    if (uploadId == null || uploadId.isEmpty) {
      try {
        final initResp = await _apiService.initModelUpload(
          filename: task.filename,
          targetSubdir: task.targetSubdir,
          totalSize: totalSize,
          chunkSize: _chunkSize,
          totalChunks: totalChunks,
        );
        uploadId = initResp['upload_id'] as String;
      } catch (e) {
        await _markFailed(task, '初始化上传失败: $e');
        return;
      }
    }

    // 查询服务端已收块（断点续传）
    Set<int> received = {};
    try {
      final statusResp = await _apiService.getModelUploadStatus(uploadId: uploadId);
      final list = (statusResp['received_indices'] as List?) ?? [];
      received = list.map((e) => (e as num).toInt()).toSet();
    } catch (_) {
      // 忽略，按本地记录续传
    }

    final uploading = task.copyWith(
      status: ModelDownloadStatus.uploading,
      backendUploadId: uploadId,
      totalSize: totalSize,
      chunkSize: _chunkSize,
      totalChunks: totalChunks,
      uploadedChunkIndices: received.toList()..sort(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repository.update(uploading);
    _emit(uploading);

    _runUploadLoop(uploading, received);
  }

  /// 上传循环（在后台运行）
  Future<void> _runUploadLoop(
    ModelDownloadTask task,
    Set<int> alreadyReceived,
  ) async {
    final cancelToken = CancelToken();
    _uploadCancelTokens[task.id] = cancelToken;
    _uploadPauseFlags[task.id] = false;
    final file = File(task.localPath);
    final raf = await file.open();

    try {
      final Set<int> done = Set<int>.from(alreadyReceived);
      final total = task.totalChunks;

      for (int idx = 0; idx < total; idx++) {
        if (done.contains(idx)) continue;
        if (_uploadPauseFlags[task.id] == true) {
          // 暂停：保存当前进度
          final paused = await _repository.getById(task.id);
          if (paused != null) {
            final updated = paused.copyWith(
              status: ModelDownloadStatus.uploadPaused,
              uploadedChunkIndices: done.toList()..sort(),
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            );
            await _repository.update(updated);
            _emit(updated);
          }
          return;
        }
        if (cancelToken.isCancelled) return;

        // 定位并读取分块
        final start = idx * _chunkSize;
        await raf.setPosition(start);
        final remaining = task.totalSize - start;
        final readLen = remaining < _chunkSize ? remaining : _chunkSize;
        final bytes = await raf.read(readLen);

        try {
          await _apiService.uploadModelChunk(
            uploadId: task.backendUploadId!,
            index: idx,
            chunkBytes: bytes,
            cancelToken: cancelToken,
          );
          done.add(idx);
          // 落库当前进度
          await _repository.updateUploadState(
            task.id,
            status: ModelDownloadStatus.uploading.name,
            uploadedChunkIndices: done.toList()..sort(),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          final cur = await _repository.getById(task.id);
          if (cur != null) _emit(cur.copyWith());
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) {
            return;
          }
          // 单块失败：标记为 paused（可继续）或 failed
          final paused = await _repository.getById(task.id);
          if (paused != null) {
            final updated = paused.copyWith(
              status: ModelDownloadStatus.uploadPaused,
              uploadedChunkIndices: done.toList()..sort(),
              errorMessage: '上传分块 $idx 失败: ${e.message}',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            );
            await _repository.update(updated);
            _emit(updated);
          }
          return;
        }
      }

      // 全部上传完成 → 合并
      if (done.length == total) {
        await _apiService.completeModelUpload(uploadId: task.backendUploadId!);
        // 删本地文件
        try {
          await file.delete();
        } catch (_) {}
        final completed = task.copyWith(
          status: ModelDownloadStatus.completed,
          uploadedChunkIndices: done.toList()..sort(),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _repository.update(completed);
        _emit(completed);
        // 完成后删表记录（UI 列表只看活跃任务）
        await Future.delayed(const Duration(seconds: 2));
        await _repository.delete(task.id);
      }
    } catch (e) {
      await _markFailed(task, '上传失败: $e');
    } finally {
      await raf.close();
      _uploadCancelTokens.remove(task.id);
      _uploadPauseFlags.remove(task.id);
    }
  }

  /// 暂停上传
  Future<void> pauseUpload(String taskId) async {
    _uploadPauseFlags[taskId] = true;
    final task = await _repository.getById(taskId);
    if (task != null && task.status == ModelDownloadStatus.uploading) {
      // 实际状态在循环下次迭代时落地
      final paused = task.copyWith(
        status: ModelDownloadStatus.uploadPaused,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _repository.update(paused);
      _emit(paused);
    }
  }

  /// 继续上传
  Future<void> resumeUpload(String taskId) async {
    await startUpload(taskId);
  }

  /// 删除任务（任意阶段）
  ///
  /// - 取消进行中的下载/上传
  /// - 删除本地文件（.part 或完整文件）
  /// - 通知 backend 删除临时分块
  /// - 删除表记录
  Future<void> deleteTask(String taskId) async {
    final task = await _repository.getById(taskId);
    if (task == null) return;

    // 取消下载
    _downloadCancelTokens[taskId]?.cancel('delete');
    // 取消上传
    _uploadCancelTokens[taskId]?.cancel('delete');
    _uploadPauseFlags[taskId] = true;

    // 删本地文件
    try {
      final file = File(task.localPath);
      if (await file.exists()) {
        await file.delete();
      }
      // 兜底删 .part
      final partFile = File('${task.localPath}.part');
      if (await partFile.exists()) {
        await partFile.delete();
      }
    } catch (_) {}

    // 通知 backend 删临时分块
    if (task.backendUploadId != null && task.backendUploadId!.isNotEmpty) {
      try {
        await _apiService.cancelModelUpload(uploadId: task.backendUploadId!);
      } catch (_) {}
    }

    await _repository.delete(taskId);
    _emit(task.copyWith(status: ModelDownloadStatus.cancelled));
  }

  /// 取消任务（语义等同于删除，但保留 cancelled 状态展示）
  Future<void> cancelTask(String taskId) async {
    await deleteTask(taskId);
  }

  /// 启动时恢复：把 downloading/uploading 重置为对应 Paused
  Future<List<ModelDownloadTask>> restoreFromDb() async {
    final tasks = await _repository.getActiveTasks();
    for (final t in tasks) {
      if (t.status == ModelDownloadStatus.downloading) {
        final paused = t.copyWith(
          status: ModelDownloadStatus.downloadPaused,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _repository.update(paused);
      } else if (t.status == ModelDownloadStatus.uploading) {
        final paused = t.copyWith(
          status: ModelDownloadStatus.uploadPaused,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _repository.update(paused);
      }
    }
    return _repository.getActiveTasks();
  }

  Future<void> _markFailed(ModelDownloadTask task, String message) async {
    final failed = task.copyWith(
      status: ModelDownloadStatus.failed,
      errorMessage: message,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repository.update(failed);
    _emit(failed);
  }

  void _emit(ModelDownloadTask task) {
    if (!_taskChangedController.isClosed) {
      _taskChangedController.add(task);
    }
  }

  void dispose() {
    for (final t in _downloadCancelTokens.values) {
      t.cancel('dispose');
    }
    for (final t in _uploadCancelTokens.values) {
      t.cancel('dispose');
    }
    _taskChangedController.close();
  }
}

/// 下载进度落库节流
class _DownloadProgressTracker {
  int _lastFlushedBytes = 0;
  DateTime _lastFlushedTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool shouldFlush(int currentBytes) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastFlushedTime).inMilliseconds;
    if (currentBytes - _lastFlushedBytes >= 1024 * 512 || elapsed >= 1000) {
      _lastFlushedBytes = currentBytes;
      _lastFlushedTime = now;
      return true;
    }
    return false;
  }
}
