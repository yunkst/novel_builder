import 'package:flutter/foundation.dart';
import '../models/chapter.dart';
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
      debugPrint('❌ 搜索章节失败: $e');
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
  /// [minGap] 最小间隔，小于此间隔则合并（默认100字）
  ///
  /// 返回合并后的内容
  String mergeAndDeduplicateContexts(
    List<String> contexts, {
    int minGap = 100,
  }) {
    if (contexts.isEmpty) return '';
    if (contexts.length == 1) return contexts[0];

    // 简化处理：直接用分隔符连接
    // 更复杂的去重需要记录每个片段的原始位置
    // 这里使用简单的策略：如果两个片段重叠很多，只保留一个
    final merged = <String>[];
    String? lastContext;

    for (final context in contexts) {
      if (lastContext == null) {
        lastContext = context;
        continue;
      }

      // 检查是否与上一个片段重叠较多
      final overlap = _calculateOverlap(lastContext, context);
      if (overlap > minGap) {
        // 合并：保留较长的片段
        if (context.length > lastContext.length) {
          lastContext = context;
        }
      } else {
        // 不重叠，添加上一个并开始新的
        merged.add(lastContext);
        lastContext = context;
      }
    }

    if (lastContext != null) {
      merged.add(lastContext);
    }

    return merged.join('\n\n...\n\n');
  }

  /// 计算两个字符串的重叠字符数
  int _calculateOverlap(String str1, String str2) {
    // 简单的重叠检测：检查 str1 的后缀是否与 str2 的前缀匹配
    int maxOverlap = 0;
    final maxPossible = str1.length < str2.length ? str1.length : str2.length;

    for (int i = 1; i <= maxPossible; i++) {
      if (str1.length >= i && str2.length >= i) {
        final suffix = str1.substring(str1.length - i);
        final prefix = str2.substring(0, i);
        if (suffix == prefix) {
          maxOverlap = i;
        }
      }
    }

    return maxOverlap;
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
