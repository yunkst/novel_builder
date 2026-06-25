// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$imageCacheManagerHash() => r'6faed2eedcb79ccd3e28c309a282a02fd84fe1b4';

/// ImageCacheManager Provider
///
/// 提供全局图片缓存管理器实例，用于管理插图图片的缓存和生命周期。
///
/// **功能**:
/// - 图片内存缓存和磁盘缓存
/// - 预加载和批量缓存
/// - 缓存有效期管理
/// - LRU 缓存策略
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API服务
///
/// **使用示例**:
/// ```dart
/// final imageCacheManager = ref.read(imageCacheManagerProvider);
/// final imageBytes = await imageCacheManager.getImage(filename);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁
/// - 缓存存储是静态的，所有实例共享同一缓存
/// - 通过依赖注入 ApiServiceWrapper，便于测试
///
/// Copied from [imageCacheManager].
@ProviderFor(imageCacheManager)
final imageCacheManagerProvider = Provider<ImageCacheManager>.internal(
  imageCacheManager,
  name: r'imageCacheManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$imageCacheManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ImageCacheManagerRef = ProviderRef<ImageCacheManager>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
