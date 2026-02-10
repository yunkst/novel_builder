import '../../../models/chat_scene.dart';

/// 聊天场景数据仓库接口
///
/// 负责管理角色聊天场景的数据库操作，包括场景的创建、更新、查询和删除。
/// 聊天场景用于预设角色聊天的背景和环境信息。
abstract class IChatSceneRepository {
  /// 插入新的聊天场景
  ///
  /// 参数：
  /// - [scene] 要插入的聊天场景对象
  ///
  /// 返回：
  /// - 新插入记录的ID
  Future<int> insertChatScene(ChatScene scene);

  /// 更新聊天场景
  ///
  /// 根据场景ID更新场景信息，自动更新 updatedAt 时间戳。
  ///
  /// 参数：
  /// - [scene] 要更新的聊天场景对象（必须包含有效的ID）
  Future<void> updateChatScene(ChatScene scene);

  /// 删除聊天场景
  ///
  /// 参数：
  /// - [id] 要删除的场景ID
  Future<void> deleteChatScene(int id);

  /// 获取所有聊天场景
  ///
  /// 返回：
  /// - 所有聊天场景的列表，按创建时间降序排列（最新创建的在前）
  Future<List<ChatScene>> getAllChatScenes();

  /// 根据ID获取聊天场景
  ///
  /// 参数：
  /// - [id] 场景ID
  ///
  /// 返回：
  /// - 找到的聊天场景对象，如果不存在则返回 null
  Future<ChatScene?> getChatSceneById(int id);

  /// 搜索聊天场景（按标题）
  ///
  /// 在标题中包含查询关键词的场景，支持模糊搜索。
  ///
  /// 参数：
  /// - [query] 搜索关键词
  ///
  /// 返回：
  /// - 匹配的聊天场景列表，按创建时间降序排列
  Future<List<ChatScene>> searchChatScenes(String query);
}
