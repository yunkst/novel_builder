import 'package:flutter/foundation.dart';
import '../core/interfaces/repositories/i_chapter_repository.dart';
import '../core/interfaces/repositories/i_illustration_repository.dart';
import '../utils/media_markup_parser.dart';
import 'logger_service.dart';

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
/// final cleaner = InvalidMarkupCleaner(
///   chapterRepo: chapterRepo,
///   illustrationRepo: illustrationRepo,
/// );
/// ```
class InvalidMarkupCleaner {
  final IChapterRepository _chapterRepo;
  final IIllustrationRepository _illustrationRepo;

  /// 创建 InvalidMarkupCleaner 实例
  ///
  /// 参数:
  /// - [chapterRepo] 章节数据仓库（必需）
  /// - [illustrationRepo] 插图数据仓库（必需）
  InvalidMarkupCleaner({
    required IChapterRepository chapterRepo,
    required IIllustrationRepository illustrationRepo,
  })  : _chapterRepo = chapterRepo,
        _illustrationRepo = illustrationRepo;

  /// 验证媒体标记是否有效（数据库中是否存在）
  ///
  /// 参数：
  /// - [mediaId]：媒体ID（taskId、videoId等）
  /// - [mediaType]：媒体类型（'插图'、'视频'等）
  ///
  /// 返回：true=有效，false=无效
  Future<bool> validateMediaMarkup(String mediaId, String mediaType) async {
    try {
      // 根据媒体类型查询不同的表
      switch (mediaType) {
        case '插图':
          // 使用插图仓库验证任务ID是否存在
          final isValid = await _illustrationRepo.taskExists(mediaId);
          LoggerService.instance.d(
            '验证插图标记 [$mediaId]: ${isValid ? "有效" : "无效"}',
            category: LogCategory.general,
            tags: ['cleanup'],
          );
          return isValid;

        case '视频':
          // 查询视频相关的表（根据实际表名调整）
          //
          // 优先级: P2 - 中等
          // Issue: 实现视频标记的验证逻辑
          //
          // 当前实现: 默认返回true以避免误删
          // 目标实现:
          // 1. 确定视频相关的数据库表名
          // 2. 实现视频ID查询验证
          // 3. 验证视频任务状态
          //
          // 注意事项:
          // - 需要了解视频功能的表结构
          // - 验证失败时应返回true避免误删
          // - 参考插图验证的实现方式
          LoggerService.instance.w(
            '视频标记验证暂未实现: $mediaId',
            category: LogCategory.general,
            tags: ['cleanup'],
          );
          return true; // 暂时返回true，避免误删

        default:
          LoggerService.instance.w(
            '未知的媒体类型: $mediaType',
            category: LogCategory.general,
            tags: ['cleanup'],
          );
          return true; // 未知类型默认有效，避免误删
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '验证媒体标记失败 [$mediaType]:$mediaId - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.general,
        tags: ['cleanup'],
      );
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

      LoggerService.instance.d(
        '检测到 ${markups.length} 个媒体标记',
        category: LogCategory.general,
        tags: ['cleanup'],
      );

      // 2. 验证每个标记，收集无效的标记
      final List<MediaMarkup> invalidMarkups = [];
      for (final markup in markups) {
        final isValid = await validateMediaMarkup(markup.id, markup.type);
        if (!isValid) {
          invalidMarkups.add(markup);
          LoggerService.instance.d(
            '发现无效标记: [${markup.type}](${markup.id})',
            category: LogCategory.general,
            tags: ['cleanup'],
          );
        }
      }

      if (invalidMarkups.isEmpty) {
        // 所有标记都有效，直接返回原内容
        LoggerService.instance.i(
          '所有媒体标记均有效',
          category: LogCategory.general,
          tags: ['cleanup'],
        );
        return chapterContent;
      }

      LoggerService.instance.i(
        '准备清理 ${invalidMarkups.length} 个无效标记',
        category: LogCategory.general,
        tags: ['cleanup'],
      );

      // 3. 从内容中移除无效的标记
      String cleanedContent = chapterContent;
      for (final invalidMarkup in invalidMarkups) {
        // 使用 replaceAll 移除所有匹配的标记
        cleanedContent =
            cleanedContent.replaceAll(invalidMarkup.fullMarkup, '');
        LoggerService.instance.d(
          '已清理: ${invalidMarkup.fullMarkup}',
          category: LogCategory.general,
          tags: ['cleanup'],
        );
      }

      // 4. 清理多余的空行（连续的空行合并为一行）
      cleanedContent =
          cleanedContent.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');

      LoggerService.instance.i(
        '清理完成，移除了 ${invalidMarkups.length} 个无效标记',
        category: LogCategory.general,
        tags: ['cleanup'],
      );

      return cleanedContent;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '清理无效标记失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.general,
        tags: ['cleanup'],
      );
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
        LoggerService.instance.i(
          '章节内容已清理，正在更新数据库: $chapterUrl',
          category: LogCategory.general,
          tags: ['cleanup'],
        );

        // 3. 更新数据库
        await _chapterRepo.updateChapterContent(chapterUrl, cleanedContent);

        LoggerService.instance.i(
          '数据库已更新',
          category: LogCategory.general,
          tags: ['cleanup'],
        );
      } else {
        // 减少日志噪音：只在调试模式下输出
        if (kDebugMode) {
          // LoggerService.instance.d('章节内容无需清理'); // 已注释，避免大量日志
        }
      }

      return cleanedContent;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '清理并更新章节失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.general,
        tags: ['cleanup'],
      );
      // 失败时返回原内容
      return chapterContent;
    }
  }
}
