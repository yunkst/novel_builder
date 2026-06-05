import 'dart:math';
import '../models/prompt_tag.dart';
import '../models/tag_group.dart';
import 'base_repository.dart';
import '../core/interfaces/repositories/i_prompt_tag_repository.dart';

class PromptTagRepository extends BaseRepository
    implements IPromptTagRepository {
  PromptTagRepository({required super.dbConnection});

  static const String _table = 'prompt_tags';

  @override
  Future<List<PromptTag>> getByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.query(
      _table,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map(PromptTag.fromMap).toList();
  }

  @override
  Future<List<PromptTag>> search(String keyword, {int? categoryId}) async {
    final db = await database;
    final kw = keyword.trim();
    final where = <String>[];
    final args = <Object?>[];
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (kw.isNotEmpty) {
      where.add('(name LIKE ? OR prompt_text LIKE ?)');
      args.add('%$kw%');
      args.add('%$kw%');
    }
    final maps = await db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map(PromptTag.fromMap).toList();
  }

  @override
  Future<int> save(PromptTag tag) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (tag.id == null) {
      return await db.insert(_table, {
        'category_id': tag.categoryId,
        'name': tag.name,
        'prompt_text': tag.promptText,
        'sort_order': tag.sortOrder,
        'created_at': now,
        'updated_at': now,
      });
    }
    await db.update(
      _table,
      {
        'category_id': tag.categoryId,
        'name': tag.name,
        'prompt_text': tag.promptText,
        'sort_order': tag.sortOrder,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [tag.id],
    );
    return tag.id!;
  }

  @override
  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteByCategory(int categoryId) async {
    final db = await database;
    await db.delete(_table, where: 'category_id = ?', whereArgs: [categoryId]);
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(
        _table,
        {'sort_order': i, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<PromptTag>> getByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final maps = await db.query(
      _table,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map(PromptTag.fromMap).toList();
  }

  @override
  Future<List<TagGroup>> getGroupedByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT MIN(id) AS representative_id,
             category_id,
             name,
             COUNT(*) AS count
      FROM $_table
      WHERE category_id = ?
      GROUP BY category_id, name
      ORDER BY MIN(sort_order) ASC, MIN(id) ASC
    ''',
      [categoryId],
    );
    return maps
        .map((m) => TagGroup(
              name: m['name'] as String,
              count: (m['count'] as int?) ?? 0,
              representativeId: m['representative_id'] as int,
              categoryId: m['category_id'] as int,
            ))
        .toList();
  }

  @override
  Future<String?> getRandomPromptText(int categoryId, String name) async {
    final db = await database;
    final maps = await db.query(
      _table,
      columns: ['prompt_text'],
      where: 'category_id = ? AND name = ?',
      whereArgs: [categoryId, name],
    );
    if (maps.isEmpty) return null;
    final picked = maps[Random().nextInt(maps.length)];
    return picked['prompt_text'] as String?;
  }
}
