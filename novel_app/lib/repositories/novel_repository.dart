import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import '../models/novel.dart';
import '../models/ai_accompaniment_settings.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';

/// 小说数据仓库
///
/// 负责小说元数据、阅读进度和AI伴读设置的数据库操作
class NovelRepository extends BaseRepository {
  Database? _sharedDatabase;

  @override
  Future<Database> initDatabase() async {
    if (_sharedDatabase != null) return _sharedDatabase!;
    if (isWebPlatform) {
      throw Exception('Database is not supported on web platform');
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'novel_reader.db');

    _sharedDatabase = await openDatabase(
      path,
      version: 21,
    );

    return _sharedDatabase!;
  }

  /// 添加小说到书架
  Future<int> addToBookshelf(Novel novel) async {
    try {
      final db = await database;
      final result = await db.insert(
        'bookshelf',
        {
          'title': novel.title,
          'author': novel.author,
          'url': novel.url,
          'coverUrl': novel.coverUrl,
          'description': novel.description,
          'backgroundSetting': novel.backgroundSetting,
          'addedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      LoggerService.instance.i(
        '添加小说到书架: ${novel.title}',
        category: LogCategory.database,
        tags: ['novel', 'add', 'success'],
      );

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '添加小说到书架失败: ${novel.title} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['novel', 'add', 'failed'],
      );
      rethrow;
    }
  }

  /// 从书架移除小说
  Future<int> removeFromBookshelf(String novelUrl) async {
    try {
      final db = await database;
      final result = await db.delete(
        'bookshelf',
        where: 'url = ?',
        whereArgs: [novelUrl],
      );

      LoggerService.instance.i(
        '从书架移除小说: $novelUrl',
        category: LogCategory.database,
        tags: ['novel', 'remove', 'success'],
      );

      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '从书架移除小说失败: $novelUrl - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['novel', 'remove', 'failed'],
      );
      rethrow;
    }
  }

  /// 获取所有小说
  Future<List<Novel>> getNovels() async {
    if (isWebPlatform) {
      return [];
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'novels',
      orderBy: 'lastReadTime DESC, addedAt DESC',
    );

    return List.generate(maps.length, (i) {
      return Novel(
        title: maps[i]['title'],
        author: maps[i]['author'],
        url: maps[i]['url'],
        coverUrl: maps[i]['coverUrl'],
        description: maps[i]['description'],
        backgroundSetting: maps[i]['backgroundSetting'],
        isInBookshelf: true,
      );
    });
  }

  /// 检查小说是否在书架中
  Future<bool> isInBookshelf(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
    return maps.isNotEmpty;
  }

  /// 更新最后阅读章节
  Future<int> updateLastReadChapter(String novelUrl, int chapterIndex) async {
    final db = await database;
    return await db.update(
      'bookshelf',
      {
        'lastReadChapter': chapterIndex,
        'lastReadTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 更新小说背景设定
  Future<int> updateBackgroundSetting(
      String novelUrl, String? backgroundSetting) async {
    if (isWebPlatform) {
      return 0;
    }

    final db = await database;
    return await db.update(
      'bookshelf',
      {'backgroundSetting': backgroundSetting},
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 获取小说背景设定
  Future<String?> getBackgroundSetting(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['backgroundSetting'],
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['backgroundSetting'] as String?;
    }
    return null;
  }

  /// 获取上次阅读的章节索引
  Future<int> getLastReadChapter(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['lastReadChapter'],
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['lastReadChapter'] as int? ?? 0;
    }
    return 0;
  }

  /// 获取小说的AI伴读设置
  Future<AiAccompanimentSettings> getAiAccompanimentSettings(
      String novelUrl) async {
    if (isWebPlatform) {
      return const AiAccompanimentSettings();
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['aiAccompanimentEnabled', 'aiInfoNotificationEnabled'],
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isEmpty) {
      return const AiAccompanimentSettings();
    }

    return AiAccompanimentSettings(
      autoEnabled: (maps[0]['aiAccompanimentEnabled'] as int) == 1,
      infoNotificationEnabled:
          (maps[0]['aiInfoNotificationEnabled'] as int) == 1,
    );
  }

  /// 更新小说的AI伴读设置
  Future<int> updateAiAccompanimentSettings(
      String novelUrl, AiAccompanimentSettings settings) async {
    if (isWebPlatform) {
      return 0;
    }

    final db = await database;
    return await db.update(
      'bookshelf',
      {
        'aiAccompanimentEnabled': settings.autoEnabled ? 1 : 0,
        'aiInfoNotificationEnabled': settings.infoNotificationEnabled ? 1 : 0,
      },
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }
}
