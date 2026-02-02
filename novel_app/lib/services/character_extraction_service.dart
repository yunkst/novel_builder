import '../models/chapter.dart';
import 'logger_service.dart';
import 'database_service.dart';

/// 章节匹配结果
class ChapterMatch {
  final Chapter chapter;
  final int matchCount;
  final List<int> matchPositions; // 匹配位置索引

  ChapterMatch({
    required this.chapter,
    required this.matchCount,
    required this.matchPositions,
  });
}

/// 角色提取服务
/// 用于从章节内容中提取角色相关的上下文
class CharacterExtractionService {
  static final CharacterExtractionService _instance =
      CharacterExtractionService._internal();
  static final DatabaseService _databaseService = DatabaseService();

  factory CharacterExtractionService() {
    return _instance;
  }

  CharacterExtractionService._internal();

  /// 根据角色名和别名搜索匹配的章节
  ///
  /// [novelUrl] 小说URL
  /// [names] 角色名列表（正式名+别名）
  ///
  /// 返回匹配的章节列表，按章节索引升序排列
  Future<List<ChapterMatch>> searchChaptersByName({
    required String novelUrl,
    required List<String> names,
  }) async {
    if (names.isEmpty) return [];

    try {
      // 获取所有已缓存的章节
      final cachedChapters = await _databaseService.getCachedChapters(novelUrl);

      final matches = <ChapterMatch>[];

      for (final chapter in cachedChapters) {
        final content = chapter.content;
        if (content == null || content.isEmpty) continue;

        // 搜索所有名字的出现位置
        final matchPositions = <int>[];
        for (final name in names) {
          if (name.isEmpty) continue;

          int index = 0;
          while (true) {
            final pos = content.indexOf(name, index);
            if (pos == -1) break;
            matchPositions.add(pos);
            index = pos + name.length;
          }
        }

        // 去重并排序位置
        final uniquePositions = matchPositions.toSet().toList()..sort();

        if (uniquePositions.isNotEmpty) {
          matches.add(ChapterMatch(
            chapter: chapter,
            matchCount: uniquePositions.length,
            matchPositions: uniquePositions,
          ));
        }
      }

      // 按章节索引升序排列（故事发展时间线）
      matches.sort((a, b) {
        final aIndex = a.chapter.chapterIndex ?? 0;
        final bIndex = b.chapter.chapterIndex ?? 0;
        return aIndex.compareTo(bIndex);
      });

      return matches;
    } catch (e) {
      LoggerService.instance.e(
        '搜索章节失败',
        category: LogCategory.character,
        tags: ['search', 'error'],
      );
      return [];
    }
  }

  /// 提取匹配位置周围的上下文
  ///
  /// [content] 章节内容
  /// [matchPositions] 匹配位置列表
  /// [contextLength] 上下文长度（前后各一半）
  /// [useFullChapter] 是否使用整章
  ///
  /// 返回提取的上下文片段列表
  List<String> extractContextAroundMatches({
    required String content,
    required List<int> matchPositions,
    required int contextLength,
    required bool useFullChapter,
  }) {
    if (useFullChapter) {
      return [content];
    }

    final contexts = <String>[];
    final halfLength = contextLength ~/ 2;

    for (final pos in matchPositions) {
      final start = (pos - halfLength).clamp(0, content.length);
      final end = (pos + halfLength).clamp(0, content.length);

      if (start < end) {
        contexts.add(content.substring(start, end));
      }
    }

    return contexts;
  }

  /// 合并并去重上下文片段
  ///
  /// [contexts] 上下文片段列表（按位置排序）
  ///
  /// 返回合并后的内容（去重后的所有内容，无字数限制）
  /// 策略：
  /// - 按段落分割所有内容
  /// - 使用 Set 去重重复段落
  /// - 保留所有段落（不丢弃首尾）
  String mergeAndDeduplicateContexts(List<String> contexts) {
    if (contexts.isEmpty) return '';
    if (contexts.length == 1) return contexts[0];

    // 按段落分割所有内容
    final allParagraphs = <String>[];

    for (final context in contexts) {
      // 按换行符分割段落，去除空白段落
      final paragraphs = context
          .split('\n')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      allParagraphs.addAll(paragraphs);
    }

    if (allParagraphs.isEmpty) return '';

    // 使用 Set 去重（保持顺序）
    final seen = <String>{};
    final uniqueParagraphs = <String>[];

    for (final paragraph in allParagraphs) {
      if (!seen.contains(paragraph)) {
        seen.add(paragraph);
        uniqueParagraphs.add(paragraph);
      }
    }

    // 用换行符连接所有段落（无字数限制）
    return uniqueParagraphs.join('\n');
  }

  /// 合并并去重上下文片段（丢弃首尾段落版本）
  ///
  /// [contexts] 上下文片段列表（按位置排序）
  ///
  /// 返回合并后的内容（去重后的所有内容，无字数限制）
  /// 策略：
  /// - 按段落分割所有内容
  /// - 对每个片段，丢弃首尾段落（因为可能是截断的）
  /// - 使用 Set 去重重复段落
  /// - 保留所有有效段落
  String mergeAndDeduplicateContextsWithDrop(List<String> contexts) {
    if (contexts.isEmpty) return '';
    if (contexts.length == 1) return contexts[0];

    // 按片段分割并丢弃首尾段落
    final allParagraphs = <String>[];

    for (final context in contexts) {
      // 按换行符分割段落，去除空白段落
      final paragraphs = context
          .split('\n')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      // 如果有多个段落，丢弃首尾（可能是截断的）
      if (paragraphs.length > 2) {
        // 保留中间段落
        final middleParagraphs = paragraphs.sublist(1, paragraphs.length - 1);
        allParagraphs.addAll(middleParagraphs);
      } else if (paragraphs.length == 2) {
        // 只有2个段落时，都是"首尾"，都丢弃
        // 不添加任何内容
      } else if (paragraphs.length == 1) {
        // 只有1个段落时，无法丢弃，保留
        allParagraphs.add(paragraphs[0]);
      }
      // length == 0 时，不添加任何内容
    }

    if (allParagraphs.isEmpty) return '';

    // 使用 Set 去重（保持顺序）
    final seen = <String>{};
    final uniqueParagraphs = <String>[];

    for (final paragraph in allParagraphs) {
      if (!seen.contains(paragraph)) {
        seen.add(paragraph);
        uniqueParagraphs.add(paragraph);
      }
    }

    // 用换行符连接所有段落（无字数限制）
    return uniqueParagraphs.join('\n');
  }

  /// 计算选中章节的总内容长度
  ///
  /// [chapterMatches] 选中的章节匹配结果
  /// [contextLength] 上下文长度
  /// [useFullChapter] 是否使用整章
  ///
  /// 返回预计的内容长度
  int estimateContentLength({
    required List<ChapterMatch> chapterMatches,
    required int contextLength,
    required bool useFullChapter,
  }) {
    int totalLength = 0;

    for (final match in chapterMatches) {
      if (useFullChapter) {
        totalLength += match.chapter.content?.length ?? 0;
      } else {
        // 每个匹配位置提取 contextLength 字
        totalLength += match.matchCount * contextLength;
      }
    }

    return totalLength;
  }
}
