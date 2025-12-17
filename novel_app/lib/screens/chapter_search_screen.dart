import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../services/database_service.dart';
import '../services/chapter_search_service.dart';
import '../widgets/highlighted_text.dart';
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
    } catch (e) {
      debugPrint('加载章节列表失败: $e');
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
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
    });
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '输入关键词搜索章节内容',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '支持搜索章节标题和内容',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关内容',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试使用其他关键词',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '提示：可以搜索章节标题或内容',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
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
            title: result.hasHighlight
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 章节索引和匹配信息
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        result.chapterIndexText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    if (result.matchCount > 0) const SizedBox(width: 8),
                    if (result.matchCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${result.matchCount} 处匹配',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // 匹配的文本片段（带高亮）
                if (result.hasHighlight)
                  SearchResultHighlight(
                    originalText: result.content,
                    keywords: result.searchKeywords,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      result.matchedText,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // 缓存时间
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '缓存于 ${result.cachedDate.toString().substring(0, 19).replaceAll('-', '/')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('无法打开该章节')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
