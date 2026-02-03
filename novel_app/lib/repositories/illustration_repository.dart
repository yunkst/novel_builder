import '../models/scene_illustration.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';
import '../core/interfaces/repositories/i_illustration_repository.dart';

/// 插图数据仓库
///
/// 负责场景插图的数据库操作，包括：
/// - 插图CRUD操作
/// - 插图路径管理
/// - 插图查询和搜索
/// - 章节插图关联
class IllustrationRepository extends BaseRepository
    implements IIllustrationRepository {
  /// 构造函数 - 接受数据库连接实例
  IllustrationRepository({required super.dbConnection});

  // ========== CRUD操作 ==========

  /// 插入场景插图记录
  ///
  /// 将新的场景插图任务插入数据库
  ///
  /// 参数:
  /// - [illustration] 场景插图对象，包含任务信息
  ///
  /// 返回: 新插入记录的ID
  @override
  Future<int> insertSceneIllustration(SceneIllustration illustration) async {
    try {
      final db = await database;
      final result = await db.insert(
        'scene_illustrations',
        illustration.toMap(),
      );

      LoggerService.instance.i(
        '插入场景插图成功: ${illustration.taskId}',
        category: LogCategory.database,
        tags: ['illustration', 'insert', 'success'],
      );

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '插入场景插图失败: ${illustration.taskId} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'insert', 'failed'],
      );
      rethrow;
    }
  }

  /// 更新场景插图状态
  ///
  /// 更新插图的处理状态，可选择更新图片路径和提示词
  ///
  /// 参数:
  /// - [id] 插图记录ID
  /// - [status] 新状态（pending/processing/completed/failed）
  /// - [images] 可选，图片路径列表
  /// - [prompts] 可选，生成提示词
  ///
  /// 返回: 受影响的行数
  @override
  Future<int> updateSceneIllustrationStatus(
    int id,
    String status, {
    List<String>? images,
    String? prompts,
  }) async {
    try {
      final db = await database;
      final Map<String, dynamic> updateData = {
        'status': status,
        'completed_at':
            status == 'completed' ? DateTime.now().toIso8601String() : null,
      };

      if (images != null) {
        updateData['images'] = images.join(',');
      }

      if (prompts != null) {
        updateData['prompts'] = prompts;
      }

      final result = await db.update(
        'scene_illustrations',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );

      LoggerService.instance.i(
        '更新场景插图状态成功: id=$id, status=$status',
        category: LogCategory.database,
        tags: ['illustration', 'update', 'success'],
      );

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新场景插图状态失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'update', 'failed'],
      );
      rethrow;
    }
  }

  /// 删除场景插图记录
  ///
  /// 根据ID删除单条插图记录
  ///
  /// 参数:
  /// - [id] 插图记录ID
  ///
  /// 返回: 受影响的行数
  @override
  Future<int> deleteSceneIllustration(int id) async {
    try {
      final db = await database;
      final result = await db.delete(
        'scene_illustrations',
        where: 'id = ?',
        whereArgs: [id],
      );

      LoggerService.instance.i(
        '删除场景插图成功: id=$id',
        category: LogCategory.database,
        tags: ['illustration', 'delete', 'success'],
      );

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除场景插图失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'delete', 'failed'],
      );
      rethrow;
    }
  }

  /// 删除章节的所有场景插图
  ///
  /// 批量删除指定小说和章节的所有插图记录
  ///
  /// 参数:
  /// - [novelUrl] 小说URL
  /// - [chapterId] 章节ID
  ///
  /// 返回: 受影响的行数
  @override
  Future<int> deleteSceneIllustrationsByChapter(
    String novelUrl,
    String chapterId,
  ) async {
    try {
      final db = await database;
      final result = await db.delete(
        'scene_illustrations',
        where: 'novel_url = ? AND chapter_id = ?',
        whereArgs: [novelUrl, chapterId],
      );

      LoggerService.instance.i(
        '删除章节插图成功: novelUrl=$novelUrl, chapterId=$chapterId, count=$result',
        category: LogCategory.database,
        tags: ['illustration', 'delete', 'success'],
      );

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除章节插图失败: novelUrl=$novelUrl, chapterId=$chapterId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'delete', 'failed'],
      );
      rethrow;
    }
  }

  // ========== 查询操作 ==========

  /// 根据小说和章节获取场景插图列表
  ///
  /// 获取指定小说和章节的所有插图记录，按创建时间升序排列
  ///
  /// 参数:
  /// - [novelUrl] 小说URL
  /// - [chapterId] 章节ID
  ///
  /// 返回: 插图列表
  @override
  Future<List<SceneIllustration>> getSceneIllustrationsByChapter(
    String novelUrl,
    String chapterId,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scene_illustrations',
        where: 'novel_url = ? AND chapter_id = ?',
        whereArgs: [novelUrl, chapterId],
        orderBy: 'created_at ASC',
      );

      return List.generate(maps.length, (i) {
        return SceneIllustration.fromMap(maps[i]);
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询章节插图失败: novelUrl=$novelUrl, chapterId=$chapterId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'query', 'failed'],
      );
      rethrow;
    }
  }

  /// 根据taskId获取场景插图
  ///
  /// 通过任务ID查询单条插图记录
  ///
  /// 参数:
  /// - [taskId] 任务ID
  ///
  /// 返回: 插图对象，不存在时返回null
  @override
  Future<SceneIllustration?> getSceneIllustrationByTaskId(
    String taskId,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scene_illustrations',
        where: 'task_id = ?',
        whereArgs: [taskId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return SceneIllustration.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询插图失败: taskId=$taskId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'query', 'failed'],
      );
      rethrow;
    }
  }

  /// 根据ID获取场景插图
  ///
  /// 通过记录ID查询单条插图记录
  ///
  /// 参数:
  /// - [id] 记录ID
  ///
  /// 返回: 插图对象，不存在时返回null
  Future<SceneIllustration?> getById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scene_illustrations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return SceneIllustration.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询插图失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'query', 'failed'],
      );
      rethrow;
    }
  }

  /// 获取分页的场景插图列表（带总数）
  ///
  /// 分页查询所有插图记录，按创建时间降序排列
  ///
  /// 参数:
  /// - [page] 页码（从0开始）
  /// - [limit] 每页数量
  ///
  /// 返回: 包含items、total、totalPages的Map
  @override
  Future<Map<String, dynamic>> getSceneIllustrationsPaginated({
    required int page,
    required int limit,
  }) async {
    try {
      final db = await database;
      final offset = page * limit;

      // 查询总数
      final List<Map<String, dynamic>> countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scene_illustrations',
      );
      final int total = countResult.first['count'] as int;
      final int totalPages = (total / limit).ceil();

      // 查询当前页数据
      final List<Map<String, dynamic>> maps = await db.query(
        'scene_illustrations',
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

      final List<SceneIllustration> items = List.generate(maps.length, (i) {
        return SceneIllustration.fromMap(maps[i]);
      });

      return {
        'items': items,
        'total': total,
        'totalPages': totalPages,
      };
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '分页查询插图失败: page=$page, limit=$limit - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'query', 'failed'],
      );
      rethrow;
    }
  }

  /// 获取所有待处理或正在处理的场景插图
  ///
  /// 查询所有pending和processing状态的插图，用于任务队列处理
  ///
  /// 返回: 待处理插图列表
  @override
  Future<List<SceneIllustration>> getPendingSceneIllustrations() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scene_illustrations',
        where: 'status IN (?, ?)',
        whereArgs: ['pending', 'processing'],
        orderBy: 'created_at ASC',
      );

      return List.generate(maps.length, (i) {
        return SceneIllustration.fromMap(maps[i]);
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询待处理插图失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'query', 'failed'],
      );
      rethrow;
    }
  }

  // ========== 批量操作 ==========

  /// 批量更新场景插图状态
  ///
  /// 批量更新多个插图记录的状态
  ///
  /// 参数:
  /// - [ids] 插图记录ID列表
  /// - [status] 新状态
  ///
  /// 返回: 受影响的行数
  @override
  Future<int> batchUpdateSceneIllustrations(
    List<int> ids,
    String status,
  ) async {
    try {
      final db = await database;
      int count = 0;

      for (final id in ids) {
        count += await db.update(
          'scene_illustrations',
          {
            'status': status,
            'completed_at':
                status == 'completed' ? DateTime.now().toIso8601String() : null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      LoggerService.instance.i(
        '批量更新插图状态成功: count=$count, status=$status',
        category: LogCategory.database,
        tags: ['illustration', 'batch_update', 'success'],
      );

      return count;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '批量更新插图状态失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'batch_update', 'failed'],
      );
      rethrow;
    }
  }

  // ========== 统计和辅助方法 ==========

  /// 获取指定小说的插图总数
  ///
  /// 参数:
  /// - [novelUrl] 小说URL
  ///
  /// 返回: 插图总数
  @override
  Future<int> getIllustrationCount(String novelUrl) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scene_illustrations WHERE novel_url = ?',
        [novelUrl],
      );
      return result.first['count'] as int;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取插图总数失败: novelUrl=$novelUrl - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'count', 'failed'],
      );
      rethrow;
    }
  }

  /// 获取指定章节的已完成插图数量
  ///
  /// 参数:
  /// - [novelUrl] 小说URL
  /// - [chapterId] 章节ID
  ///
  /// 返回: 已完成的插图数量
  @override
  Future<int> getCompletedIllustrationCount(
    String novelUrl,
    String chapterId,
  ) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scene_illustrations WHERE novel_url = ? AND chapter_id = ? AND status = ?',
        [novelUrl, chapterId, 'completed'],
      );
      return result.first['count'] as int;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取已完成插图数量失败: novelUrl=$novelUrl, chapterId=$chapterId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['illustration', 'count', 'failed'],
      );
      rethrow;
    }
  }

  /// 检查任务ID是否已存在
  ///
  /// 用于避免创建重复任务
  ///
  /// 参数:
  /// - [taskId] 任务ID
  ///
  /// 返回: true表示已存在，false表示不存在
  @override
  Future<bool> taskExists(String taskId) async {
    try {
      final result = await getSceneIllustrationByTaskId(taskId);
      return result != null;
    } catch (e) {
      return false;
    }
  }
}
