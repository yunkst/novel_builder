import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/model_download_task.dart';
import '../../services/model_download_service.dart';
import 'database_providers.dart';
import 'services/network_service_providers.dart';

/// 模型下载/上传任务列表状态
class ModelDownloadState {
  final List<ModelDownloadTask> tasks;
  final bool isLoading;

  const ModelDownloadState({
    this.tasks = const [],
    this.isLoading = false,
  });

  ModelDownloadState copyWith({
    List<ModelDownloadTask>? tasks,
    bool? isLoading,
  }) {
    return ModelDownloadState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// [ModelDownloadService] Provider
final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  final repository = ref.watch(modelDownloadRepositoryProvider);
  final service = ModelDownloadService(
    apiService: apiService,
    repository: repository,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// 模型下载/上传任务状态管理
class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  final ModelDownloadService _service;
  StreamSubscription<ModelDownloadTask>? _sub;

  ModelDownloadNotifier(this._service) : super(const ModelDownloadState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final tasks = await _service.restoreFromDb();
      state = ModelDownloadState(tasks: tasks, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
    _sub = _service.taskChanged.listen(_onTaskChanged);
  }

  void _onTaskChanged(ModelDownloadTask task) {
    final tasks = List<ModelDownloadTask>.from(state.tasks);
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      // cancelled / completed 的任务从列表移除
      if (task.status == ModelDownloadStatus.cancelled ||
          task.status == ModelDownloadStatus.completed) {
        tasks.removeAt(idx);
      } else {
        tasks[idx] = task;
      }
    } else if (task.status != ModelDownloadStatus.cancelled &&
        task.status != ModelDownloadStatus.completed) {
      tasks.insert(0, task);
    }
    state = state.copyWith(tasks: tasks);
  }

  Future<void> refresh() async {
    final tasks = await _service.restoreFromDb();
    state = state.copyWith(tasks: tasks);
  }

  Future<void> createTask({
    required String url,
    required String filename,
    required String targetSubdir,
    String? sourcePage,
  }) async {
    await _service.createTask(
      url: url,
      filename: filename,
      targetSubdir: targetSubdir,
      sourcePage: sourcePage,
    );
  }

  Future<void> pause(String taskId) async {
    final task =
        state.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    if (task.isDownloadPhase) {
      await _service.pauseDownload(taskId);
    } else if (task.isUploadPhase) {
      await _service.pauseUpload(taskId);
    }
  }

  Future<void> resume(String taskId) async {
    final task =
        state.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    if (task.status == ModelDownloadStatus.downloadPaused ||
        task.status == ModelDownloadStatus.failed && task.isDownloadPhase) {
      await _service.resumeDownload(taskId);
    } else if (task.status == ModelDownloadStatus.downloaded) {
      await _service.startUpload(taskId);
    } else if (task.status == ModelDownloadStatus.uploadPaused ||
        (task.status == ModelDownloadStatus.failed && task.isUploadPhase)) {
      await _service.resumeUpload(taskId);
    } else if (task.status == ModelDownloadStatus.failed) {
      await _service.resumeDownload(taskId);
    }
  }

  Future<void> startUpload(String taskId) async {
    await _service.startUpload(taskId);
  }

  Future<void> deleteTask(String taskId) async {
    await _service.deleteTask(taskId);
  }

  Future<void> cancel(String taskId) async {
    await _service.cancelTask(taskId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// 模型下载/上传任务 Provider
final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
  final service = ref.watch(modelDownloadServiceProvider);
  return ModelDownloadNotifier(service);
});
