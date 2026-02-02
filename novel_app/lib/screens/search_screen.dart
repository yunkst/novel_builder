import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/search_screen_providers.dart';
import '../core/providers/service_providers.dart';
import '../screens/chapter_list_screen_riverpod.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import '../utils/toast_utils.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchScreenNotifierProvider);
    final sourceSitesState = ref.watch(sourceSitesNotifierProvider);
    final apiService = ref.watch(apiServiceWrapperProvider);

    // 初始化 API 和源站列表（仅在第一次加载时执行）
    ref.listen<SearchState>(searchScreenNotifierProvider, (previous, next) {
      if (previous == null ||
          (!previous.isInitialized && !next.isInitialized)) {
        // 首次初始化
        _initializeApiAndSites(apiService);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索小说'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 源站过滤按钮
          if (sourceSitesState.sites.isNotEmpty)
            IconButton(
              icon: Icon(
                sourceSitesState.showFilter
                    ? Icons.filter_list_off
                    : Icons.filter_list,
                color: sourceSitesState.selectedSiteIds.length <
                        sourceSitesState.sites.length
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: '源站筛选',
              onPressed: () {
                ref.read(sourceSitesNotifierProvider.notifier).toggleFilter();
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 源站过滤面板
          if (sourceSitesState.showFilter && sourceSitesState.sites.isNotEmpty)
            _buildSiteFilterPanel(sourceSitesState),

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
                      suffixText:
                          sourceSitesState.getSelectedSiteNames().isNotEmpty
                              ? '${sourceSitesState.selectedSiteIds.length}个源站'
                              : null,
                      suffixStyle: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(
                      apiService,
                      _searchController.text,
                      sourceSitesState.selectedSiteIds.toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: searchState.isLoading
                      ? null
                      : () => _performSearch(
                            apiService,
                            _searchController.text,
                            sourceSitesState.selectedSiteIds.toList(),
                          ),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          if (searchState.isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (searchState.errorMessage != null &&
              searchState.errorMessage!.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  searchState.errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            )
          else if (searchState.results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: searchState.results.length,
                itemBuilder: (context, index) {
                  final novel = searchState.results[index];
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
                                ChapterListScreenRiverpod(novel: novel),
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

  /// 初始化 API 和源站列表
  void _initializeApiAndSites(
    dynamic apiService,
  ) async {
    try {
      await ref
          .read(searchScreenNotifierProvider.notifier)
          .initialize(apiService);
      await ref
          .read(sourceSitesNotifierProvider.notifier)
          .loadSourceSites(apiService);
    } catch (e) {
      // 初始化失败，保持未初始化状态
    }
  }

  /// 执行搜索
  Future<void> _performSearch(
    dynamic apiService,
    String keyword,
    List<String> sites,
  ) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      ToastUtils.showWarning('请输入搜索关键词', context: context);
      return;
    }

    final searchState = ref.read(searchScreenNotifierProvider);
    if (!searchState.isInitialized) {
      LoggerService.instance.w(
        '搜索前未配置后端服务',
        category: LogCategory.network,
        tags: ['search', 'backend', 'not-configured'],
      );
      ToastUtils.showError('请先配置后端服务地址', context: context);
      return;
    }

    if (sites.isEmpty) {
      LoggerService.instance.w(
        '未选择搜索源站',
        category: LogCategory.network,
        tags: ['search', 'sites', 'none-selected'],
      );
      ToastUtils.showWarning('请至少选择一个搜索源站', context: context);
      return;
    }

    // 显示开始搜索的提示
    final sourceSitesState = ref.read(sourceSitesNotifierProvider);
    String searchInfo = '正在搜索 "$trimmedKeyword"';
    if (sites.isNotEmpty && sites.length < sourceSitesState.sites.length) {
      final selectedSiteNames = sourceSitesState.sites
          .where((site) => sites.contains(site['id'] as String))
          .map((site) => site['name'] as String)
          .join(', ');
      searchInfo += ' (源站: $selectedSiteNames)';
    }
    ToastUtils.showLoading(searchInfo, context: context);

    // 执行搜索
    try {
      await ref
          .read(searchScreenNotifierProvider.notifier)
          .searchNovels(apiService, trimmedKeyword, sites);

      // 显示搜索结果提示
      final newState = ref.read(searchScreenNotifierProvider);
      if (!mounted) return;

      if (newState.results.isNotEmpty) {
        ToastUtils.showSuccess('找到 ${newState.results.length} 个相关小说',
            context: context);
      } else {
        ToastUtils.showInfo('未找到相关小说，请尝试其他关键词或调整源站筛选', context: context);
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '搜索小说失败',
        stackTrace: stackTrace,
        category: LogCategory.network,
        tags: ['search', 'api', 'failed'],
      );
    }
  }

  /// 构建源站过滤面板
  Widget _buildSiteFilterPanel(
    SourceSitesState sourceSitesState,
  ) {
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
                      ref
                          .read(sourceSitesNotifierProvider.notifier)
                          .selectAll();
                    },
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(sourceSitesNotifierProvider.notifier)
                          .clearSelection();
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
            children: sourceSitesState.sites.map((site) {
              final siteId = site['id'] as String;
              final siteName = site['name'] as String;
              final siteDescription =
                  site['description'] as String? ?? siteName;
              final isSelected =
                  sourceSitesState.selectedSiteIds.contains(siteId);

              return FilterChip(
                label: Text(siteName),
                selected: isSelected,
                onSelected: (selected) {
                  ref
                      .read(sourceSitesNotifierProvider.notifier)
                      .toggleSite(siteId);
                },
                tooltip: siteDescription,
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
              );
            }).toList(),
          ),
          if (sourceSitesState.selectedSiteIds.isEmpty)
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
