// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loggerServiceHash() => r'517b7a109d52d09f96accf83448ccbb019465e6f';

/// LoggerService Provider
///
/// 提供全局日志服务实例，用于记录应用运行时的日志信息。
///
/// **功能**:
/// - 支持多级别日志（debug, info, warning, error）
/// - 支持日志分类和标签
/// - 持久化日志到本地文件
///
/// **依赖**:
/// - 无（单例服务）
///
/// **使用示例**:
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final logger = ref.watch(loggerServiceProvider);
///     logger.info('Widget 已构建');
///     return Container();
///   }
/// }
/// ```
///
/// **注意事项**:
/// - 使用 `LoggerService.instance` 单例模式
/// - 日志文件位于应用文档目录
/// - 支持异步日志写入
///
/// **相关 Providers**:
/// - [preferencesServiceProvider] - 用于读取日志配置
///
/// Copied from [loggerService].
@ProviderFor(loggerService)
final loggerServiceProvider = AutoDisposeProvider<LoggerService>.internal(
  loggerService,
  name: r'loggerServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loggerServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LoggerServiceRef = AutoDisposeProviderRef<LoggerService>;
String _$preferencesServiceHash() =>
    r'1ea3b212d9f5520c6d39cca0036eafba0aa904e3';

/// PreferencesService Provider
///
/// 提供全局 SharedPreferences 服务实例，用于存储用户偏好设置。
///
/// **功能**:
/// - 持久化键值对存储
/// - 支持多种数据类型（String、int、bool、double、List<String>等）
/// - 线程安全访问
///
/// **依赖**:
/// - 无（单例服务）
///
/// **使用示例**:
/// ```dart
/// final prefs = ref.watch(preferencesServiceProvider);
/// await prefs.setString('theme_mode', 'dark');
/// final themeMode = await prefs.getString('theme_mode');
/// ```
///
/// **注意事项**:
/// - 使用 `PreferencesService.instance` 单例模式
/// - 所有操作都是异步的
/// - 数据存储在本地 SharedPreferences
///
/// **相关 Providers**:
/// - [themeProvider] - 用于主题设置持久化
/// - [databaseServiceProvider] - 用于数据库配置
///
/// Copied from [preferencesService].
@ProviderFor(preferencesService)
final preferencesServiceProvider =
    AutoDisposeProvider<PreferencesService>.internal(
  preferencesService,
  name: r'preferencesServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preferencesServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PreferencesServiceRef = AutoDisposeProviderRef<PreferencesService>;
String _$apiServiceWrapperHash() => r'96f5a0afe67bdf926f2f8ca1f3b3da300fedbacc';

/// ApiServiceWrapper Provider
///
/// 提供全局 API 服务实例，负责与后端服务器通信。
///
/// **功能**:
/// - 封装后端 API 调用
/// - 自动初始化和配置
/// - 错误处理和重试机制
/// - 支持 OpenAPI 生成的类型安全接口
///
/// **依赖**:
/// - [preferencesServiceProvider] - 用于读取 API 配置
///
/// **使用示例**:
/// ```dart
/// final apiService = ref.watch(apiServiceWrapperProvider);
/// await apiService.init();
/// final novels = await apiService.searchNovels(' keyword');
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要先调用 `init()` 方法初始化
/// - 内部已经是单例模式，Provider 提供统一访问方式
///
/// **相关 Providers**:
/// - [preferencesServiceProvider] - API 配置存储
/// - [chapterLoaderProvider] - 依赖此 Provider
///
/// Copied from [apiServiceWrapper].
@ProviderFor(apiServiceWrapper)
final apiServiceWrapperProvider = Provider<ApiServiceWrapper>.internal(
  apiServiceWrapper,
  name: r'apiServiceWrapperProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$apiServiceWrapperHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApiServiceWrapperRef = ProviderRef<ApiServiceWrapper>;
String _$difyServiceHash() => r'f9ff2c280e9ad41f4d32f51a6a24a398cb87e35e';

/// DifyService Provider
///
/// 提供全局 Dify AI 服务实例，用于 AI 内容生成和流式响应。
///
/// **功能**:
/// - 流式 AI 响应处理
/// - 特写功能内容生成
/// - SSE 解析器支持
/// - 多轮对话管理
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final difyService = ref.watch(difyServiceProvider);
/// final stream = difyService.streamGenerate('提示词');
/// await for (final chunk in stream) {
///   print('收到: ${chunk.content}');
/// }
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要配置 Dify URL 和 Token
/// - 支持流式和阻塞两种响应模式
///
/// **相关 Providers**:
/// - [preferencesServiceProvider] - Dify 配置存储
///
/// Copied from [difyService].
@ProviderFor(difyService)
final difyServiceProvider = Provider<DifyService>.internal(
  difyService,
  name: r'difyServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$difyServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DifyServiceRef = ProviderRef<DifyService>;
String _$preloadServiceHash() => r'c485fc3312c238914200a858228c97b90c447e95';

/// PreloadService Provider
///
/// 提供全局预加载服务实例，用于章节内容的预加载和缓存管理。
///
/// **功能**:
/// - 后台预加载章节内容
/// - 进度流式更新
/// - 并发控制
/// - 任务队列管理
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final preloadService = ref.watch(preloadServiceProvider);
///
/// // 监听预加载进度
/// ref.listen(preloadProgressProvider, (previous, next) {
///   print('预加载进度: ${next.cachedChapters}/${next.totalChapters}');
/// });
///
/// // 开始预加载
/// await preloadService.preloadNovel(novelUrl);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 预加载在后台异步执行
/// - 支持通过 progressStream 监听进度
///
/// **相关 Providers**:
/// - [chapterLoaderProvider] - 章节加载
/// - [databaseServiceProvider] - 缓存存储
///
/// Copied from [preloadService].
@ProviderFor(preloadService)
final preloadServiceProvider = Provider<PreloadService>.internal(
  preloadService,
  name: r'preloadServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preloadServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PreloadServiceRef = ProviderRef<PreloadService>;
String _$chapterServiceHash() => r'2dccd7ad2c06b7df2edb0e30488d1a21c80770dc';

/// ChapterService Provider
///
/// 提供章节服务实例，处理章节数据的业务逻辑。
///
/// **功能**:
/// - 章节 CRUD 操作
/// - 章节索引管理
/// - 用户插入章节保护
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final chapterService = ref.watch(chapterServiceProvider);
/// await chapterService.insertChapter(novelUrl, chapter);
/// final chapters = await chapterService.getChapters(novelUrl);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 依赖 DatabaseService，自动注入
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterLoaderProvider] - 章节加载器
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
String _$chapterLoaderHash() => r'7fc7fceca7af8d51d090a8fd910013fa0dcc34b1';

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
/// **相关 Providers**:
/// - [apiServiceWrapperProvider] - API 服务
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterActionHandlerProvider] - 章节操作
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
    r'2702dcd27892ae4210564123800444faeb2c08c3';

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
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterReorderControllerProvider] - 章节重排
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
    r'4f3930c9faa9311e129c5a39a50e34e4188e97ba';

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
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterActionHandlerProvider] - 章节操作
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
String _$sceneIllustrationServiceHash() =>
    r'fc122804f336f372345cf3a409a2d5a726094cea';

/// SceneIllustrationService Provider
///
/// 提供场景插图服务实例，负责场景图片的生成和管理。
///
/// **功能**:
/// - 场景插图生成
/// - 插图缓存管理
/// - 图片 URL 处理
///
/// **依赖**:
/// - [illustrationRepositoryProvider] - 插图数据访问
/// - [apiServiceWrapperProvider] - API 服务
///
/// **使用示例**:
/// ```dart
/// final illustrationService = ref.watch(sceneIllustrationServiceProvider);
/// final imageUrl = await illustrationService.generateIllustration(scene);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 插图生成是异步操作
///
/// **相关 Providers**:
/// - [illustrationRepositoryProvider] - 插图数据访问
/// - [apiServiceWrapperProvider] - API 服务
///
/// Copied from [sceneIllustrationService].
@ProviderFor(sceneIllustrationService)
final sceneIllustrationServiceProvider =
    AutoDisposeProvider<SceneIllustrationService>.internal(
  sceneIllustrationService,
  name: r'sceneIllustrationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sceneIllustrationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SceneIllustrationServiceRef
    = AutoDisposeProviderRef<SceneIllustrationService>;
String _$roleGalleryCacheServiceHash() =>
    r'7778b0acb6f16683c1f0697771377e26228346c4';

/// RoleGalleryCacheService Provider
///
/// 提供角色图集缓存服务实例，管理角色图片的缓存。
///
/// **功能**:
/// - 角色图片缓存
/// - 缓存清理
/// - 缓存大小管理
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final cacheService = ref.watch(roleGalleryCacheServiceProvider);
/// await cacheService.cacheRoleImage(roleId, imageUrl);
/// final cachedPath = cacheService.getCachedImagePath(roleId);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 缓存文件存储在应用缓存目录
///
/// **相关 Providers**:
/// - [characterAvatarServiceProvider] - 头像服务
///
/// Copied from [roleGalleryCacheService].
@ProviderFor(roleGalleryCacheService)
final roleGalleryCacheServiceProvider =
    Provider<RoleGalleryCacheService>.internal(
  roleGalleryCacheService,
  name: r'roleGalleryCacheServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$roleGalleryCacheServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RoleGalleryCacheServiceRef = ProviderRef<RoleGalleryCacheService>;
String _$characterAvatarSyncServiceHash() =>
    r'7046069ca54851aae272228873f5d84ff45bcf3c';

/// CharacterAvatarSyncService Provider
///
/// 提供角色头像同步服务实例，同步头像数据到多个来源。
///
/// **功能**:
/// - 头像数据同步
/// - 批量同步
/// - 同步状态跟踪
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final syncService = ref.watch(characterAvatarSyncServiceProvider);
/// await syncService.syncAvatar(characterId);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 同步操作是异步的
///
/// **相关 Providers**:
/// - [characterAvatarServiceProvider] - 头像服务
/// - [characterImageCacheServiceProvider] - 图片缓存
///
/// Copied from [characterAvatarSyncService].
@ProviderFor(characterAvatarSyncService)
final characterAvatarSyncServiceProvider =
    Provider<CharacterAvatarSyncService>.internal(
  characterAvatarSyncService,
  name: r'characterAvatarSyncServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterAvatarSyncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterAvatarSyncServiceRef = ProviderRef<CharacterAvatarSyncService>;
String _$characterAvatarServiceHash() =>
    r'a0d4f978b106223eb7e977373746ec9d4385b26e';

/// CharacterAvatarService Provider
///
/// 提供角色头像服务实例，处理角色头像的生成和管理。
///
/// **功能**:
/// - 头像生成
/// - 头像缓存
/// - 头像 URL 管理
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final avatarService = ref.watch(characterAvatarServiceProvider);
/// final avatarUrl = await avatarService.generateAvatar(character);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 头像生成是异步操作
///
/// **相关 Providers**:
/// - [characterAvatarSyncServiceProvider] - 同步服务
/// - [characterImageCacheServiceProvider] - 图片缓存
///
/// Copied from [characterAvatarService].
@ProviderFor(characterAvatarService)
final characterAvatarServiceProvider =
    Provider<CharacterAvatarService>.internal(
  characterAvatarService,
  name: r'characterAvatarServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterAvatarServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterAvatarServiceRef = ProviderRef<CharacterAvatarService>;
String _$chapterSearchServiceHash() =>
    r'bb7c2c0d0d4b73939d4e182f47f1375664ad18bb';

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
/// - [chapterRepositoryProvider] - 章节数据访问
/// - [cacheSearchServiceProvider] - 缓存搜索
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
/// **相关 Providers**:
/// - [chapterRepositoryProvider] - 章节数据访问
/// - [cacheSearchServiceProvider] - 缓存搜索
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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
