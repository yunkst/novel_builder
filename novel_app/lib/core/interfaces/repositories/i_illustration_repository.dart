import '../../../models/scene_illustration.dart';

/// 插图数据仓库接口
///
/// 负责场景插图的数据库操作，包括：
/// - 插图CRUD操作
/// - 插图路径管理
/// - 插图查询和搜索
/// - 章节插图关联
abstract class IIllustrationRepository {
  // ========== CRUD操作 ==========

  /// 插入场景插图记录
  ///
  /// 将新的场景插图任务插入数据库
  ///
  /// 参数:
  /// - [illustration] 场景插图对象，包含任务信息
  ///
  /// 返回: 新插入记录的ID
  Future<int> insertSceneIllustration(SceneIllustration illustration);

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
  Future<int> updateSceneIllustrationStatus(
    int id,
    String status, {
    List<String>? images,
    String? prompts,
  });

  /// 删除场景插图记录
  ///
  /// 根据ID删除单条插图记录
  ///
  /// 参数:
  /// - [id] 插图记录ID
  ///
  /// 返回: 受影响的行数
  Future<int> deleteSceneIllustration(int id);

  /// 删除章节的所有场景插图
  ///
  /// 批量删除指定小说和章节的所有插图记录
  ///
  /// 参数:
  /// - [novelUrl] 小说URL
  /// - [chapterId] 章节ID
  ///
  /// 返回: 受影响的行数
  Future<int> deleteSceneIllustrationsByChapter(
    String novelUrl,
    String chapterId,
  );

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
  Future<List<SceneIllustration>> getSceneIllustrationsByChapter(
    String novelUrl,
    String chapterId,
  );

  /// 根据taskId获取场景插图
  ///
  /// 通过任务ID查询单条插图记录
  ///
  /// 参数:
  /// - [taskId] 任务ID
  ///
  /// 返回: 插图对象，不存在时返回null
  Future<SceneIllustration?> getSceneIllustrationByTaskId(String taskId);

  /// 获取分页的场景插图列表（带总数）
  ///
  /// 分页查询所有插图记录，按创建时间降序排列
  ///
  /// 参数:
  /// - [page] 页码（从0开始）
  /// - [limit] 每页数量
  ///
  /// 返回: 包含items、total、totalPages的Map
  Future<Map<String, dynamic>> getSceneIllustrationsPaginated({
    required int page,
    required int limit,
  });

  /// 获取所有待处理或正在处理的场景插图
  ///
  /// 查询所有pending和processing状态的插图，用于任务队列处理
  ///
  /// 返回: 待处理插图列表
  Future<List<SceneIllustration>> getPendingSceneIllustrations();

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
  Future<int> batchUpdateSceneIllustrations(
    List<int> ids,
    String status,
  );

  // ========== 统计和辅助方法 ==========

  /// 获取指定小说的插图总数
  ///
  /// 参数:
  /// - [novelUrl] 小说URL
  ///
  /// 返回: 插图总数
  Future<int> getIllustrationCount(String novelUrl);

  /// 获取指定章节的已完成插图数量
  ///
  /// 参数:
  /// - [novelUrl] 小说URL
  /// - [chapterId] 章节ID
  ///
  /// 返回: 已完成的插图数量
  Future<int> getCompletedIllustrationCount(
    String novelUrl,
    String chapterId,
  );

  /// 检查任务ID是否已存在
  ///
  /// 用于避免创建重复任务
  ///
  /// 参数:
  /// - [taskId] 任务ID
  ///
  /// 返回: true表示已存在，false表示不存在
  Future<bool> taskExists(String taskId);
}
