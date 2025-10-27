import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';
import 'chapter_list_screen.dart';
import 'cache_search_screen.dart';
import '../utils/toast_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiServiceWrapper _api = ApiServiceWrapper();
  final DatabaseService _databaseService = DatabaseService();
  List<Novel> _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    try {
      await _api.init();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // API初始化失败，可能是未配置后端地址
      setState(() {
        _isInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _api.dispose();
    super.dispose();
  }

  /// 检查是否有缓存内容
  Future<bool> _checkHasCachedContent() async {
    try {
      // 简单查询数据库是否有相关章节缓存
      final results = await _databaseService.searchInCachedContent(
        _searchController.text.trim(),
        novelUrl: null, // 查询所有缓存内容，不限制小说URL
      );

      return results.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _searchNovels() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      ToastUtils.showWarning(context, '请输入搜索关键词');
      return;
    }

    if (!_isInitialized) {
      ToastUtils.showError(context, '请先配置后端服务地址');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      // 显示开始搜索的提示
      ToastUtils.showLoading(context, '正在搜索 "$keyword"...');

      // 通过后端服务进行搜索
      final results = await _api.searchNovels(keyword);

      setState(() {
        _isLoading = false;
        _searchResults = results;
        if (results.isEmpty) {
          _errorMessage = '未找到相关小说，请尝试其他关键词';
        }
      });

      // 显示搜索结果提示
      if (mounted) {
        if (results.isNotEmpty) {
          ToastUtils.showSuccess(context, '找到 ${results.length} 个相关小说');
        } else {
          ToastUtils.showInfo(context, '未找到相关小说，请尝试其他关键词');
        }
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ToastUtils.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索小说'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          FutureBuilder<bool>(
            future: _checkHasCachedContent(),
            builder: (context, snapshot) {
              final hasCachedContent = snapshot.data ?? false;
              if (!hasCachedContent) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: const Icon(Icons.storage),
                tooltip: '搜索缓存内容',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CacheSearchScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
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
                      subtitle: Text('作者: ${novel.author} · 来源: ${Uri.tryParse(novel.url)?.host ?? '未知站点'}'),
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
