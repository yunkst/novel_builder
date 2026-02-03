import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import '../utils/media_markup_parser.dart';

/// 无效媒体标记清理服务
///
/// 功能：
/// 1. 检测章节内容中的无效媒体标记（插图、视频等）
/// 2. 自动清理无效标记
/// 3. 验证标记在数据库中是否存在
///
/// 使用方式：
/// ```dart
/// // 通过Provider获取（推荐）
/// final cleaner = ref.watch(invalidMarkupCleanerProvider);
///
/// // 或手动创建实例
/// final cleaner = InvalidMarkupCleaner(databaseService: databaseService);
/// ```
class InvalidMarkupCleaner {
  final DatabaseService? _databaseService;
  final Future<Database> Function()? _databaseGetter;

  /// 创建 InvalidMarkupCleaner 实例
  ///
  /// 参数:
  /// - [databaseService] 数据库服务（可选，与databaseGetter二选一）
  /// - [databaseGetter] 数据库获取函数（可选，与databaseService二选一）
  InvalidMarkupCleaner({
    DatabaseService? databaseService,
    Future<Database> Function()? databaseGetter,
  })  : _databaseService = databaseService,
        _databaseGetter = databaseGetter {
    assert(
      databaseService != null || databaseGetter != null,
      '必须提供 databaseService 或 databaseGetter 之一',
    );
  }

  /// 获取数据库连接
  Future<Database> get _database async {
    if (_databaseService != null) {
      return await _databaseService!.database;
    }
    return await _databaseGetter!();
  }

  /// 验证媒体标记是否有效（数据库中是否存在）
  ///
  /// 参数：
  /// - [mediaId]：媒体ID（taskId、videoId等）
  /// - [mediaType]：媒体类型（'插图'、'视频'等）
  ///
  /// 返回：true=有效，false=无效
  Future<bool> validateMediaMarkup(String mediaId, String mediaType) async {
    try {
      final db = await _database;

      // 根据媒体类型查询不同的表
      switch (mediaType) {
        case '插图':
          // 查询 scene_illustrations 表
          final List<Map<String, dynamic>> maps = await db.query(
            'scene_illustrations',
            where: 'task_id = ?',
            whereArgs: [mediaId],
            limit: 1,
          );
          final isValid = maps.isNotEmpty;
          debugPrint('🔍 验证插图标记 [$mediaId]: ${isValid ? "✅ 有效" : "❌ 无效"}');
          return isValid;

        case '视频':
          // 查询视频相关的表（根据实际表名调整）
          // TODO: 实现视频标记的验证逻辑
          debugPrint('⚠️ 视频标记验证暂未实现: $mediaId');
          return true; // 暂时返回true，避免误删

        default:
          debugPrint('⚠️ 未知的媒体类型: $mediaType');
          return true; // 未知类型默认有效，避免误删
      }
    } catch (e) {
      debugPrint('❌ 验证媒体标记失败 [$mediaType]:$mediaId - $e');
      // 验证失败时默认返回true，避免网络错误导致误删
      return true;
    }
  }

  /// 清理章节内容中的所有无效媒体标记
  ///
  /// 参数：
  /// - [chapterContent]：章节内容
  ///
  /// 返回：清理后的章节内容
  Future<String> cleanInvalidMarkups(String chapterContent) async {
    try {
      // 1. 解析所有媒体标记
      final markups = MediaMarkupParser.parseMediaMarkup(chapterContent);

      if (markups.isEmpty) {
        // 没有媒体标记，直接返回原内容
        return chapterContent;
      }

      debugPrint('🔍 检测到 ${markups.length} 个媒体标记');

      // 2. 验证每个标记，收集无效的标记
      final List<MediaMarkup> invalidMarkups = [];
      for (final markup in markups) {
        final isValid = await validateMediaMarkup(markup.id, markup.type);
        if (!isValid) {
          invalidMarkups.add(markup);
          debugPrint('  ❌ 发现无效标记: [${markup.type}](${markup.id})');
        }
      }

      if (invalidMarkups.isEmpty) {
        // 所有标记都有效，直接返回原内容
        debugPrint('✅ 所有媒体标记均有效');
        return chapterContent;
      }

      debugPrint('🧹 准备清理 ${invalidMarkups.length} 个无效标记');

      // 3. 从内容中移除无效的标记
      String cleanedContent = chapterContent;
      for (final invalidMarkup in invalidMarkups) {
        // 使用 replaceAll 移除所有匹配的标记
        cleanedContent =
            cleanedContent.replaceAll(invalidMarkup.fullMarkup, '');
        debugPrint('  ✅ 已清理: ${invalidMarkup.fullMarkup}');
      }

      // 4. 清理多余的空行（连续的空行合并为一行）
      cleanedContent =
          cleanedContent.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');

      debugPrint('✅ 清理完成，移除了 ${invalidMarkups.length} 个无效标记');

      return cleanedContent;
    } catch (e) {
      debugPrint('❌ 清理无效标记失败: $e');
      // 清理失败时返回原内容，避免破坏章节内容
      return chapterContent;
    }
  }

  /// 清理章节内容并自动更新数据库
  ///
  /// 参数：
  /// - [chapterUrl]：章节URL
  /// - [chapterContent]：章节内容
  ///
  /// 返回：清理后的章节内容（如果被清理则更新数据库）
  Future<String> cleanAndUpdateChapter(
    String chapterUrl,
    String chapterContent,
  ) async {
    try {
      // 1. 清理无效标记
      final cleanedContent = await cleanInvalidMarkups(chapterContent);

      // 2. 检查内容是否被修改
      if (cleanedContent != chapterContent) {
        debugPrint('💾 章节内容已清理，正在更新数据库: $chapterUrl');

        // 3. 更新数据库
        await (await _database).update(
          'chapter_cache',
          {'content': cleanedContent},
          where: 'chapterUrl = ?',
          whereArgs: [chapterUrl],
        );

        debugPrint('✅ 数据库已更新');
      } else {
        // 减少日志噪音：只在调试模式下输出
        if (kDebugMode) {
          // debugPrint('ℹ️ 章节内容无需清理'); // 已注释，避免大量日志
        }
      }

      return cleanedContent;
    } catch (e) {
      debugPrint('❌ 清理并更新章节失败: $e');
      // 失败时返回原内容
      return chapterContent;
    }
  }
}
