// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$apiServiceWrapperHash() => r'45715e468a5bb8cfd049e29ed2a4df08182a3bd7';

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
/// final novels = await apiService.searchNovels('keyword');
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要先调用 `init()` 方法初始化
/// - 内部已经是单例模式，Provider 提供统一访问方式
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
String _$preloadServiceHash() => r'9c9c37295abda572fd7eea1070f935534f8bc8bd';

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
    r'63ce725f7bb7dc4d1c10022b3dc6136bb60d3039';

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
/// - [databaseServiceProvider] - 数据库访问
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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
