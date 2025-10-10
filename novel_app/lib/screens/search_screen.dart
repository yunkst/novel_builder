import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../services/novel_crawler_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/crawlers/crawler_factory.dart';
import '../services/crawlers/base_crawler.dart';
import 'chapter_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NovelCrawlerService _crawlerService = NovelCrawlerService();
  List<Novel> _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final CrawlerFactory _factory = CrawlerFactory();

  @override
  void dispose() {
    _searchController.dispose();
    _crawlerService.dispose();
    super.dispose();
  }

  Future<void> _searchNovels() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _errorMessage = '请输入搜索关键词';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      // 读取启用的源站点
      final prefs = await SharedPreferences.getInstance();
      final enabledHosts = prefs.getStringList('enabled_sources');
      final crawlers = _factory.registered;
      final List<BaseCrawler> activeCrawlers = enabledHosts == null || enabledHosts.isEmpty
          ? crawlers
          : crawlers.where((c) => enabledHosts.contains(Uri.parse(c.baseUrl).host)).toList();

      if (activeCrawlers.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '未启用任何源站点，请到设置中启用';
        });
        return;
      }

      // 并行搜索，流式追加结果
      final List<Novel> aggregated = [];
      final futures = activeCrawlers.map((crawler) async {
        try {
          final res = await crawler.searchNovels(keyword);
          if (res.isNotEmpty) {
            setState(() {
              aggregated.addAll(res);
              _searchResults = List.of(aggregated);
            });
          }
        } catch (_) {
          // 忽略单站点错误，继续其他站点
        }
      }).toList();

      await Future.wait(futures);
      setState(() {
        _isLoading = false;
        if (aggregated.isEmpty) {
          _errorMessage = '未找到相关小说，请尝试其他关键词';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '搜索失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索小说'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '请输入小说名称或作者',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchNovels(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchNovels,
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final novel = _searchResults[index];
                  final host = Uri.tryParse(novel.url)?.host ?? '未知站点';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(
                        novel.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('作者: ${novel.author} · 来源: $host'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChapterListScreen(novel: novel),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('输入关键词搜索小说'),
              ),
            ),
        ],
      ),
    );
  }
}
