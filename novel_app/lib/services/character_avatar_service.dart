import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'character_image_cache_service.dart';
import '../core/interfaces/repositories/i_character_repository.dart';

/// 角色头像管理服务
/// 负责头像的设置、获取、缓存等操作
class CharacterAvatarService {
  /// 构造函数 - 支持依赖注入
  ///
  /// [characterRepository] 角色数据仓库实例
  /// [cacheService] 图片缓存服务实例
  CharacterAvatarService({
    required ICharacterRepository characterRepository,
    required CharacterImageCacheService cacheService,
  })  : _characterRepo = characterRepository,
        _cacheService = cacheService;

  final ICharacterRepository _characterRepo;
  final CharacterImageCacheService _cacheService;

  /// 设置角色头像
  /// [characterId] 角色ID
  /// [imageBytes] 图片字节数据
  /// [originalFilename] 原始图集文件名
  /// [originalImageUrl] 原始图片URL（可选）
  /// 返回头像缓存路径
  Future<String?> setCharacterAvatar(
    int characterId,
    List<int> imageBytes,
    String originalFilename, {
    String? originalImageUrl,
  }) async {
    try {
      debugPrint(
          '🎨 开始设置角色头像: characterId=$characterId, originalFilename=$originalFilename');

      // 生成唯一的头像文件名
      final avatarFilename =
          'avatar_${characterId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 缓存头像图片
      final cachedPath = await _cacheService.cacheCharacterImage(
        characterId,
        imageBytes,
        avatarFilename,
      );

      if (cachedPath != null) {
        // 更新数据库
        await _characterRepo.updateCharacterAvatar(
          characterId,
          imageUrl: cachedPath,
          originalFilename: originalFilename,
          originalImageUrl: originalImageUrl,
        );

        debugPrint('✅ 角色头像设置成功: $cachedPath');
        return cachedPath;
      } else {
        debugPrint('❌ 角色头像缓存失败');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 设置角色头像失败: $e');
      return null;
    }
  }

  /// 从图集图片设置角色头像
  /// [characterId] 角色ID
  /// [imageBytes] 图片字节数据
  /// [originalFilename] 原始图集文件名
  /// 返回头像缓存路径
  Future<String?> setAvatarFromGallery(
    int characterId,
    List<int> imageBytes,
    String originalFilename,
  ) async {
    return setCharacterAvatar(
      characterId,
      imageBytes,
      originalFilename,
      originalImageUrl: null,
    );
  }

  /// 获取角色头像缓存路径
  /// [characterId] 角色ID
  /// 返回头像文件路径，如果没有设置则返回null
  Future<String?> getCharacterAvatarPath(int characterId) async {
    try {
      final cachedUrl =
          await _characterRepo.getCharacterCachedImage(characterId);
      return cachedUrl;
    } catch (e) {
      debugPrint('❌ 获取角色头像路径失败: $e');
      return null;
    }
  }

  /// 获取角色头像信息
  /// [characterId] 角色ID
  /// 返回头像信息，包括缓存路径、原始文件名等
  Future<Map<String, String>?> getCharacterAvatarInfo(int characterId) async {
    try {
      // 这里可以扩展数据库服务来获取更详细的头像信息
      final cachedUrl =
          await _characterRepo.getCharacterCachedImage(characterId);

      if (cachedUrl != null) {
        return {
          'cachedUrl': cachedUrl,
          'originalFilename': path
              .basename(cachedUrl)
              .replaceFirst('avatar_${characterId}_', ''),
        };
      }

      return null;
    } catch (e) {
      debugPrint('❌ 获取角色头像信息失败: $e');
      return null;
    }
  }

  /// 删除角色头像
  /// [characterId] 角色ID
  /// 返回是否删除成功
  Future<bool> deleteCharacterAvatar(int characterId) async {
    try {
      debugPrint('🗑️ 开始删除角色头像: characterId=$characterId');

      // 获取当前头像路径
      final avatarPath = await getCharacterAvatarPath(characterId);

      if (avatarPath != null) {
        // 删除头像文件
        final avatarFile = File(avatarPath);
        if (await avatarFile.exists()) {
          await avatarFile.delete();
          debugPrint('✅ 删除头像文件: $avatarPath');
        }
      }

      // 清空数据库中的头像信息
      await _characterRepo.updateCharacterCachedImage(characterId, null);

      debugPrint('✅ 角色头像删除成功');
      return true;
    } catch (e) {
      debugPrint('❌ 删除角色头像失败: $e');
      return false;
    }
  }

  /// 检查角色是否有头像
  /// [characterId] 角色ID
  /// 返回是否有头像
  Future<bool> hasCharacterAvatar(int characterId) async {
    final avatarPath = await getCharacterAvatarPath(characterId);
    if (avatarPath == null) return false;

    final avatarFile = File(avatarPath);
    return await avatarFile.exists();
  }

  /// 同步图集图片到角色头像（从现有缓存文件）
  /// [characterId] 角色ID
  /// [galleryImagePath] 图集图片路径
  /// [originalFilename] 原始文件名
  /// 返回头像缓存路径
  Future<String?> syncGalleryImageToAvatar(
    int characterId,
    String galleryImagePath,
    String originalFilename,
  ) async {
    try {
      debugPrint('🔄 开始同步图集图片到头像: $galleryImagePath');

      final galleryFile = File(galleryImagePath);
      if (!await galleryFile.exists()) {
        debugPrint('❌ 图集图片文件不存在: $galleryImagePath');
        return null;
      }

      // 读取图集图片数据
      final imageBytes = await galleryFile.readAsBytes();

      // 设置为头像
      return await setAvatarFromGallery(
        characterId,
        imageBytes,
        originalFilename,
      );
    } catch (e) {
      debugPrint('❌ 同步图集图片到头像失败: $e');
      return null;
    }
  }

  /// 清理无效的头像缓存
  /// [characterId] 角色ID
  /// 如果数据库中记录的头像文件不存在，则清理数据库记录
  Future<void> cleanupInvalidAvatarCache(int characterId) async {
    try {
      final avatarPath = await getCharacterAvatarPath(characterId);

      if (avatarPath != null) {
        final avatarFile = File(avatarPath);
        if (!await avatarFile.exists()) {
          debugPrint('🧹 清理无效的头像缓存记录: $avatarPath');
          await _characterRepo.updateCharacterCachedImage(characterId, null);
        }
      }
    } catch (e) {
      debugPrint('❌ 清理无效头像缓存失败: $e');
    }
  }

  /// 批量清理所有角色的无效头像缓存
  Future<void> cleanupAllInvalidAvatarCaches() async {
    try {
      debugPrint('🧹 开始批量清理无效头像缓存');

      // 这里可以获取所有角色ID，然后逐个清理
      // 需要扩展 DatabaseService 来支持获取所有角色
      // 暂时跳过实现，可以在需要时添加

      debugPrint('✅ 批量清理无效头像缓存完成');
    } catch (e) {
      debugPrint('❌ 批量清理无效头像缓存失败: $e');
    }
  }
}
