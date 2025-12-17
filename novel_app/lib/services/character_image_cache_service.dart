import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 角色图片缓存管理器
///
/// 负责管理角色图片的本地缓存，包括存储、检索和清理
class CharacterImageCacheService {
  static CharacterImageCacheService? _instance;
  static CharacterImageCacheService get instance {
    _instance ??= CharacterImageCacheService._();
    return _instance!;
  }

  CharacterImageCacheService._();

  late Directory _cacheDir;
  bool _initialized = false;

  /// 初始化缓存目录
  Future<void> init() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(appDir.path, 'character_images'));

      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }

      _initialized = true;
      debugPrint('角色图片缓存目录初始化完成: ${_cacheDir.path}');
    } catch (e) {
      debugPrint('初始化角色图片缓存目录失败: $e');
      rethrow;
    }
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  /// 获取角色图片缓存文件路径
  Future<String> getCharacterImagePath(int characterId, String filename) async {
    await _ensureInitialized();
    return path.join(_cacheDir.path, '${characterId}_$filename');
  }

  /// 缓存角色图片
  ///
  /// [characterId] 角色ID
  /// [imageData] 图片数据（bytes）
  /// [filename] 文件名
  /// 返回缓存的文件路径
  Future<String?> cacheCharacterImage(
    int characterId,
    List<int> imageData,
    String filename,
  ) async {
    try {
      await _ensureInitialized();

      final filePath = await getCharacterImagePath(characterId, filename);
      final file = File(filePath);

      await file.writeAsBytes(imageData);
      debugPrint('角色图片已缓存: $filePath');

      return filePath;
    } catch (e) {
      debugPrint('缓存角色图片失败: $e');
      return null;
    }
  }

  /// 缓存角色图片从网络URL
  ///
  /// [characterId] 角色ID
  /// [imageUrl] 网络图片URL
  /// [httpClient] HTTP客户端（可选）
  /// 返回缓存的文件路径
  Future<String?> cacheCharacterImageFromUrl(
    int characterId,
    String imageUrl, {
    dynamic httpClient,
  }) async {
    try {
      await _ensureInitialized();

      // 从URL提取文件名
      final uri = Uri.parse(imageUrl);
      final filename = path.basename(uri.path);
      if (filename.isEmpty) {
        // 如果URL没有文件名，使用默认名称
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = _getExtensionFromUrl(imageUrl);
        return await getCharacterImagePath(characterId, '$timestamp$extension');
      }

      final filePath = await getCharacterImagePath(characterId, filename);

      // 如果文件已存在，直接返回路径
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }

      // 下载图片（这里简化实现，实际项目中可能需要使用http包）
      // 这里只返回URL，实际下载需要在UI层处理
      debugPrint('准备缓存角色图片: $imageUrl -> $filePath');
      return imageUrl;

    } catch (e) {
      debugPrint('缓存角色图片URL失败: $e');
      return null;
    }
  }

  /// 获取角色图片缓存路径
  ///
  /// [characterId] 角色ID
  /// 返回第一个找到的图片路径，如果没有缓存则返回null
  Future<String?> getCharacterImagePathCached(int characterId) async {
    try {
      await _ensureInitialized();

      if (!await _cacheDir.exists()) {
        return null;
      }

      final files = await _cacheDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.startsWith('${characterId}_') && await file.exists()) {
            return file.path;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('获取角色图片缓存路径失败: $e');
      return null;
    }
  }

  /// 删除角色的所有缓存图片
  ///
  /// [characterId] 角色ID
  Future<bool> deleteCharacterCachedImages(int characterId) async {
    try {
      await _ensureInitialized();

      if (!await _cacheDir.exists()) {
        return true;
      }

      final files = await _cacheDir.list().toList();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.startsWith('${characterId}_')) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      debugPrint('删除了 $deletedCount 个角色图片缓存 (ID: $characterId)');
      return true;
    } catch (e) {
      debugPrint('删除角色图片缓存失败: $e');
      return false;
    }
  }

  /// 清理所有角色图片缓存
  Future<bool> clearAllCachedImages() async {
    try {
      await _ensureInitialized();

      if (await _cacheDir.exists()) {
        await _cacheDir.delete(recursive: true);
        await _cacheDir.create(recursive: true);
        debugPrint('已清理所有角色图片缓存');
      }

      return true;
    } catch (e) {
      debugPrint('清理所有角色图片缓存失败: $e');
      return false;
    }
  }

  /// 获取缓存目录大小
  Future<int> getCacheSize() async {
    try {
      await _ensureInitialized();

      if (!await _cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      final files = await _cacheDir.list().toList();

      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('获取缓存大小失败: $e');
      return 0;
    }
  }

  /// 获取缓存文件数量
  Future<int> getCacheFileCount() async {
    try {
      await _ensureInitialized();

      if (!await _cacheDir.exists()) {
        return 0;
      }

      final files = await _cacheDir.list().toList();
      int count = 0;

      for (final file in files) {
        if (file is File) {
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('获取缓存文件数量失败: $e');
      return 0;
    }
  }

  /// 检查图片是否已缓存
  Future<bool> isImageCached(int characterId, String filename) async {
    try {
      await _ensureInitialized();

      final filePath = await getCharacterImagePath(characterId, filename);
      final file = File(filePath);

      return await file.exists();
    } catch (e) {
      debugPrint('检查图片缓存状态失败: $e');
      return false;
    }
  }

  /// 从URL提取文件扩展名
  String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        final dotIndex = lastSegment.lastIndexOf('.');
        if (dotIndex != -1 && dotIndex < lastSegment.length - 1) {
          return lastSegment.substring(dotIndex);
        }
      }
    } catch (e) {
      debugPrint('从URL提取扩展名失败: $e');
    }

    return '.jpg'; // 默认扩展名
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();

    final size = await getCacheSize();
    final count = await getCacheFileCount();

    return {
      'totalSize': size,
      'fileCount': count,
      'cacheDir': _cacheDir.path,
      'sizeFormatted': _formatBytes(size),
    };
  }

  /// 格式化字节数为可读格式
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}