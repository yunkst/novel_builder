// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$roleGalleryCacheServiceHash() =>
    r'dab640aaf5be9727aad82d6865ef766e658d1af3';

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
/// - [apiServiceWrapperProvider] - API服务
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
String _$characterImageCacheServiceHash() =>
    r'4cfb788b12ede78f54233531ba19f52bfa4b9401';

/// CharacterImageCacheService Provider
///
/// 提供角色图片缓存服务实例，用于管理角色图片的本地缓存。
///
/// **功能**:
/// - 角色图片本地缓存
/// - 缓存文件管理
/// - 图片存储和检索
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final cacheService = ref.watch(characterImageCacheServiceProvider);
/// await cacheService.init();
/// final path = await cacheService.cacheCharacterImage(id, bytes, filename);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要先调用 `init()` 方法初始化
///
/// Copied from [characterImageCacheService].
@ProviderFor(characterImageCacheService)
final characterImageCacheServiceProvider =
    Provider<CharacterImageCacheService>.internal(
  characterImageCacheService,
  name: r'characterImageCacheServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterImageCacheServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterImageCacheServiceRef = ProviderRef<CharacterImageCacheService>;
String _$characterAvatarSyncServiceHash() =>
    r'a659395cbf28d7d2ab51fef565c9a8677dfc2783';

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
/// - [roleGalleryCacheServiceProvider] - 图集缓存服务
/// - [characterImageCacheServiceProvider] - 头像缓存服务
/// - [databaseServiceProvider] - 数据库服务
/// - [apiServiceWrapperProvider] - API服务
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
    r'f4dc89f92abbda37cfc9c40e7a83205ceefe88fe';

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
/// - [databaseServiceProvider] - 数据库服务
/// - [characterImageCacheServiceProvider] - 图片缓存服务
///
/// **使用示例**:
/// ```dart
/// final avatarService = ref.watch(characterAvatarServiceProvider);
/// final avatarUrl = await avatarService.setAvatarFromGallery(
///   characterId,
///   imageBytes,
///   filename,
/// );
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 头像操作是异步操作
///
/// Copied from [characterAvatarService].
@ProviderFor(characterAvatarService)
final characterAvatarServiceProvider =
    AutoDisposeProvider<CharacterAvatarService>.internal(
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
typedef CharacterAvatarServiceRef
    = AutoDisposeProviderRef<CharacterAvatarService>;
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
