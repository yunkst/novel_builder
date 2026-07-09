/// 章节读取子执行器 — read_chapter_content / list_chapters / search_in_chapters
///
/// read_chapter_content 是特例：返回纯文本（不是 JSON），其他两个返回 JSON。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../logger_service.dart';
import '../tool_arg_parser.dart' show ToolArgParser;
import '../agent_scenario.dart';
import '../tool_executor_helpers.dart';

class ChapterReadExecutor with ToolExecutorHelpers {
  ChapterReadExecutor(this.ref);
  @override
  final Ref ref;

  Future<String> readChapterContent(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (position, posErr) = parser.requireInt('position');
    if (posErr != null) return posErr;
    final resolveResult = await resolveChapterUrlByPosition(ctx, position);
    if (resolveResult.errorJson != null) {
      return jsonEncode(resolveResult.errorJson);
    }
    final chapterUrl = resolveResult.chapterUrl!;

    final repo = ref.read(chapterRepositoryProvider);
    final content = await repo.getCachedChapter(chapterUrl);
    if (content == null || content.isEmpty) {
      LoggerService.instance.w('章节未缓存: position=$position',
          category: LogCategory.ai,
          tags: ['agent', 'tool', 'read_chapter_content', 'not_cached']);
      return jsonEncode({
        'error': 'not_cached',
        'message':
            '位置 $position 的章节存在但内容尚未缓存，无法读取。',
        'suggested_action': '请告知用户该章节需要先加载/缓存。',
      });
    }

    LoggerService.instance.i('读取章节成功: position=$position (${content.length} chars)',
        category: LogCategory.ai, tags: ['agent', 'tool', 'read_chapter_content']);
    return content;
  }

  Future<String> listChapters(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final novelResolve = await resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final chapters = await repo.getCachedNovelChapters(novelUrl);
    final list = <Map<String, dynamic>>[];
    for (var i = 0; i < chapters.length; i++) {
      final c = chapters[i];
      list.add({
        'position': i + 1,
        'title': c.title,
        'chapterIndex': c.chapterIndex,
        'isCached': c.isCached,
        'isUserInserted': c.isUserInserted,
      });
    }

    final novelContext = buildCurrentNovelContext(ctx);
    LoggerService.instance.i(
        '列出章节: ${list.length} 章 (currentNovelId=${ctx?.currentNovelId})',
        category: LogCategory.ai, tags: ['agent', 'tool', 'list_chapters']);
    return jsonEncode({
      'novel': novelContext,
      'chapters': list,
      'count': list.length,
    });
  }

  Future<String> searchInChapters(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (keyword, kwErr) = parser.requireString('keyword');
    if (kwErr != null) return kwErr;
    final novelResolve = await resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final novelUrl = novelResolve.url!;

    final repo = ref.read(chapterRepositoryProvider);
    final results = await repo.searchInCachedContent(
      keyword,
      novelUrl: novelUrl,
    );

    // 解析每个结果项的 position（按 list_chapters 顺序）
    final chapters = await repo.getCachedNovelChapters(novelUrl);
    final urlToPosition = <String, int>{
      for (var i = 0; i < chapters.length; i++) chapters[i].url: i + 1,
    };

    final list = results.map((r) => {
          'position': urlToPosition[r.chapterUrl],
          'chapterTitle': r.chapterTitle,
          'matchedText': r.matchPositions.isNotEmpty
              ? r.content.substring(r.matchPositions.first.start, r.matchPositions.first.end)
              : '',
          'matchCount': r.matchCount,
        }).toList();

    final novelContext = buildCurrentNovelContext(ctx);
    LoggerService.instance.i(
        '章节搜索: keyword="$keyword", ${list.length} 个匹配',
        category: LogCategory.ai, tags: ['agent', 'tool', 'search_in_chapters']);
    return jsonEncode({
      'novel': novelContext,
      'results': list,
      'count': list.length,
    });
  }
}
