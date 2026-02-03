// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chapterServiceHash() => r'746bbf694057fed1932ea1b8cfef5ad846412f45';

/// ChapterService Provider
///
/// 提供章节服务实例，处理章节数据的业务逻辑。
///
/// **功能**:
/// - 章节 CRUD 操作
/// - 章节索引管理
/// - 用户插入章节保护
/// - 历史章节查询和处理
/// - 角色信息格式化
/// - AI请求参数构建
///
/// **依赖**:
/// - [chapterRepositoryProvider] - 章节数据访问
/// - [characterRepositoryProvider] - 角色数据访问
///
/// **使用示例**:
/// ```dart
/// final chapterService = ref.watch(chapterServiceProvider);
/// final inputs = await chapterService.buildChapterGenerationInputs(
///   novel: novel,
///   chapters: chapters,
///   afterIndex: 0,
///   userInput: '要求',
///   characterIds: [1, 2],
/// );
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 依赖 Repository 接口，支持测试和依赖替换
///
/// Copied from [chapterService].
@ProviderFor(chapterService)
final chapterServiceProvider = AutoDisposeProvider<ChapterService>.internal(
  chapterService,
  name: r'chapterServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChapterServiceRef = AutoDisposeProviderRef<ChapterService>;
String _$chapterLoaderHash() => r'd7be75d342d5afb3b8fa8ed3e10909b08bc454b3';

/// ChapterLoader Provider
///
/// 提供章节加载器实例，负责从 API 和数据库加载章节数据。
///
/// **功能**:
/// - 从 API 获取章节列表
/// - 从数据库加载缓存章节
/// - 刷新章节列表
/// - 最后阅读位置管理
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API 服务
/// - [databaseServiceProvider] - 数据库服务
///
/// **使用示例**:
/// ```dart
/// final chapterLoader = ref.watch(chapterLoaderProvider);
/// await chapterLoader.initApi();
/// final chapters = await chapterLoader.loadChapters(novelUrl);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 需要先调用 `initApi()` 初始化
/// - 自动处理缓存和刷新逻辑
///
/// Copied from [chapterLoader].
@ProviderFor(chapterLoader)
final chapterLoaderProvider = AutoDisposeProvider<ChapterLoader>.internal(
  chapterLoader,
  name: r'chapterLoaderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterLoaderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChapterLoaderRef = AutoDisposeProviderRef<ChapterLoader>;
String _$chapterActionHandlerHash() =>
    r'296d1ca9c49d809fe9e6480efa31815030b3cca1';

/// ChapterActionHandler Provider
///
/// 提供章节操作处理器实例，处理章节的增删改查操作。
///
/// **功能**:
/// - 章节缓存状态查询
/// - 章节删除
/// - 章节重排
/// - 批量操作
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库服务
///
/// **使用示例**:
/// ```dart
/// final handler = ref.watch(chapterActionHandlerProvider);
/// final isCached = await handler.isChapterCached(chapterUrl);
/// await handler.deleteChapter(chapterUrl);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 支持批量操作以提高性能
///
/// Copied from [chapterActionHandler].
@ProviderFor(chapterActionHandler)
final chapterActionHandlerProvider =
    AutoDisposeProvider<ChapterActionHandler>.internal(
  chapterActionHandler,
  name: r'chapterActionHandlerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterActionHandlerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChapterActionHandlerRef = AutoDisposeProviderRef<ChapterActionHandler>;
String _$chapterReorderControllerHash() =>
    r'00ce9575e7624424922d6336c92bc99e1ff9d073';

/// ChapterReorderController Provider
///
/// 提供章节重排控制器实例，管理章节顺序调整。
///
/// **功能**:
/// - 章节拖拽重排
/// - 保存重排结果
/// - 验证重排合法性
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库服务
///
/// **使用示例**:
/// ```dart
/// final reorderController = ref.watch(chapterReorderControllerProvider);
/// final reordered = reorderController.onReorder(
///   oldIndex: 0,
///   newIndex: 2,
///   chapters: chapters,
/// );
/// await reorderController.saveReorderedChapters(novelUrl, reordered);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 保存操作会持久化到数据库
///
/// Copied from [chapterReorderController].
@ProviderFor(chapterReorderController)
final chapterReorderControllerProvider =
    AutoDisposeProvider<ChapterReorderController>.internal(
  chapterReorderController,
  name: r'chapterReorderControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterReorderControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChapterReorderControllerRef
    = AutoDisposeProviderRef<ChapterReorderController>;
String _$chapterSearchServiceHash() =>
    r'7efda65815b3e0c5651b5cbc078ab36d1e283a6f';

/// ChapterSearchService Provider
///
/// 提供章节搜索服务实例，支持章节内容的全文搜索。
///
/// **功能**:
/// - 章节内容搜索
/// - 搜索结果高亮
/// - 模糊搜索
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final searchService = ref.watch(chapterSearchServiceProvider);
/// final results = await searchService.searchInNovel(novelUrl, '关键词');
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 搜索操作是异步的
///
/// Copied from [chapterSearchService].
@ProviderFor(chapterSearchService)
final chapterSearchServiceProvider =
    AutoDisposeProvider<ChapterSearchService>.internal(
  chapterSearchService,
  name: r'chapterSearchServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterSearchServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChapterSearchServiceRef = AutoDisposeProviderRef<ChapterSearchService>;
String _$cacheSearchServiceHash() =>
    r'6e884daccda71277939e9619434ad3149a2dc21d';

/// CacheSearchService Provider
///
/// 提供缓存搜索服务实例，支持缓存内容的搜索和分页。
///
/// **功能**:
/// - 缓存内容搜索
/// - 搜索结果分页
/// - 搜索建议
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final cacheSearch = ref.watch(cacheSearchServiceProvider);
/// final results = await cacheSearch.searchInCache(keyword: '关键词');
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 搜索操作是异步的
///
/// Copied from [cacheSearchService].
@ProviderFor(cacheSearchService)
final cacheSearchServiceProvider =
    AutoDisposeProvider<CacheSearchService>.internal(
  cacheSearchService,
  name: r'cacheSearchServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cacheSearchServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CacheSearchServiceRef = AutoDisposeProviderRef<CacheSearchService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
