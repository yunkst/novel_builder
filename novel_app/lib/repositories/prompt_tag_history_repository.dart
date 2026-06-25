import '../core/interfaces/i_database_connection.dart';
import '../services/logger_service.dart';

/// 标签修改历史记录
class PromptTagHistoryEntry {
  final int? id;
  final int tagId;
  final String novelUrl;
  final String changeType; // 'reason_adjust' | 'prompt_clarify' | 'created'
  final String? oldValue;
  final String newValue;
  final String reason;
  final DateTime createdAt;

  const PromptTagHistoryEntry({
    this.id,
    required this.tagId,
    required this.novelUrl,
    required this.changeType,
    this.oldValue,
    required this.newValue,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'tag_id': tagId,
        'novel_url': novelUrl,
        'change_type': changeType,
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory PromptTagHistoryEntry.fromMap(Map<String, dynamic> map) =>
      PromptTagHistoryEntry(
        id: map['id'] as int?,
        tagId: map['tag_id'] as int,
        novelUrl: map['novel_url'] as String,
        changeType: map['change_type'] as String,
        oldValue: map['old_value'] as String?,
        newValue: map['new_value'] as String,
        reason: map['reason'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

/// 标签修改历史 Repository
///
/// 记录 AI 自省对 tag 的修改（reason 调整、promptText 优化、新增 tag），
/// 用于回滚和进化轨迹查看。
class PromptTagHistoryRepository {
  final IDatabaseConnection _dbConnection;
  static const String _table = 'prompt_tag_history';

  PromptTagHistoryRepository({required IDatabaseConnection dbConnection})
      : _dbConnection = dbConnection;

  /// 记录一次修改
  Future<int> insert(PromptTagHistoryEntry entry) async {
    final db = await _dbConnection.database;
    LoggerService.instance.d(
      'insert: 记录标签修改历史 (tagId: ${entry.tagId}, type: ${entry.changeType})',
      category: LogCategory.database,
      tags: ['tag-history', 'insert'],
    );
    return db.insert(_table, entry.toMap());
  }

  /// 查询某标签的修改历史
  Future<List<PromptTagHistoryEntry>> getByTagId(int tagId) async {
    final db = await _dbConnection.database;
    final maps = await db.query(
      _table,
      where: 'tag_id = ?',
      whereArgs: [tagId],
      orderBy: 'created_at DESC',
    );
    return maps.map(PromptTagHistoryEntry.fromMap).toList();
  }

  /// 查询某小说的所有修改历史
  Future<List<PromptTagHistoryEntry>> getByNovelUrl(String novelUrl) async {
    final db = await _dbConnection.database;
    final maps = await db.query(
      _table,
      where: 'novel_url = ?',
      whereArgs: [novelUrl],
      orderBy: 'created_at DESC',
    );
    return maps.map(PromptTagHistoryEntry.fromMap).toList();
  }

  /// 获取最近 N 条修改记录
  Future<List<PromptTagHistoryEntry>> getRecent({int limit = 20}) async {
    final db = await _dbConnection.database;
    final maps = await db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map(PromptTagHistoryEntry.fromMap).toList();
  }
}
