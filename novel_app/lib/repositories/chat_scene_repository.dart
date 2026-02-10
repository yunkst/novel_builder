import '../models/chat_scene.dart';
import 'base_repository.dart';
import '../core/interfaces/repositories/i_chat_scene_repository.dart';

/// 聊天场景数据仓库
///
/// 负责管理角色聊天场景的数据库操作，包括场景的创建、更新、查询和删除。
/// 聊天场景用于预设角色聊天的背景和环境信息。
///
/// 注意：此Repository现在使用统一的数据库版本v21，不再有独立的数据库版本管理。
class ChatSceneRepository extends BaseRepository
    implements IChatSceneRepository {
  /// 构造函数 - 接受数据库连接实例
  ChatSceneRepository({required super.dbConnection});

  /// 插入新的聊天场景
  ///
  /// 参数：
  /// - [scene] 要插入的聊天场景对象
  ///
  /// 返回：
  /// - 新插入记录的ID
  ///
  /// 示例：
  /// ```dart
  /// final scene = ChatScene(
  ///   title: '咖啡厅偶遇',
  ///   content: '在一个阳光明媚的下午...',
  /// );
  /// final id = await repository.insertChatScene(scene);
  /// print('新场景ID: $id');
  /// ```
  @override
  Future<int> insertChatScene(ChatScene scene) async {
    final db = await database;
    return await db.insert('chat_scenes', scene.toMap());
  }

  /// 更新聊天场景
  ///
  /// 根据场景ID更新场景信息，自动更新 updatedAt 时间戳。
  ///
  /// 参数：
  /// - [scene] 要更新的聊天场景对象（必须包含有效的ID）
  ///
  /// 示例：
  /// ```dart
  /// final scene = ChatScene(
  ///   id: 1,
  ///   title: '更新后的标题',
  ///   content: '更新后的内容...',
  ///   createdAt: DateTime.now(),
  /// );
  /// await repository.updateChatScene(scene);
  /// ```
  @override
  Future<void> updateChatScene(ChatScene scene) async {
    final db = await database;
    await db.update(
      'chat_scenes',
      scene.toMap(),
      where: 'id = ?',
      whereArgs: [scene.id],
    );
  }

  /// 删除聊天场景
  ///
  /// 参数：
  /// - [id] 要删除的场景ID
  ///
  /// 示例：
  /// ```dart
  /// await repository.deleteChatScene(1);
  /// print('场景已删除');
  /// ```
  @override
  Future<void> deleteChatScene(int id) async {
    final db = await database;
    await db.delete(
      'chat_scenes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有聊天场景
  ///
  /// 返回：
  /// - 所有聊天场景的列表，按创建时间降序排列（最新创建的在前）
  ///
  /// 示例：
  /// ```dart
  /// final scenes = await repository.getAllChatScenes();
  /// for (var scene in scenes) {
  ///   print('${scene.title} - ${scene.createdAt}');
  /// }
  /// ```
  @override
  Future<List<ChatScene>> getAllChatScenes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_scenes',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => ChatScene.fromMap(maps[i]));
  }

  /// 根据ID获取聊天场景
  ///
  /// 参数：
  /// - [id] 场景ID
  ///
  /// 返回：
  /// - 找到的聊天场景对象，如果不存在则返回 null
  ///
  /// 示例：
  /// ```dart
  /// final scene = await repository.getChatSceneById(1);
  /// if (scene != null) {
  ///   print('找到场景：${scene.title}');
  /// }
  /// ```
  @override
  Future<ChatScene?> getChatSceneById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_scenes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ChatScene.fromMap(maps.first);
  }

  /// 搜索聊天场景（按标题）
  ///
  /// 在标题中包含查询关键词的场景，支持模糊搜索。
  ///
  /// 参数：
  /// - [query] 搜索关键词
  ///
  /// 返回：
  /// - 匹配的聊天场景列表，按创建时间降序排列
  ///
  /// 示例：
  /// ```dart
  /// final results = await repository.searchChatScenes('咖啡厅');
  /// print('找到 ${results.length} 个相关场景');
  /// ```
  @override
  Future<List<ChatScene>> searchChatScenes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_scenes',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => ChatScene.fromMap(maps[i]));
  }
}
