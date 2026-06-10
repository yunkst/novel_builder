/// Riverpod Search Screen Providers
///
/// 此文件定义搜索页面相关的 Provider
/// 使用 @riverpod 注解自动生成代码
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/novel.dart';
import '../../services/api_service_wrapper.dart';
import '../../services/logger_service.dart';

part 'search_screen_providers.g.dart';

/// 搜索状态类
class SearchState {
  final List<Novel> results;
  final bool isLoading;
  final String? errorMessage;
  final bool isInitialized;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isInitialized = false,
  });

  SearchState copyWith({
    List<Novel>? results,
    bool? isLoading,
    String? errorMessage,
    bool? isInitialized,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// 源站列表状态类
class SourceSitesState {
  final List<Map<String, dynamic>> sites;
  final Set<String> selectedSiteIds;
  final bool showFilter;

  const SourceSitesState({
    this.sites = const [],
    this.selectedSiteIds = const {},
    this.showFilter = false,
  });

  SourceSitesState copyWith({
    List<Map<String, dynamic>>? sites,
    Set<String>? selectedSiteIds,
    bool? showFilter,
  }) {
    return SourceSitesState(
      sites: sites ?? this.sites,
      selectedSiteIds: selectedSiteIds ?? this.selectedSiteIds,
      showFilter: showFilter ?? this.showFilter,
    );
  }

  /// 获取选中站点的显示名称
  String getSelectedSiteNames() {
    if (selectedSiteIds.isEmpty || selectedSiteIds.length == sites.length) {
      return '';
    }
    return sites
        .where((site) => selectedSiteIds.contains(site['id'] as String))
        .map((site) => site['name'] as String)
        .join(', ');
  }
}

/// 搜索状态 Provider
///
/// 管理搜索结果和搜索状态
@riverpod
class SearchScreenNotifier extends _$SearchScreenNotifier {
  @override
  SearchState build() {
    return const SearchState();
  }

  /// 开始初始化 API
  Future<void> initialize(ApiServiceWrapper api) async {
    LoggerService.instance.d(
      '开始初始化搜索 API',
      category: LogCategory.network,
      tags: ['provider', 'search', 'init'],
    );
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await api.init();
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        errorMessage: null,
      );
      LoggerService.instance.i(
        '搜索 API 初始化成功',
        category: LogCategory.ui,
        tags: ['provider', 'search', 'init'],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        '搜索 API 初始化失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.network,
        tags: ['provider', 'search', 'init'],
      );
      state = state.copyWith(
        isLoading: false,
        isInitialized: false,
        errorMessage: '后端服务连接失败: ${e.toString()}',
      );
      rethrow; // 让调用者知道初始化失败
    }
  }

  /// 开始搜索
  Future<void> searchNovels(
    ApiServiceWrapper api,
    String keyword,
    List<String> sites,
  ) async {
    if (keyword.isEmpty) {
      return;
    }

    if (!state.isInitialized) {
      // 如果状态中已有错误信息（来自初始化失败），保留它；否则使用默认消息
      state = state.copyWith(
        errorMessage: state.errorMessage ?? '请先配置后端服务地址',
      );
      return;
    }

    if (sites.isEmpty) {
      state = state.copyWith(
        errorMessage: '请至少选择一个搜索源站',
      );
      return;
    }

    LoggerService.instance.d(
      '开始搜索小说: keyword=$keyword, sites=$sites',
      category: LogCategory.network,
      tags: ['provider', 'search', 'search'],
    );

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      results: [],
    );

    try {
      final results = await api.searchNovels(keyword, sites: sites);
      state = state.copyWith(
        isLoading: false,
        results: results,
        errorMessage: results.isEmpty ? '未找到相关小说，请尝试其他关键词或调整源站筛选' : null,
      );
      LoggerService.instance.i(
        '搜索完成: keyword=$keyword, results=${results.length}',
        category: LogCategory.ui,
        tags: ['provider', 'search', 'search'],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        '搜索小说失败: keyword=$keyword, $e',
        stackTrace: st.toString(),
        category: LogCategory.network,
        tags: ['provider', 'search', 'search'],
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// 源站状态 Provider
///
/// 管理源站列表和筛选状态
@riverpod
class SourceSitesNotifier extends _$SourceSitesNotifier {
  @override
  SourceSitesState build() {
    return const SourceSitesState();
  }

  /// 加载源站列表
  Future<void> loadSourceSites(ApiServiceWrapper api) async {
    LoggerService.instance.d(
      '开始加载源站列表',
      category: LogCategory.network,
      tags: ['provider', 'search', 'load-sites'],
    );
    try {
      final sites = await api.getSourceSites();
      state = state.copyWith(
        sites: sites,
        selectedSiteIds: sites.map((site) => site['id'] as String).toSet(),
      );
      LoggerService.instance.i(
        '源站列表加载成功: count=${sites.length}',
        category: LogCategory.ui,
        tags: ['provider', 'search', 'load-sites'],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        '加载源站列表失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.network,
        tags: ['provider', 'search', 'load-sites'],
      );
      // 加载失败，保持空列表，但记录错误以便调试
      // 如果sites已经不为空，说明之前加载过，那么保持之前的数据
      if (state.sites.isEmpty) {
        // 首次加载失败，sites保持空列表
        // 不更新状态，保持默认值
      }
      // 如果之前有数据，保持之前的数据不变
    }
  }

  /// 切换过滤面板显示
  void toggleFilter() {
    state = state.copyWith(showFilter: !state.showFilter);
  }

  /// 选择/取消选择站点
  void toggleSite(String siteId) {
    final newSelected = Set<String>.from(state.selectedSiteIds);
    if (newSelected.contains(siteId)) {
      newSelected.remove(siteId);
    } else {
      newSelected.add(siteId);
    }
    state = state.copyWith(selectedSiteIds: newSelected);
  }

  /// 全选
  void selectAll() {
    state = state.copyWith(
      selectedSiteIds: state.sites.map((site) => site['id'] as String).toSet(),
    );
  }

  /// 清空选择
  void clearSelection() {
    state = state.copyWith(selectedSiteIds: {});
  }

  /// 检查是否有选中的站点
  bool get hasSelectedSites => state.selectedSiteIds.isNotEmpty;
}
