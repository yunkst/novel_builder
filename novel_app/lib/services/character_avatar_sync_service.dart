import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/role_gallery.dart';
import '../services/role_gallery_cache_service.dart';
import '../services/character_image_cache_service.dart';
import '../services/database_service.dart';
import '../core/di/api_service_provider.dart';

/// 角色头像同步服务
/// 负责将图集图片同步为角色头像
class CharacterAvatarSyncService {
  static final CharacterAvatarSyncService _instance = CharacterAvatarSyncService._internal();
  factory CharacterAvatarSyncService() => _instance;
  CharacterAvatarSyncService._internal();

  final RoleGalleryCacheService _galleryCacheService = RoleGalleryCacheService();
  final CharacterImageCacheService _avatarCacheService = CharacterImageCacheService.instance;
  final DatabaseService _databaseService = DatabaseService();

  /// 初始化服务
  Future<void> init() async {
    await _galleryCacheService.init();
    await _avatarCacheService.init();
  }

  /// 同步指定图片为角色头像
  ///
  /// [characterId] 角色ID
  /// [image] 要同步的图片对象
  /// [filename] 图片文件名（可选，如果不提供则使用image.filename）
  ///
  /// 返回同步的缓存路径，失败时返回null
  Future<String?> syncImageToCharacterAvatar(
    int characterId,
    RoleImage image, {
    String? filename,
  }) async {
    try {
      final targetFilename = filename ?? image.filename;
      debugPrint('🔄 开始同步图片到角色头像: $targetFilename (角色ID: $characterId)');

      // 获取图片字节数据
      final imageBytes = await _galleryCacheService.getImageBytes(targetFilename);
      if (imageBytes == null) {
        debugPrint('❌ 无法获取图片字节数据: $targetFilename');
        return null;
      }

      debugPrint('📸 成功获取图片字节数据: ${imageBytes.length} bytes');

      // 使用 CharacterImageCacheService 缓存图片作为头像
      final cachedImagePath = await _avatarCacheService.cacheCharacterImage(
        characterId,
        imageBytes,
        'avatar_$targetFilename', // 使用特殊前缀标识是头像
      );

      if (cachedImagePath != null) {
        // 更新数据库中的 cachedImageUrl 字段
        await _databaseService.updateCharacterCachedImage(
          characterId,
          cachedImagePath,
        );

        debugPrint('✅ 图片同步为角色头像成功: $targetFilename -> $cachedImagePath');
        return cachedImagePath;
      } else {
        debugPrint('❌ 图片缓存失败: $targetFilename');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 同步图片到角色头像失败: ${image.filename}, 错误: $e');
      return null;
    }
  }

  /// 同步角色的第一张图片（或置顶图片）为头像
  ///
  /// [characterId] 角色ID
  ///
  /// 返回同步的缓存路径，失败时返回null
  Future<String?> syncFirstImageToAvatar(int characterId) async {
    try {
      debugPrint('🔄 开始同步角色的第一张图片为头像: 角色ID $characterId');

      // 获取角色图集
      final apiService = ApiServiceProvider.instance;
      final galleryData = await apiService.getRoleGallery(characterId.toString());
      final gallery = RoleGallery.fromJson(galleryData);

      // 获取第一张图片（优先取置顶图片）
      final firstImage = gallery.firstImage;
      if (firstImage != null) {
        debugPrint('📸 找到图集第一张图片: ${firstImage.filename}');
        return await syncImageToCharacterAvatar(characterId, firstImage);
      } else {
        debugPrint('ℹ️ 角色图集为空: 角色ID $characterId');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 同步角色第一张图片失败: 角色ID $characterId, 错误: $e');
      return null;
    }
  }

  /// 检查角色是否已有有效的头像缓存
  ///
  /// [characterId] 角色ID
  /// [cachedImageUrl] 当前缓存的图片URL
  ///
  /// 返回是否已有有效的头像缓存
  Future<bool> hasValidAvatarCache(int characterId, String? cachedImageUrl) async {
    if (cachedImageUrl == null || cachedImageUrl.isEmpty) {
      return false;
    }

    if (!cachedImageUrl.startsWith('/')) {
      return false; // 不是本地文件路径
    }

    final file = File(cachedImageUrl);
    return await file.exists();
  }

  /// 清除角色的头像缓存
  ///
  /// [characterId] 角色ID
  ///
  /// 返回是否清除成功
  Future<bool> clearCharacterAvatar(int characterId) async {
    try {
      // 清除所有相关的头像缓存文件
      await _avatarCacheService.deleteCharacterCachedImages(characterId);

      // 清除数据库中的 cachedImageUrl 字段
      await _databaseService.clearCharacterCachedImage(characterId);

      debugPrint('✅ 清除角色头像缓存成功: 角色ID $characterId');
      return true;
    } catch (e) {
      debugPrint('❌ 清除角色头像缓存失败: 角色ID $characterId, 错误: $e');
      return false;
    }
  }

  /// 批量同步多个角色的头像
  ///
  /// [characterIds] 角色ID列表
  ///
  /// 返回同步结果映射表
  Future<Map<int, String?>> batchSyncCharacterAvatars(List<int> characterIds) async {
    final results = <int, String?>{};

    for (final characterId in characterIds) {
      final result = await syncFirstImageToAvatar(characterId);
      results[characterId] = result;
    }

    debugPrint('📊 批量同步角色头像完成: ${results.length} 个角色');
    return results;
  }
}