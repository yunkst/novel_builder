// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$roleGalleryCacheServiceHash() =>
    r'742305844742d717065b94ad17846198aa0bebe1';

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
    r'4d4a25b156b974d6ed60a39311efe0de037899c7';

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
    r'1bb251b88d1194306808ff60ac1bd2f6a704cf8c';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
