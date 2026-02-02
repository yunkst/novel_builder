/// Cache Service Providers
///
/// 此文件定义所有缓存相关服务的 Provider。
///
/// **功能**:
/// - 角色图集缓存服务
/// - 角色头像同步服务
/// - 角色头像生成服务
///
/// **依赖**:
/// - 无（独立服务）
///
/// **相关 Providers**:
/// - [ai_service_providers.dart] - AI相关 Providers
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../services/role_gallery_cache_service.dart';
import '../../../services/character_avatar_sync_service.dart';
import '../../../services/character_avatar_service.dart';

part 'cache_service_providers.g.dart';

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
@Riverpod(keepAlive: true)
RoleGalleryCacheService roleGalleryCacheService(Ref ref) {
  return RoleGalleryCacheService();
}

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
@Riverpod(keepAlive: true)
CharacterAvatarSyncService characterAvatarSyncService(Ref ref) {
  return CharacterAvatarSyncService();
}

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
@Riverpod(keepAlive: true)
CharacterAvatarService characterAvatarService(Ref ref) {
  return CharacterAvatarService();
}
