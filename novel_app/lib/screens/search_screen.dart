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

  // 源站过滤相关
  List<Map<String, dynamic>> _sourceSites = [];
  Set<String> _selectedSites = {};
  bool _showSiteFilter = false;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    try {
      await _api.init();
      await _loadSourceSites();
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

  /// 加载源站列表
  Future<void> _loadSourceSites() async {
    try {
      final sites = await _api.getSourceSites();
      setState(() {
        _sourceSites = sites;
        // 默认选中所有站点 - 使用站点ID而不是站点名称
        _selectedSites = sites.map((site) => site['id'] as String).toSet();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载源站列表失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

    if (_selectedSites.isEmpty) {
      ToastUtils.showWarning(context, '请至少选择一个搜索源站');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      // 构建搜索信息
      String searchInfo = '正在搜索 "$keyword"';
      if (_selectedSites.isNotEmpty &&
          _selectedSites.length < _sourceSites.length) {
        // 获取选中站点的显示名称
        final selectedSiteNames = _sourceSites
            .where((site) => _selectedSites.contains(site['id'] as String))
            .map((site) => site['name'] as String)
            .join(', ');
        searchInfo += ' (源站: $selectedSiteNames)';
      }

      // 显示开始搜索的提示
      ToastUtils.showLoading(context, searchInfo);

      // 通过后端服务进行搜索，传递选中的站点
      final results = await _api.searchNovels(
        keyword,
        sites: _selectedSites.toList(),
      );

      setState(() {
        _isLoading = false;
        _searchResults = results;
        if (results.isEmpty) {
          _errorMessage = '未找到相关小说，请尝试其他关键词或调整源站筛选';
        }
      });

      // 显示搜索结果提示
      if (mounted) {
        if (results.isNotEmpty) {
          ToastUtils.showSuccess(context, '找到 ${results.length} 个相关小说');
        } else {
          ToastUtils.showInfo(context, '未找到相关小说，请尝试其他关键词或调整源站筛选');
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
          // 源站过滤按钮
          if (_sourceSites.isNotEmpty)
            IconButton(
              icon: Icon(
                _showSiteFilter ? Icons.filter_list_off : Icons.filter_list,
                color: _selectedSites.length < _sourceSites.length
                    ? Colors.blue
                    : null,
              ),
              tooltip: '源站筛选',
              onPressed: () {
                setState(() {
                  _showSiteFilter = !_showSiteFilter;
                });
              },
            ),
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
          // 源站过滤面板
          if (_showSiteFilter && _sourceSites.isNotEmpty)
            _buildSiteFilterPanel(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '请输入小说名称或作者',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixText: _selectedSites.isNotEmpty &&
                              _selectedSites.length < _sourceSites.length
                          ? '${_selectedSites.length}个源站'
                          : null,
                      suffixStyle: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                      ),
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
                      subtitle: Text(
                          '作者: ${novel.author} · 来源: ${Uri.tryParse(novel.url)?.host ?? '未知站点'}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChapterListScreen(novel: novel),
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

  /// 构建源站过滤面板
  Widget _buildSiteFilterPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择搜索源站',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedSites = _sourceSites
                            .map((site) => site['id'] as String)
                            .toSet();
                      });
                    },
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedSites.clear();
                      });
                    },
                    child: const Text('清空'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _sourceSites.map((site) {
              final siteId = site['id'] as String;
              final siteName = site['name'] as String;
              final siteDescription =
                  site['description'] as String? ?? siteName;
              final isSelected = _selectedSites.contains(siteId);

              return FilterChip(
                label: Text(siteName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSites.add(siteId);
                    } else {
                      _selectedSites.remove(siteId);
                    }
                  });
                },
                tooltip: siteDescription,
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
              );
            }).toList(),
          ),
          if (_selectedSites.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '请至少选择一个源站',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
