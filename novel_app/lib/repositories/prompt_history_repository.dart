import 'dart:convert';
import '../models/prompt_history.dart';
import '../models/saved_tag_group.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';
import '../core/interfaces/repositories/i_prompt_history_repository.dart';

class PromptHistoryRepository extends BaseRepository
    implements IPromptHistoryRepository {
  PromptHistoryRepository({required super.dbConnection});

  static const String _table = 'prompt_history';

  @override
  Future<void> addOrUpdate(
    String promptText, {
    List<SavedTagGroup> tagGroups = const [],
  }) async {
    final trimmed = promptText.trim();
    if (trimmed.isEmpty) {
      LoggerService.instance.d(
        'addOrUpdate: 提示词为空，跳过写入',
        category: LogCategory.database,
        tags: ['prompt-history', 'upsert', 'skip-empty'],
      );
      return;
    }
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final tagGroupsJson = jsonEncode(tagGroups.map((t) => t.toJson()).toList());

    try {
      final existing = await db.query(
        _table,
        columns: ['id', 'tag_group_ids'],
        where: 'prompt_text = ?',
        whereArgs: [trimmed],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        final existingTags = existing.first['tag_group_ids'] as String?;
        // 合并标签：新传入的非空才覆盖旧的
        final mergedTagsJson = tagGroups.isNotEmpty
            ? tagGroupsJson
            : (existingTags ?? tagGroupsJson);
        await db.update(
          _table,
          {
            'updated_at': now,
            'tag_group_ids': mergedTagsJson,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        LoggerService.instance.i(
          'addOrUpdate: 更新已存在的提示词历史 (ID: $id, tags: ${tagGroups.length})',
          category: LogCategory.database,
          tags: ['prompt-history', 'update'],
        );
      } else {
        await db.insert(_table, {
          'prompt_text': trimmed,
          'created_at': now,
          'updated_at': now,
          'tag_group_ids': tagGroups.isEmpty ? null : tagGroupsJson,
        });
        LoggerService.instance.i(
          'addOrUpdate: 新增提示词历史 (tags: ${tagGroups.length})',
          category: LogCategory.database,
          tags: ['prompt-history', 'insert'],
        );
      }
    } catch (e, stack) {
      LoggerService.instance.e(
        'addOrUpdate: 写入提示词历史失败: $e',
        stackTrace: stack.toString(),
        category: LogCategory.database,
        tags: ['prompt-history', 'upsert', 'error'],
      );
      rethrow;
    }
  }

  @override
  Future<List<PromptHistory>> getAll({int? limit}) async {
    final db = await database;
    LoggerService.instance.d(
      'getAll: 查询全部提示词历史 (limit: $limit)',
      category: LogCategory.database,
      tags: ['prompt-history', 'query', 'getAll'],
    );
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
    final kw = keyword.trim();
    LoggerService.instance.d(
      'search: 搜索提示词历史 (keyword: $kw)',
      category: LogCategory.database,
      tags: ['prompt-history', 'query', 'search'],
    );
    final maps = await db.query(
      _table,
      where: 'prompt_text LIKE ?',
      whereArgs: ['%$kw%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map(PromptHistory.fromMap).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await database;
    try {
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      LoggerService.instance.i(
        'delete: 删除提示词历史 (ID: $id)',
        category: LogCategory.database,
        tags: ['prompt-history', 'delete'],
      );
    } catch (e, stack) {
      LoggerService.instance.e(
        'delete: 删除提示词历史失败 (ID: $id): $e',
        stackTrace: stack.toString(),
        category: LogCategory.database,
        tags: ['prompt-history', 'delete', 'error'],
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteAll() async {
    final db = await database;
    try {
      await db.delete(_table);
      LoggerService.instance.i(
        'deleteAll: 清空全部提示词历史',
        category: LogCategory.database,
        tags: ['prompt-history', 'delete', 'all'],
      );
    } catch (e, stack) {
      LoggerService.instance.e(
        'deleteAll: 清空提示词历史失败: $e',
        stackTrace: stack.toString(),
        category: LogCategory.database,
        tags: ['prompt-history', 'delete', 'all', 'error'],
      );
      rethrow;
    }
  }
}
