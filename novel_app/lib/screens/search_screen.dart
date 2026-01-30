import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../services/api_service_wrapper.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import 'chapter_list_screen.dart';
import '../utils/toast_utils.dart';
import '../core/di/api_service_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiServiceWrapper _api = ApiServiceProvider.instance;
  List<Novel> _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  // 源站过滤相关
  List<Map<String, dynamic>> _sourceSites = [];
  Set<String> _selectedSites = {};
  bool _showSiteFilter = false;

  // 异步操作控制
  bool _isSearchDisposed = false;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    try {
      await _api.init();
      await _loadSourceSites();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // API初始化失败，可能是未配置后端地址
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  /// 加载源站列表
  Future<void> _loadSourceSites() async {
    try {
      final sites = await _api.getSourceSites();
      // 检查页面是否已被销毁
      if (_isSearchDisposed || !mounted) return;

      if (mounted) {
        setState(() {
          _sourceSites = sites;
          // 默认选中所有站点 - 使用站点ID而不是站点名称
          _selectedSites = sites.map((site) => site['id'] as String).toSet();
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('加载源站列表失败: $e', context: context);
      }
    }
  }

  @override
  void dispose() {
    // 标记搜索已销毁，防止异步操作继续执行
    _isSearchDisposed = true;
    _searchController.dispose();
    // 移除 _api.dispose() 调用，避免关闭共享的Dio连接
    // _api.dispose(); // 已移除，ApiServiceWrapper是单例，不应由Screen关闭
    super.dispose();
  }

  Future<void> _searchNovels() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      if (mounted) {
        ToastUtils.showWarning('请输入搜索关键词', context: context);
      }
      return;
    }

    if (!_isInitialized) {
      LoggerService.instance.w(
        '搜索前未配置后端服务',
        category: LogCategory.network,
        tags: ['search', 'backend', 'not-configured'],
      );
      if (mounted) {
        ToastUtils.showError('请先配置后端服务地址', context: context);
      }
      return;
    }

    if (_selectedSites.isEmpty) {
      LoggerService.instance.w(
        '未选择搜索源站',
        category: LogCategory.network,
        tags: ['search', 'sites', 'none-selected'],
      );
      if (mounted) {
        ToastUtils.showWarning('请至少选择一个搜索源站', context: context);
      }
      return;
    }

    // 检查页面是否已被销毁
    if (_isSearchDisposed || !mounted) return;

    // 设置加载状态
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _searchResults = [];
      });
    }

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
      if (mounted) {
        ToastUtils.showLoading(searchInfo, context: context);
      }

      // 通过后端服务进行搜索，传递选中的站点
      final results = await _api.searchNovels(
        keyword,
        sites: _selectedSites.toList(),
      );

      // 再次检查页面状态，确保搜索结果回来时页面还存在
      if (_isSearchDisposed || !mounted) return;

      // 更新搜索结果
      if (mounted) {
        setState(() {
          _isLoading = false;
          _searchResults = results;
          if (results.isEmpty) {
            _errorMessage = '未找到相关小说，请尝试其他关键词或调整源站筛选';
          }
        });
      }

      // 显示搜索结果提示
      if (mounted) {
        if (results.isNotEmpty) {
          ToastUtils.showSuccess('找到 ${results.length} 个相关小说', context: context);
        } else {
          ToastUtils.showInfo('未找到相关小说，请尝试其他关键词或调整源站筛选', context: context);
        }
      }
    } catch (e, stackTrace) {
      // 再次检查页面状态
      if (_isSearchDisposed || !mounted) return;

      // 更新错误状态
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }

      if (mounted) {
        ErrorHelper.showErrorWithLog(
          context,
          '搜索小说失败',
          stackTrace: stackTrace,
          category: LogCategory.network,
          tags: ['search', 'api', 'failed'],
        );
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
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: '源站筛选',
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _showSiteFilter = !_showSiteFilter;
                  });
                }
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
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
                      if (mounted) {
                        setState(() {
                          _selectedSites = _sourceSites
                              .map((site) => site['id'] as String)
                              .toSet();
                        });
                      }
                    },
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _selectedSites.clear();
                        });
                      }
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
                  if (mounted) {
                    setState(() {
                      if (selected) {
                        _selectedSites.add(siteId);
                      } else {
                        _selectedSites.remove(siteId);
                      }
                    });
                  }
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
