import 'package:flutter/foundation.dart';

/// 分页控制器
///
/// 管理分页数据的加载状态和数据集合。
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> {
///   late final PaginationController<MyModel> _pagination;
///
///   @override
///   void initState() {
///     super.initState();
///     _pagination = PaginationController<MyModel>(
///       fetchPage: (page) async {
///         final response = await api.fetchItems(page: page);
///         return response.items;
///       },
///     );
///     _pagination.refresh();
///   }
///
///   @override
///   void dispose() {
///     _pagination.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return AnimatedBuilder(
///       animation: _pagination,
///       builder: (context, child) {
///         return ListView.builder(
///           itemCount: _pagination.items.length +
///                       (_pagination.hasMore ? 1 : 0),
///           itemBuilder: (context, index) {
///             if (index == _pagination.items.length) {
///               // 加载更多指示器
///               _pagination.loadNextPage();
///               return const CircularProgressIndicator();
///             }
///             return ItemWidget(item: _pagination.items[index]);
///           },
///         );
///       },
///     );
///   }
/// }
/// ```
///
/// 功能特性：
/// - 自动管理分页加载状态
/// - 支持下拉刷新和上拉加载更多
/// - 提供加载状态回调
/// - 防止重复加载
/// - 支持 pageSize 配置
class PaginationController<T> extends ChangeNotifier {
  /// 当前页码（从 1 开始）
  int currentPage;

  /// 每页数据量
  final int pageSize;

  /// 总页数
  int totalPages;

  /// 数据项列表
  List<T> items;

  /// 是否正在加载
  bool isLoading;

  /// 是否正在加载更多
  bool isLoadingMore;

  /// 是否还有更多数据
  bool hasMore;

  /// 总数据量（可选）
  int? totalItems;

  /// 错误消息
  String? errorMessage;

  /// 获取页面数据的函数
  final Future<List<T>> Function(int page, int pageSize) fetchPage;

  /// 加载完成回调
  void Function()? onLoadCompleted;

  /// 加载失败回调
  void Function(String error)? onLoadFailed;

  /// 创建分页控制器
  ///
  /// [fetchPage] 获取页面数据的函数，接收页码和每页大小，返回数据列表
  /// [pageSize] 每页数据量（默认 20）
  /// [initialPage] 初始页码（默认 1）
  PaginationController({
    required this.fetchPage,
    this.pageSize = 20,
    this.initialPage = 1,
    List<T>? initialItems,
    this.onLoadCompleted,
    this.onLoadFailed,
  })  : currentPage = initialPage,
        totalPages = 1,
        items = initialItems ?? [],
        isLoading = false,
        isLoadingMore = false,
        hasMore = true;

  /// 初始页码
  final int initialPage;

  /// 是否为空（无数据且未加载）
  bool get isEmpty => items.isEmpty && !isLoading && errorMessage == null;

  /// 是否有错误
  bool get hasError => errorMessage != null;

  /// 是否可以加载更多
  bool get canLoadMore => hasMore && !isLoading && !isLoadingMore;

  /// 数据项数量
  int get itemCount => items.length;

  /// 刷新数据（重置到第一页）
  ///
  /// [clearExisting] 是否清空现有数据（默认 true）
  Future<void> refresh({bool clearExisting = true}) async {
    if (isLoading) {
      debugPrint('⚠️ [PaginationController] 已有加载操作在进行中');
      return;
    }

    if (clearExisting) {
      items.clear();
      currentPage = initialPage;
    }
    hasMore = true;
    errorMessage = null;

    await _loadPage(isLoadMore: false);
  }

  /// 加载下一页
  Future<void> loadNextPage() async {
    if (!canLoadMore) {
      debugPrint('⚠️ [PaginationController] 无法加载更多: '
          'hasMore=$hasMore, isLoading=$isLoading, isLoadingMore=$isLoadingMore');
      return;
    }

    await _loadPage(isLoadMore: true);
  }

  /// 加载指定页
  ///
  /// [page] 页码
  /// [replace] 是否替换当前数据（默认 false，追加数据）
  Future<void> loadPage(int page, {bool replace = false}) async {
    if (isLoading) {
      debugPrint('⚠️ [PaginationController] 已有加载操作在进行中');
      return;
    }

    if (replace) {
      items.clear();
    }

    currentPage = page;
    await _loadPage(isLoadMore: false);
  }

  /// 加载页面数据的内部实现
  Future<void> _loadPage({required bool isLoadMore}) async {
    if (isLoadMore) {
      isLoadingMore = true;
    } else {
      isLoading = true;
    }
    errorMessage = null;
    notifyListeners();

    try {
      debugPrint(
        '📄 [PaginationController] 加载第 $currentPage 页 '
        '(每页 $pageSize 条)',
      );

      final newItems = await fetchPage(currentPage, pageSize);

      if (!isLoadMore) {
        items.clear();
      }
      items.addAll(newItems);

      // 判断是否还有更多数据
      hasMore = newItems.length >= pageSize;
      if (hasMore) {
        currentPage++;
      } else {
        totalPages = currentPage;
      }

      debugPrint(
        '✅ [PaginationController] 加载完成: '
        '新增 ${newItems.length} 条，总共 ${items.length} 条，'
        'hasMore=$hasMore',
      );

      onLoadCompleted?.call();
    } catch (e, stackTrace) {
      errorMessage = e.toString();
      debugPrint('❌ [PaginationController] 加载失败: $e\n$stackTrace');
      onLoadFailed?.call(errorMessage!);
    } finally {
      isLoading = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 重试加载（清除错误状态后重新加载）
  Future<void> retry() async {
    errorMessage = null;
    notifyListeners();
    await refresh();
  }

  /// 追加数据项
  ///
  /// 直接追加数据到列表，不触发网络请求。
  void appendItems(List<T> newItems) {
    items.addAll(newItems);
    notifyListeners();
  }

  /// 插入数据项
  ///
  /// [index] 插入位置
  /// [item] 要插入的数据项
  void insertItem(int index, T item) {
    items.insert(index, item);
    notifyListeners();
  }

  /// 移除数据项
  ///
  /// [index] 要移除的数据项索引
  void removeItem(int index) {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      notifyListeners();
    }
  }

  /// 更新数据项
  ///
  /// [index] 要更新的数据项索引
  /// [item] 新的数据项
  void updateItem(int index, T item) {
    if (index >= 0 && index < items.length) {
      items[index] = item;
      notifyListeners();
    }
  }

  /// 清空所有数据
  void clear() {
    items.clear();
    currentPage = initialPage;
    hasMore = true;
    errorMessage = null;
    notifyListeners();
  }

  /// 设置总数据量
  ///
  /// 设置后可根据总数据量计算总页数。
  void setTotalItems(int total) {
    totalItems = total;
    totalPages = (total / pageSize).ceil();
  }

  @override
  void dispose() {
    debugPrint('🧹 [PaginationController] 释放资源');
    super.dispose();
  }
}

/// 带缓存的分页控制器
///
/// 在 PaginationController 基础上添加数据缓存功能，
/// 避免重复加载已加载过的页面。
class CachedPaginationController<T> extends ChangeNotifier {
  /// 每页数据量
  final int pageSize;

  /// 获取页面数据的函数
  final Future<List<T>> Function(int page, int pageSize) fetchPage;

  /// 页面缓存
  final Map<int, List<T>> _pageCache = {};

  /// 当前已加载的页面
  final Set<int> _loadedPages = {};

  /// 当前页码
  int currentPage;

  /// 数据项列表
  List<T> get items {
    final allItems = <T>[];
    for (final page in _loadedPages.toList()..sort()) {
      allItems.addAll(_pageCache[page] ?? []);
    }
    return allItems;
  }

  /// 是否正在加载
  bool isLoading = false;

  /// 是否还有更多数据
  bool hasMore = true;

  /// 总页数
  int? totalPages;

  /// 错误消息
  String? errorMessage;

  /// 创建带缓存的分页控制器
  ///
  /// [fetchPage] 获取页面数据的函数
  /// [pageSize] 每页数据量（默认 20）
  /// [initialPage] 初始页码（默认 1）
  CachedPaginationController({
    required this.fetchPage,
    this.pageSize = 20,
    this.initialPage = 1,
  }) : currentPage = initialPage;

  /// 初始页码
  final int initialPage;

  /// 加载指定页（使用缓存）
  Future<void> loadPage(int page) async {
    if (_loadedPages.contains(page)) {
      debugPrint('📋 [CachedPaginationController] 第 $page 页已缓存');
      currentPage = page;
      notifyListeners();
      return;
    }

    if (isLoading) {
      debugPrint('⚠️ [CachedPaginationController] 已有加载操作在进行中');
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      debugPrint('📄 [CachedPaginationController] 加载第 $page 页');
      final items = await fetchPage(page, pageSize);

      _pageCache[page] = items;
      _loadedPages.add(page);
      currentPage = page;

      // 判断是否还有更多数据
      hasMore = items.length >= pageSize;
      if (!hasMore && totalPages == null) {
        totalPages = page;
      }

      debugPrint(
        '✅ [CachedPaginationController] 加载完成: '
        '新增 ${items.length} 条，已加载 ${_loadedPages.length} 页',
      );
    } catch (e, stackTrace) {
      errorMessage = e.toString();
      debugPrint('❌ [CachedPaginationController] 加载失败: $e\n$stackTrace');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 加载下一页
  Future<void> loadNextPage() async {
    if (!hasMore || isLoading) {
      return;
    }
    await loadPage(currentPage + 1);
  }

  /// 刷新（清除缓存）
  Future<void> refresh() async {
    _pageCache.clear();
    _loadedPages.clear();
    currentPage = initialPage;
    hasMore = true;
    errorMessage = null;
    await loadPage(initialPage);
  }

  /// 预加载下一页
  Future<void> preloadNextPage() async {
    final nextPage = currentPage + 1;
    if (!_loadedPages.contains(nextPage) && hasMore && !isLoading) {
      debugPrint('⏩ [CachedPaginationController] 预加载第 $nextPage 页');
      await loadPage(nextPage);
    }
  }

  /// 清空缓存
  void clearCache() {
    _pageCache.clear();
    _loadedPages.clear();
    currentPage = initialPage;
    hasMore = true;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🧹 [CachedPaginationController] 释放资源');
    _pageCache.clear();
    _loadedPages.clear();
    super.dispose();
  }
}

/// 分页加载状态
enum PaginationStatus {
  /// 空闲状态
  idle,

  /// 正在加载
  loading,

  /// 加载成功
  success,

  /// 加载失败
  error,

  /// 没有更多数据
  noMore,
}

/// 分页数据包装器
///
/// 用于包装分页数据的响应。
class PaginationResult<T> {
  /// 数据列表
  final List<T> items;

  /// 当前页码
  final int currentPage;

  /// 每页大小
  final int pageSize;

  /// 总数据量
  final int? total;

  /// 总页数
  final int? totalPages;

  /// 是否有下一页
  final bool hasNext;

  /// 是否有上一页
  final bool hasPrevious;

  const PaginationResult({
    required this.items,
    required this.currentPage,
    required this.pageSize,
    this.total,
    this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  /// 从 API 响应创建分页结果
  ///
  /// [items] 数据列表
  /// [currentPage] 当前页码
  /// [pageSize] 每页大小
  /// [total] 总数据量
  factory PaginationResult.fromResponse({
    required List<T> items,
    required int currentPage,
    required int pageSize,
    int? total,
  }) {
    final totalPages = total != null ? (total / pageSize).ceil() : null;
    final calculatedTotalPages = totalPages;
    final hasNext = calculatedTotalPages == null
        ? items.length >= pageSize
        : currentPage < calculatedTotalPages;
    final hasPrevious = currentPage > 1;

    return PaginationResult(
      items: items,
      currentPage: currentPage,
      pageSize: pageSize,
      total: total,
      totalPages: totalPages,
      hasNext: hasNext,
      hasPrevious: hasPrevious,
    );
  }

  /// 空结果
  static const empty = PaginationResult(
    items: [],
    currentPage: 1,
    pageSize: 20,
    hasNext: false,
    hasPrevious: false,
  );
}
