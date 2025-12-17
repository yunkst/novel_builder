import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/search_result.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/cache_search_service.dart';
import '../services/database_service.dart';
import 'reader_screen.dart';

class CacheSearchScreen extends StatefulWidget {
  const CacheSearchScreen({super.key});

  @override
  State<CacheSearchScreen> createState() => _CacheSearchScreenState();
}

class _CacheSearchScreenState extends State<CacheSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CacheSearchService _searchService = CacheSearchService();
  final ScrollController _scrollController = ScrollController();

  List<ChapterSearchResult> _searchResults = [];
  List<CachedNovelInfo> _cachedNovels = [];
  bool _isLoading = false;
  bool _isLoadingNovels = false;
  bool _hasSearched = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  int _totalCount = 0;
  String? _selectedNovelUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCachedNovels();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载已缓存小说列表
  Future<void> _loadCachedNovels() async {
    setState(() {
      _isLoadingNovels = true;
    });

    try {
      final novels = await _searchService.getCachedNovels();
      setState(() {
        _cachedNovels = novels;
        _isLoadingNovels = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingNovels = false;
      });
    }
  }

  /// 执行搜索
  Future<void> _performSearch({bool isLoadMore = false}) async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入搜索关键字')),
      );
      return;
    }

    // 如果没有选择小说，显示警告
    if (_selectedNovelUrl == null && !isLoadMore) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('搜索所有已缓存小说'),
          content: const Text(
            '您没有选择特定小说，这将搜索所有已缓存小说的内容。\n\n'
            '是否继续搜索所有小说？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return;
      }
    }

    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _hasSearched = false;
        _currentPage = 1;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await _searchService.searchInCache(
        keyword: keyword,
        novelUrl: _selectedNovelUrl,
        page: _currentPage,
        pageSize: 20,
      );

      setState(() {
        if (isLoadMore) {
          _searchResults.addAll(result.results);
        } else {
          _searchResults = result.results;
          _totalCount = result.totalCount;
        }
        _hasNextPage = result.hasMore;
        _hasSearched = true;
        _isLoading = false;
        _errorMessage = result.error;

        if (isLoadMore) {
          _currentPage++;
        }
      });

      if (!isLoadMore && _currentPage == 1) {
        _currentPage++;
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _errorMessage = e.toString();
      });
    }
  }

  /// 滚动到底部加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoading &&
        _hasNextPage) {
      _performSearch(isLoadMore: true);
    }
  }

  /// 打开章节内容
  void _openChapter(ChapterSearchResult result) async {
    try {
      // 创建一个 Chapter 对象用于导航
      final chapter = Chapter(
        title: result.chapterTitle,
        url: result.chapterUrl,
        isCached: true,
      );

      // 尝试获取小说信息
      final databaseService = DatabaseService();
      final bookshelfNovels = await databaseService.getBookshelf();

      Novel? targetNovel;
      // 在书架中查找匹配的小说
      for (final novel in bookshelfNovels) {
        if (novel.url == result.novelUrl) {
          targetNovel = novel;
          break;
        }
      }

      // 如果在书架中找不到，创建一个基本的 Novel 对象
      targetNovel ??= Novel(
        title: _extractNovelTitle(result),
        author: '未知作者',
        url: result.novelUrl,
      );

      // 获取该小说的所有章节
      final chapters = await databaseService.getCachedNovelChapters(result.novelUrl);

      if (chapters.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取章节列表')),
          );
        }
        return;
      }

      // 跳转到阅读器
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(
              novel: targetNovel!,
              chapter: chapter,
              chapters: chapters,
              // 传递搜索结果以便精确定位
              searchResult: result,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开章节失败: $e')),
        );
      }
    }
  }

  /// 从搜索结果中提取小说标题
  String _extractNovelTitle(ChapterSearchResult result) {
    // 尝试从章节标题中提取小说标题
    final title = result.chapterTitle;

    // 如果标题包含"第"字，可能是章节名，尝试提取前面的部分
    final chapterIndex = title.indexOf('第');
    if (chapterIndex > 0) {
      return title.substring(0, chapterIndex).trim();
    }

    // 如果标题很短，可能已经是小说名
    if (title.length <= 20) {
      return title;
    }

    // 否则截取前20个字符作为小说名
    return '${title.substring(0, 20).trim()}...';
  }

  /// 构建小说选择器
  Widget _buildNovelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '搜索范围',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedNovelUrl,
                hint: const Text('请选择小说进行搜索'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('所有已缓存小说'),
                  ),
                  ..._cachedNovels.map((novel) {
                    return DropdownMenuItem(
                      value: novel.novelUrl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            novel.novelTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${novel.novelAuthor} · ${novel.chapterCountText}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedNovelUrl = value;
                  });
                  // 如果已经搜索过，自动重新搜索
                  if (_hasSearched && _searchController.text.isNotEmpty) {
                    _performSearch();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索框
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索缓存内容...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _hasSearched = false;
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
              inputFormatters: [
                LengthLimitingTextInputFormatter(100),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _performSearch,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.search),
          ),
        ],
      ),
    );
  }

  /// 构建搜索结果项
  Widget _buildResultItem(ChapterSearchResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          result.chapterTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              result.chapterIndexText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                result.matchedText,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  '缓存于 ${_formatDate(result.cachedDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openChapter(result),
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 构建搜索状态视图
  Widget _buildSearchStatusView() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '在已缓存内容中搜索',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入关键字开始搜索',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '搜索出错',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('重试'),
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
              Icons.find_in_page,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关内容',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试使用不同的关键字',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 搜索结果统计
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Text(
            '找到 $_totalCount 个相关章节',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        // 搜索结果列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _searchResults.length + (_hasNextPage ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _searchResults.length) {
                // 加载更多指示器
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return _buildResultItem(_searchResults[index]);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索缓存内容'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isLoadingNovels)
            const LinearProgressIndicator()
          else
            _buildNovelSelector(),
          _buildSearchBar(),
          Expanded(
            child: _buildSearchStatusView(),
          ),
        ],
      ),
    );
  }
}
