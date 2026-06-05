import '../models/prompt_tag_category.dart';
import 'base_repository.dart';
import '../core/interfaces/repositories/i_prompt_tag_category_repository.dart';

class PromptTagCategoryRepository extends BaseRepository
    implements IPromptTagCategoryRepository {
  PromptTagCategoryRepository({required super.dbConnection});

  static const String _table = 'prompt_tag_categories';

  @override
  Future<List<PromptTagCategory>> getAll() async {
    final db = await database;
    final maps = await db.query(_table, orderBy: 'sort_order ASC, id ASC');
    return maps.map(PromptTagCategory.fromMap).toList();
  }

  @override
  Future<int> save(PromptTagCategory category) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (category.id == null) {
      return await db.insert(_table, {
        'name': category.name,
        'sort_order': category.sortOrder,
        'created_at': now,
        'updated_at': now,
      });
    }
    await db.update(
      _table,
      {
        'name': category.name,
        'sort_order': category.sortOrder,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
    return category.id!;
  }

  @override
  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
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
  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $_table');
    return (result.first['cnt'] as int?) ?? 0;
  }

  @override
  Future<void> initDefaultCategories() async {
    if (await count() > 0) return;
    final now = DateTime.now();
    final defaults = ['风格', '场景', '人物', '情节'];
    for (var i = 0; i < defaults.length; i++) {
      await save(PromptTagCategory(
        name: defaults[i],
        sortOrder: i,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }
}
