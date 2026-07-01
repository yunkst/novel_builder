import '../core/interfaces/repositories/i_chat_session_repository.dart';
import '../models/chat_session.dart';
import '../models/chat_message_record.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';

/// AI 对话会话仓库实现
///
/// 表常量说明：
/// - chat_sessions: id PK（自增）+ scenarioId + 标题/时间/currentNovel
/// - chat_messages: id PK（自增）+ sessionId FK（CASCADE 删除）+ 角色/内容/segmentsJson/timestamp/orderIndex
///
/// appendMessage 用 db.transaction 把 3 步合成原子操作：
/// 1) MAX(orderIndex)+1 计算下一个序号
/// 2) INSERT chat_messages
/// 3) UPDATE chat_sessions SET updatedAt = now
/// 任何一步异常都会回滚，DB 状态保持一致。
class ChatSessionRepository extends BaseRepository
    implements IChatSessionRepository {
  static const String _tableSessions = 'chat_sessions';
  static const String _tableMessages = 'chat_messages';

  ChatSessionRepository({required super.dbConnection});

  // ===== 会话 =====

  @override
  Future<int> createSession(ChatSession session) async {
    try {
      final db = await database;
      final id = await db.insert(_tableSessions, session.toMap());
      LoggerService.instance.i(
        '创建会话: id=$id scenarioId=${session.scenarioId} title=${session.title}',
        category: LogCategory.database,
        tags: ['chat_session', 'create', 'success'],
      );
      return id;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '创建会话失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_session', 'create', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<List<ChatSession>> listSessionsByScenario(
    String scenarioId, {
    int limit = 200,
  }) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableSessions,
        where: 'scenarioId = ?',
        whereArgs: [scenarioId],
        orderBy: 'updatedAt DESC',
        limit: limit,
      );
      return maps.map((m) => ChatSession.fromMap(m)).toList();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '列出会话失败: scenarioId=$scenarioId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_session', 'list', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<ChatSession?> getSession(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableSessions,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return ChatSession.fromMap(maps.first);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询会话失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_session', 'get', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<int> renameSession(int id, String title) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final affected = await db.update(
        _tableSessions,
        {'title': title, 'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      LoggerService.instance.i(
        '重命名会话: id=$id affected=$affected',
        category: LogCategory.database,
        tags: ['chat_session', 'rename', 'success'],
      );
      return affected;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '重命名会话失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_session', 'rename', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<int> deleteSession(int id) async {
    try {
      final db = await database;
      final affected = await db.delete(
        _tableSessions,
        where: 'id = ?',
        whereArgs: [id],
      );
      LoggerService.instance.i(
        '删除会话: id=$id affected=$affected（messages 经 FK CASCADE 自动删除）',
        category: LogCategory.database,
        tags: ['chat_session', 'delete', 'success'],
      );
      return affected;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除会话失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_session', 'delete', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<int> touchSession(int id) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      return db.update(
        _tableSessions,
        {'updatedAt': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '刷新会话时间失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_session', 'touch', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<void> updateCurrentNovel(
    int id, {
    int? novelId,
    String? novelTitle,
  }) async {
    try {
      final db = await database;
      await db.update(
        _tableSessions,
        {
          'currentNovelId': novelId,
          'currentNovelTitle': novelTitle,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新 currentNovel 失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_session', 'update_novel', 'failed'],
      );
      rethrow;
    }
  }

  // ===== 消息 =====

  @override
  Future<int> appendMessage(ChatMessageRecord record) async {
    try {
      final db = await database;
      // 用 transaction 把 orderIndex 计算 + 插入消息 + 更新 session 时间戳合并
      return await db.transaction((txn) async {
        // 1) 计算下一个 orderIndex：MAX + 1；空表时取 0
        final maxResult = await txn.rawQuery(
          'SELECT COALESCE(MAX(orderIndex), -1) AS maxIdx FROM $_tableMessages WHERE sessionId = ?',
          [record.sessionId],
        );
        final maxIdx = (maxResult.first['maxIdx'] as int?) ?? -1;
        final nextIdx = maxIdx + 1;

        // 2) 插入消息（强制覆盖 orderIndex，避免调用方传错导致冲突）
        final insertable = record.copyWith(orderIndex: nextIdx).toMap();
        final messageId = await txn.insert(_tableMessages, insertable);

        // 3) 刷新 session.updatedAt，让列表排序稳定
        final now = DateTime.now().millisecondsSinceEpoch;
        await txn.update(
          _tableSessions,
          {'updatedAt': now},
          where: 'id = ?',
          whereArgs: [record.sessionId],
        );

        LoggerService.instance.d(
          '追加消息: sessionId=${record.sessionId} role=${record.role} orderIdx=$nextIdx messageId=$messageId',
          category: LogCategory.database,
          tags: ['chat_message', 'append', 'success'],
        );
        return messageId;
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '追加消息失败: sessionId=${record.sessionId} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_message', 'append', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<List<ChatMessageRecord>> listMessages(int sessionId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableMessages,
        where: 'sessionId = ?',
        whereArgs: [sessionId],
        orderBy: 'orderIndex ASC',
      );
      return maps.map((m) => ChatMessageRecord.fromMap(m)).toList();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '列举消息失败: sessionId=$sessionId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_message', 'list', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<int> getMessageCount(int sessionId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM $_tableMessages WHERE sessionId = ?',
        [sessionId],
      );
      return (result.first['cnt'] as int?) ?? 0;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '统计消息数失败: sessionId=$sessionId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_message', 'count', 'failed'],
      );
      rethrow;
    }
  }

  @override
  Future<int> clearMessages(int sessionId) async {
    try {
      final db = await database;
      return db.transaction((txn) async {
        final deleted = await txn.delete(
          _tableMessages,
          where: 'sessionId = ?',
          whereArgs: [sessionId],
        );
        await txn.update(
          _tableSessions,
          {'updatedAt': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [sessionId],
        );
        return deleted;
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '清空会话消息失败: sessionId=$sessionId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chat_message', 'clear', 'failed'],
      );
      rethrow;
    }
  }
}
