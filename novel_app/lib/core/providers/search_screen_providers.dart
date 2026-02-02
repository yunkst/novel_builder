/// Riverpod Search Screen Providers
///
/// 此文件定义搜索页面相关的 Provider
/// 使用 @riverpod 注解自动生成代码
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/novel.dart';
import '../../services/api_service_wrapper.dart';

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
    try {
      await api.init();
      state = state.copyWith(isInitialized: true);
    } catch (e) {
      state = state.copyWith(isInitialized: false);
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
      state = state.copyWith(
        errorMessage: '请先配置后端服务地址',
      );
      return;
    }

    if (sites.isEmpty) {
      state = state.copyWith(
        errorMessage: '请至少选择一个搜索源站',
      );
      return;
    }

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
    } catch (e) {
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
    try {
      final sites = await api.getSourceSites();
      state = state.copyWith(
        sites: sites,
        selectedSiteIds: sites.map((site) => site['id'] as String).toSet(),
      );
    } catch (e) {
      // 加载失败，保持空列表
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
