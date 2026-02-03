// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dioHash() => r'e29c612f910d2ebaae7bae655d0da68d54468bf2';

/// Dio Provider
///
/// 提供全局统一的 HTTP 客户端实例。
///
/// **功能**:
/// - 统一配置超时时间、连接池
/// - 添加日志拦截器
/// - 优化HTTP连接管理
///
/// **配置**:
/// - 连接超时: 10秒
/// - 接收超时: 90秒
/// - 发送超时: 30秒
/// - 最大并发连接: 20/主机
/// - 空闲超时: 60秒
///
/// **使用示例**:
/// ```dart
/// final dio = ref.watch(dioProvider);
/// final response = await dio.get('/api/endpoint');
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 自动添加日志拦截器（调试模式）
/// - 已优化的连接池配置，避免资源耗尽
///
/// Copied from [dio].
@ProviderFor(dio)
final dioProvider = Provider<Dio>.internal(
  dio,
  name: r'dioProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DioRef = ProviderRef<Dio>;
String _$apiServiceWrapperHash() => r'ad6a9ac48976ae344df490909fe83b8b99b7e523';

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
/// - [dioProvider] - HTTP 客户端
///
/// **使用示例**:
/// ```dart
/// // 方式1: 直接使用（已自动初始化）
/// final apiService = ref.watch(apiServiceWrapperProvider);
/// final novels = await apiService.searchNovels('keyword');
///
/// // 方式2: 仅获取 Future（异步场景）
/// final initFuture = ref.watch(apiServiceWrapperInitProvider);
/// await initFuture;
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁
/// - Provider 会自动调用 `init()`，无需手动初始化
/// - 通过依赖注入创建实例，便于测试
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
String _$apiServiceWrapperInitHash() =>
    r'050646a40f43e0fadbcc7ef4dc0a888c82a7ddd7';

/// ApiServiceWrapper 初始化 Provider
///
/// 提供 ApiServiceWrapper 的初始化 Future，用于需要等待初始化的场景。
///
/// **使用示例**:
/// ```dart
/// // 在应用启动时等待初始化
/// final initFuture = ref.watch(apiServiceWrapperInitProvider);
/// await initFuture;
/// ```
///
/// Copied from [apiServiceWrapperInit].
@ProviderFor(apiServiceWrapperInit)
final apiServiceWrapperInitProvider = FutureProvider<void>.internal(
  apiServiceWrapperInit,
  name: r'apiServiceWrapperInitProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$apiServiceWrapperInitHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApiServiceWrapperInitRef = FutureProviderRef<void>;
String _$preloadServiceHash() => r'de5034b7741f37734cfb299923b88010b685931b';

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
/// - [apiServiceWrapperProvider] - API 服务
/// - [chapterRepositoryProvider] - 章节数据访问
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
/// await preloadService.enqueueTasks(
///   novelUrl: novelUrl,
///   novelTitle: novelTitle,
///   chapterUrls: chapterUrls,
///   currentIndex: currentIndex,
/// );
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 预加载在后台异步执行
/// - 支持通过 progressStream 监听进度
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
String _$sceneIllustrationServiceHash() =>
    r'7f60bc634b8c313ac540eaa0d11a7c96193bd800';

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
/// - [chapterRepositoryProvider] - 章节数据访问
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
String _$sceneIllustrationCacheServiceHash() =>
    r'0a4a41925c35fee4fbc518e2e0c465de5bc35b3c';

/// SceneIllustrationCacheService Provider
///
/// 提供场景插图缓存服务实例，管理场景插图的本地缓存。
///
/// **功能**:
/// - 图片内存缓存和磁盘缓存
/// - 预加载和批量缓存
/// - 缓存有效期管理
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API服务
///
/// **使用示例**:
/// ```dart
/// final cacheService = ref.read(sceneIllustrationCacheServiceProvider);
/// await cacheService.init();
/// final imageBytes = await cacheService.getImageBytes(filename);
/// ```
///
/// Copied from [sceneIllustrationCacheService].
@ProviderFor(sceneIllustrationCacheService)
final sceneIllustrationCacheServiceProvider =
    Provider<SceneIllustrationCacheService>.internal(
  sceneIllustrationCacheService,
  name: r'sceneIllustrationCacheServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sceneIllustrationCacheServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SceneIllustrationCacheServiceRef
    = ProviderRef<SceneIllustrationCacheService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
