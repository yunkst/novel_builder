/// Novel Sync Providers
///
/// 此文件定义小说同步功能的 Riverpod 状态管理。
///
/// **功能**:
/// - 同步状态枚举定义
/// - 同步状态数据类
///
/// **依赖**:
/// - sync_service_providers.dart - 同步服务
///
/// **使用示例**:
/// ```dart
/// // 在对话框中使用 NovelSyncDialog
/// final result = await NovelSyncDialog.show(
///   context: context,
///   novel: novel,
///   operation: SyncOperation.upload,
/// );
/// ```
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../services/logger_service.dart';
import '../../services/novel_sync_service.dart';
import 'services/sync_service_providers.dart';

part 'novel_sync_providers.g.dart';

/// 同步状态枚举
enum SyncStatus {
  /// 空闲状态
  idle,

  /// 上传中
  uploading,

  /// 下载中
  downloading,

  /// 成功
  success,

  /// 错误
  error,
}

/// 同步状态数据类
class SyncState {
  /// 当前同步状态
  final SyncStatus status;

  /// 进度 (0.0 - 1.0)，暂时不使用，保留扩展
  final double progress;

  /// 错误信息
  final String? errorMessage;

  /// 同步结果数据
  final Map<String, dynamic>? resultData;

  /// 同步版本号
  final int? syncVersion;

  /// 同步时间
  final DateTime? syncedAt;

  const SyncState({
    this.status = SyncStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
    this.resultData,
    this.syncVersion,
    this.syncedAt,
  });

  /// 是否正在进行同步操作
  bool get isSyncing =>
      status == SyncStatus.uploading || status == SyncStatus.downloading;

  /// 是否同步成功
  bool get isSuccess => status == SyncStatus.success;

  /// 是否有错误
  bool get hasError => status == SyncStatus.error;

  /// 复制并更新状态
  SyncState copyWith({
    SyncStatus? status,
    double? progress,
    String? errorMessage,
    Map<String, dynamic>? resultData,
    int? syncVersion,
    DateTime? syncedAt,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resultData: clearResult ? null : (resultData ?? this.resultData),
      syncVersion: syncVersion ?? this.syncVersion,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// 重置为空闲状态
  SyncState reset() {
    return const SyncState();
  }
}

/// 同步操作类型
enum SyncOperation {
  /// 上传
  upload,

  /// 下载
  download,
}

/// 同步服务帮助类
///
/// 封装同步操作，便于在UI中使用
class SyncServiceHelper {
  final Ref _ref;

  SyncServiceHelper(this._ref);

  /// 获取同步服务实例
  NovelSyncService get _syncService => _ref.read(novelSyncServiceProvider);

  /// 上传小说到服务器
  ///
  /// [novel] 要上传的小说
  /// [forceOverwrite] 是否强制覆盖服务器数据
  ///
  /// 返回同步结果
  Future<SyncResult> uploadNovel(
    dynamic novel, {
    bool forceOverwrite = false,
  }) async {
    LoggerService.instance.d(
      '开始上传小说: forceOverwrite=$forceOverwrite',
      category: LogCategory.network,
      tags: ['provider', 'novel-sync', 'upload'],
    );
    try {
      final result = await _syncService.uploadNovel(novel, forceOverwrite: forceOverwrite);
      LoggerService.instance.i(
        '小说上传成功',
        category: LogCategory.ui,
        tags: ['provider', 'novel-sync', 'upload'],
      );
      return result;
    } catch (e, st) {
      LoggerService.instance.e(
        '上传小说失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.network,
        tags: ['provider', 'novel-sync', 'upload'],
      );
      rethrow;
    }
  }

  /// 从服务器下载小说
  ///
  /// [novel] 要下载的小说
  /// [deleteExisting] 是否删除本地现有数据后再导入
  ///
  /// 返回同步结果
  Future<SyncResult> downloadNovel(
    dynamic novel, {
    bool deleteExisting = true,
  }) async {
    LoggerService.instance.d(
      '开始下载小说: deleteExisting=$deleteExisting',
      category: LogCategory.network,
      tags: ['provider', 'novel-sync', 'download'],
    );
    try {
      final result = await _syncService.downloadNovel(novel, deleteExisting: deleteExisting);
      LoggerService.instance.i(
        '小说下载成功',
        category: LogCategory.ui,
        tags: ['provider', 'novel-sync', 'download'],
      );
      return result;
    } catch (e, st) {
      LoggerService.instance.e(
        '下载小说失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.network,
        tags: ['provider', 'novel-sync', 'download'],
      );
      rethrow;
    }
  }

  /// 获取已同步的小说列表
  Future<List<SyncedNovelInfo>> listSyncedNovels({
    int page = 1,
    int pageSize = 20,
  }) async {
    LoggerService.instance.d(
      '获取已同步小说列表: page=$page, pageSize=$pageSize',
      category: LogCategory.network,
      tags: ['provider', 'novel-sync', 'list'],
    );
    try {
      final result = await _syncService.listSyncedNovels(page: page, pageSize: pageSize);
      LoggerService.instance.i(
        '已同步小说列表获取成功: count=${result.length}',
        category: LogCategory.ui,
        tags: ['provider', 'novel-sync', 'list'],
      );
      return result;
    } catch (e, st) {
      LoggerService.instance.e(
        '获取已同步小说列表失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.network,
        tags: ['provider', 'novel-sync', 'list'],
      );
      rethrow;
    }
  }
}

/// 同步服务帮助类 Provider
///
/// 提供同步操作的便捷访问
@Riverpod(keepAlive: true)
SyncServiceHelper syncServiceHelper(Ref ref) {
  return SyncServiceHelper(ref);
}