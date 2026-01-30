import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../services/database_service.dart';
import '../services/chapter_search_service.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import '../widgets/highlighted_text.dart';
import '../utils/toast_utils.dart';
import 'reader_screen.dart';

class ChapterSearchScreen extends StatefulWidget {
  final Novel novel;

  const ChapterSearchScreen({super.key, required this.novel});

  @override
  State<ChapterSearchScreen> createState() => _ChapterSearchScreenState();
}

class _ChapterSearchScreenState extends State<ChapterSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChapterSearchService _searchService = ChapterSearchService();
  final DatabaseService _databaseService = DatabaseService();

  List<ChapterSearchResult> _searchResults = [];
  List<Chapter> _chapters = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    try {
      final chapters =
          await _databaseService.getCachedNovelChapters(widget.novel.url);
      setState(() {
        _chapters = chapters;
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '加载章节列表失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'list', 'load', 'failed'],
      );
    }
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchService.searchInNovel(
        widget.novel.url,
        keyword.trim(),
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      ErrorHelper.showErrorWithLog(
        context,
        '搜索失败',
        stackTrace: stackTrace,
        category: LogCategory.database,
        tags: ['chapter', 'search', 'failed'],
      );
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
    });
  }

  /// 构建所有匹配项的高亮显示
  List<Widget> _buildMatchHighlights(ChapterSearchResult result) {
    if (!result.hasHighlight || result.matchPositions.isEmpty) {
      return const [
        SizedBox.shrink(),
      ];
    }

    return result.matchPositions.map((position) {
      // 提取匹配位置前后的上下文（前后20字）
      final start = (position.start - 20).clamp(0, result.content.length);
      final end = (position.end + 20).clamp(0, result.content.length);
      var contextText = result.content.substring(start, end);

      // 添加省略号
      if (start > 0) contextText = '...$contextText';
      if (end < result.content.length) contextText = '$contextText...';

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _SingleMatchHighlight(
          text: contextText,
          keywords: result.searchKeywords,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),
      );
    }).toList();
  }

  Chapter? _findChapterByUrl(String chapterUrl) {
    try {
      return _chapters.firstWhere((chapter) => chapter.url == chapterUrl);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索章节内容'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_hasSearched)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
              tooltip: '清除搜索',
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索 ${widget.novel.title} 的章节内容...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onSubmitted: _performSearch,
              onChanged: (value) {
                // 实时更新清除按钮的显示状态
                setState(() {});
              },
            ),
          ),

          // 搜索结果
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在搜索...'),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '输入关键词搜索章节内容',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '支持搜索章节标题和内容',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关内容',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试使用其他关键词',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '提示：可以搜索章节标题或内容',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final chapter = _findChapterByUrl(result.chapterUrl);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 2,
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: result.hasHighlight
                      ? TitleHighlight(
                          title: result.chapterTitle,
                          keywords: result.searchKeywords,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : Text(
                          result.chapterTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
                if (result.matchCount > 0)
                  Text(
                    ' (${result.matchCount}处匹配)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 匹配的文本片段列表（带高亮）
                ..._buildMatchHighlights(result),

                // 缓存时间
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '缓存于 ${result.cachedDate.toString().substring(0, 19).replaceAll('-', '/')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              if (chapter != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(
                      novel: widget.novel,
                      chapter: chapter,
                      chapters: _chapters,
                      // 传递搜索结果以便精确跳转
                      searchResult: result,
                    ),
                  ),
                );
              } else {
                LoggerService.instance.e(
                  '无法打开章节: Chapter not found for URL: ${result.chapterUrl}',
                  category: LogCategory.database,
                  tags: ['chapter', 'open', 'not-found'],
                );
                ToastUtils.show('无法打开该章节');
              }
            },
          ),
        );
      },
    );
  }
}

/// 单个匹配高亮组件
class _SingleMatchHighlight extends StatelessWidget {
  final String text;
  final List<String> keywords;
  final TextStyle? style;

  const _SingleMatchHighlight({
    required this.text,
    required this.keywords,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: style,
        children: _buildHighlightedSpans(context),
      ),
    );
  }

  List<TextSpan> _buildHighlightedSpans(BuildContext context) {
    final List<TextSpan> spans = [];
    int currentIndex = 0;

    // 查找所有关键词的匹配位置
    final List<MatchPosition> allMatches = [];
    for (final keyword in keywords) {
      if (keyword.isEmpty) continue;
      final pattern = RegExp(RegExp.escape(keyword), caseSensitive: false);
      for (final match in pattern.allMatches(text)) {
        allMatches.add(MatchPosition(
          start: match.start,
          end: match.end,
          matchedText: match.group(0) ?? '',
        ));
      }
    }

    // 按位置排序
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    // 构建高亮的文本片段
    for (final match in allMatches) {
      // 添加匹配前的普通文本
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
        ));
      }

      // 添加高亮的匹配文本
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      currentIndex = match.end;
    }

    // 添加剩余的普通文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
      ));
    }

    return spans;
  }
}
