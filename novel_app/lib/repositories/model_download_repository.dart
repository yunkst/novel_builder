/// ComfyUI 模型下载/上传任务 Repository
///
/// 提供 model_download_tasks 表的 CRUD 操作。
/// 遵循项目 Repository 模式，继承 BaseRepository。
library;

import 'package:sqflite/sqflite.dart';
import '../models/model_download_task.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';

class ModelDownloadRepository extends BaseRepository {
  ModelDownloadRepository({required super.dbConnection});

  /// 插入新任务
  Future<void> insert(ModelDownloadTask task) async {
    try {
      final db = await database;
      await db.insert(
        'model_download_tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '插入模型下载任务失败: ${task.id} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['model_download', 'insert', 'failed'],
      );
      rethrow;
    }
  }

  /// 更新整个任务（按 id）
  Future<void> update(ModelDownloadTask task) async {
    try {
      final db = await database;
      await db.update(
        'model_download_tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新模型下载任务失败: ${task.id} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['model_download', 'update', 'failed'],
      );
      rethrow;
    }
  }

  /// 删除任务
  Future<void> delete(String id) async {
    try {
      final db = await database;
      await db.delete(
        'model_download_tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除模型下载任务失败: $id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['model_download', 'delete', 'failed'],
      );
      rethrow;
    }
  }

  /// 按 id 查询
  Future<ModelDownloadTask?> getById(String id) async {
    try {
      final db = await database;
      final results = await db.query(
        'model_download_tasks',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return ModelDownloadTask.fromMap(results.first);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询模型下载任务失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['model_download', 'get_by_id', 'failed'],
      );
      rethrow;
    }
  }

  /// 查询所有未完成任务（completed/cancelled 不返回）
  Future<List<ModelDownloadTask>> getActiveTasks() async {
    try {
      final db = await database;
      final results = await db.query(
        'model_download_tasks',
        where: 'status NOT IN (?, ?)',
        whereArgs: [
          ModelDownloadStatus.completed.name,
          ModelDownloadStatus.cancelled.name,
        ],
        orderBy: 'createdAt DESC',
      );
      return results.map(ModelDownloadTask.fromMap).toList();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询活跃模型下载任务失败 - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['model_download', 'get_active', 'failed'],
      );
      rethrow;
    }
  }

  /// 仅更新已下载字节数（高频调用，避免整对象序列化）
  Future<void> updateDownloadedBytes(
    String id,
    int downloadedBytes,
    int updatedAt,
  ) async {
    try {
      final db = await database;
      await db.update(
        'model_download_tasks',
        {
          'downloadedBytes': downloadedBytes,
          'updatedAt': updatedAt,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新下载字节数失败: $id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['model_download', 'update_bytes', 'failed'],
      );
      rethrow;
    }
  }

  /// 更新上传相关字段
  Future<void> updateUploadState(
    String id, {
    required String status,
    required List<int> uploadedChunkIndices,
    String? backendUploadId,
    int? totalSize,
    int? chunkSize,
    int? totalChunks,
    int? updatedAt,
  }) async {
    try {
      final db = await database;
      final values = <String, dynamic>{
        'status': status,
        'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      };
      // 上传字段存 JSON
      values['uploadedChunkIndicesJson'] =
          '[${uploadedChunkIndices.join(',')}]';
      if (backendUploadId != null) values['backendUploadId'] = backendUploadId;
      if (totalSize != null) values['totalSize'] = totalSize;
      if (chunkSize != null) values['chunkSize'] = chunkSize;
      if (totalChunks != null) values['totalChunks'] = totalChunks;
      await db.update(
        'model_download_tasks',
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新上传状态失败: $id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['model_download', 'update_upload', 'failed'],
      );
      rethrow;
    }
  }
}
