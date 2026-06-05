import '../models/prompt_history.dart';
import 'base_repository.dart';
import '../core/interfaces/repositories/i_prompt_history_repository.dart';

class PromptHistoryRepository extends BaseRepository
    implements IPromptHistoryRepository {
  PromptHistoryRepository({required super.dbConnection});

  static const String _table = 'prompt_history';

  @override
  Future<void> addOrUpdate(String promptText) async {
    final trimmed = promptText.trim();
    if (trimmed.isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing = await db.query(
      _table,
      columns: ['id'],
      where: 'prompt_text = ?',
      whereArgs: [trimmed],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        _table,
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(_table, {
        'prompt_text': trimmed,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  @override
  Future<List<PromptHistory>> getAll({int? limit}) async {
    final db = await database;
    final maps = await db.query(
      _table,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps.map(PromptHistory.fromMap).toList();
  }

  @override
  Future<List<PromptHistory>> search(String keyword) async {
    final db = await database;
    final maps = await db.query(
      _table,
      where: 'prompt_text LIKE ?',
      whereArgs: ['%${keyword.trim()}%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map(PromptHistory.fromMap).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteAll() async {
    final db = await database;
    await db.delete(_table);
  }
}
