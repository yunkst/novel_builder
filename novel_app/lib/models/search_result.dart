/// 简化的搜索结果模型
class SearchResult {
  final String novelUrl;
  final String novelTitle;
  final String novelAuthor;
  final String? coverUrl;
  final String? description;

  const SearchResult({
    required this.novelUrl,
    required this.novelTitle,
    required this.novelAuthor,
    this.coverUrl,
    this.description,
  });

  /// 从JSON创建实例
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      novelUrl: json['novel_url'] ?? '',
      novelTitle: json['novel_title'] ?? '',
      novelAuthor: json['novel_author'] ?? '',
      coverUrl: json['cover_url'],
      description: json['description'],
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'novel_url': novelUrl,
      'novel_title': novelTitle,
      'novel_author': novelAuthor,
      'cover_url': coverUrl,
      'description': description,
    };
  }
}

/// 章节搜索结果
class ChapterSearchResult {
  final String novelUrl;
  final String novelTitle;
  final String novelAuthor;
  final String chapterUrl;
  final String chapterTitle;
  final int chapterIndex;
  final String content;
  final List<String> searchKeywords;
  final List<MatchPosition> matchPositions;
  final DateTime cachedAt;

  ChapterSearchResult({
    required this.novelUrl,
    required this.novelTitle,
    required this.novelAuthor,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.content,
    required this.searchKeywords,
    required this.matchPositions,
    required this.cachedAt,
  });

  /// 获取匹配数量
  int get matchCount => matchPositions.length;

  /// 获取第一个匹配位置
  MatchPosition? get firstMatch =>
      matchPositions.isNotEmpty ? matchPositions.first : null;

  /// 获取章节索引文本
  String get chapterIndexText => '第 ${chapterIndex + 1} 章';

  /// 获取匹配的文本片段
  String get matchedText {
    if (matchPositions.isEmpty) return '';
    final pos = matchPositions.first;
    return content.substring(pos.start, pos.end);
  }

  /// 获取缓存日期
  DateTime get cachedDate => cachedAt;

  /// 是否有高亮匹配
  bool get hasHighlight => matchPositions.isNotEmpty;
}

/// 匹配位置信息
class MatchPosition {
  final int start;
  final int end;
  final String matchedText;

  const MatchPosition({
    required this.start,
    required this.end,
    required this.matchedText,
  });
}

/// 缓存的小说信息
class CachedNovelInfo {
  final String novelUrl;
  final String novelTitle;
  final String novelAuthor;
  final String? coverUrl;
  final String? description;
  final int chapterCount;
  final DateTime lastUpdated;

  const CachedNovelInfo({
    required this.novelUrl,
    required this.novelTitle,
    required this.novelAuthor,
    this.coverUrl,
    this.description,
    required this.chapterCount,
    required this.lastUpdated,
  });

  /// 获取章节数量文本
  String get chapterCountText => '$chapterCount 章节';
}
