import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../core/di/api_service_provider.dart';

/// 角色图集缓存服务
class RoleGalleryCacheService {
  static final RoleGalleryCacheService _instance = RoleGalleryCacheService._internal();
  factory RoleGalleryCacheService() => _instance;
  RoleGalleryCacheService._internal();

  Directory? _cacheDir; // 改为可空类型
  final Map<String, String> _memoryCache = {};
  final int _maxMemoryCacheSize = 50; // 最大内存缓存数量
  final int _maxDiskCacheSizeMB = 200; // 最大磁盘缓存大小（MB）

  /// 初始化缓存服务
  Future<void> init() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${documentsDir.path}/role_gallery_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      // 清理过期的缓存文件
      await _cleanExpiredCache();

      debugPrint('✓ 角色图集缓存服务初始化完成');
      debugPrint('缓存目录: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('❌ 角色图集缓存服务初始化失败: $e');
    }
  }

  /// 确保缓存服务已初始化
  void _ensureInitialized() {
    if (_cacheDir == null) {
      throw Exception('RoleGalleryCacheService 未初始化，请先调用 init()');
    }
    if (!_cacheDir!.existsSync()) {
      throw Exception('RoleGalleryCacheService 缓存目录不存在');
    }
  }

  /// 获取缓存文件路径
  String _getCacheFilePath(String filename) {
    _ensureInitialized();
    final hash = md5.convert(utf8.encode(filename)).toString();
    return '${_cacheDir!.path}/$hash.jpg';
  }

  /// 获取文件名对应的缓存文件
  File? getCachedFile(String filename) {
    _ensureInitialized();
    final filePath = _getCacheFilePath(filename);
    final file = File(filePath);
    return file.existsSync() ? file : null;
  }

  /// 缓存图片
  Future<File?> cacheImage(String filename) async {
    try {
      // 先检查是否有缓存
      final existingFile = getCachedFile(filename);
      if (existingFile != null) {
        _addToMemoryCache(filename, existingFile.path);
        return existingFile;
      }

      // 使用ApiServiceWrapper确保正确的token认证和连接管理
      final apiService = ApiServiceProvider.instance;
      final bytes = await apiService.getImageProxy(filename);

      // ApiServiceWrapper.getImageProxy 直接返回 Uint8List

      // 验证图片数据有效性
      if (bytes.isEmpty) {
        debugPrint('❌ 图片数据为空: $filename');
        return null;
      }

      // 检查图片头部标识
      if (!_isValidImageData(bytes)) {
        debugPrint('❌ 无效的图片数据格式: $filename');
        return null;
      }

      // 保存到文件
      final filePath = _getCacheFilePath(filename);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      _addToMemoryCache(filename, filePath);
      debugPrint('✓ 图片缓存成功: $filename, 大小: ${bytes.length} bytes');
      return file;
    } catch (e) {
      debugPrint('❌ 图片缓存异常: $filename, 错误: $e');
      return null;
    }
  }

  /// 添加到内存缓存
  void _addToMemoryCache(String filename, String filePath) {
    // 如果内存缓存已满，删除最旧的项
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final firstKey = _memoryCache.keys.first;
      _memoryCache.remove(firstKey);
    }
    _memoryCache[filename] = filePath;
  }

  /// 从内存缓存获取
  File? getFromMemoryCache(String filename) {
    final filePath = _memoryCache[filename];
    if (filePath != null) {
      final file = File(filePath);
      return file.existsSync() ? file : null;
    }
    return null;
  }

  /// 获取图片字节数据（优先从缓存获取）
  Future<Uint8List?> getImageBytes(String filename) async {
    try {
      // 先检查内存缓存
      final memoryFile = getFromMemoryCache(filename);
      if (memoryFile != null) {
        return await memoryFile.readAsBytes();
      }

      // 再检查磁盘缓存
      final cachedFile = getCachedFile(filename);
      if (cachedFile != null) {
        _addToMemoryCache(filename, cachedFile.path);
        return await cachedFile.readAsBytes();
      }

      // 缓存中没有，使用API客户端获取并缓存
      final downloadedFile = await cacheImage(filename);
      if (downloadedFile != null) {
        return await downloadedFile.readAsBytes();
      }

      return null;
    } catch (e) {
      debugPrint('获取图片字节数据失败: $filename, 错误: $e');
      return null;
    }
  }

  /// 删除图片缓存
  Future<bool> deleteCachedImage(String filename) async {
    try {
      // 从内存缓存删除
      _memoryCache.remove(filename);

      // 从磁盘删除
      final filePath = _getCacheFilePath(filename);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✓ 图片缓存删除成功: $filename');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ 图片缓存删除失败: $filename, 错误: $e');
      return false;
    }
  }

  /// 获取缓存大小（MB）
  Future<double> getCacheSize() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return 0.0;

      final files = await _cacheDir!.list().toList();
      int totalSize = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return totalSize / (1024 * 1024); // 转换为MB
    } catch (e) {
      debugPrint('❌ 获取缓存大小失败: $e');
      return 0.0;
    }
  }

  /// 清理过期缓存文件
  Future<void> _cleanExpiredCache() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return;

      final files = await _cacheDir!.list().toList();
      final now = DateTime.now();
      const maxAge = Duration(days: 30); // 30天过期

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);

          if (age > maxAge) {
            await file.delete();
            debugPrint('🗑️  删除过期缓存文件: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 清理过期缓存失败: $e');
    }
  }

  /// 清理所有缓存
  Future<void> clearAllCache() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
      _memoryCache.clear();
      debugPrint('✓ 所有角色图集缓存已清理');
    } catch (e) {
      debugPrint('❌ 清理缓存失败: $e');
    }
  }

  /// 检查缓存是否超限并清理
  Future<void> checkAndCleanCache() async {
    try {
      final currentSize = await getCacheSize();

      if (currentSize > _maxDiskCacheSizeMB) {
        debugPrint('⚠️  缓存大小超限 (${currentSize.toStringAsFixed(2)}MB > $_maxDiskCacheSizeMB MB)，开始清理');

        final files = await _cacheDir!.list().toList();
        List<File> fileStats = [];

        for (final file in files) {
          if (file is File) {
            fileStats.add(file);
          }
        }

        // 按修改时间排序（最旧的在前）
        fileStats.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return aStat.modified.compareTo(bStat.modified);
        });

        // 删除最旧的文件直到缓存大小合适
        double targetSize = _maxDiskCacheSizeMB * 0.8; // 清理到80%
        int deletedCount = 0;

        for (final file in fileStats) {
          final currentSizeAfterDelete = await getCacheSize();
          if (currentSizeAfterDelete <= targetSize) break;

          await file.delete();
          deletedCount++;
        }

        debugPrint('✓ 缓存清理完成，删除了 $deletedCount 个文件');
      }
    } catch (e) {
      debugPrint('❌ 检查和清理缓存失败: $e');
    }
  }

  /// 预加载图片
  Future<void> preloadImages(List<String> filenames) async {
    for (final filename in filenames.take(3)) { // 最多预加载3张
      try {
        await cacheImage(filename);
      } catch (e) {
        debugPrint('⚠️  预加载图片失败: $filename, 错误: $e');
      }
    }
  }

  /// 获取内存缓存统计信息
  Map<String, dynamic> getMemoryCacheStats() {
    return {
      'size': _memoryCache.length,
      'maxSize': _maxMemoryCacheSize,
      'usage': '${(_memoryCache.length / _maxMemoryCacheSize * 100).toStringAsFixed(1)}%',
    };
  }

  /// 释放内存缓存
  void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('✓ 内存缓存已清理');
  }

  /// 验证图片数据是否有效
  bool _isValidImageData(Uint8List bytes) {
    if (bytes.length < 8) return false;

    // 检查常见图片格式的文件头
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
        bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
      return true;
    }

    // GIF: GIF87a 或 GIF89a
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
        bytes[3] == 0x38 && ((bytes[4] == 0x37 && bytes[5] == 0x61) || (bytes[4] == 0x39 && bytes[5] == 0x61))) {
      return true;
    }

    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return true;
    }

    // BMP: BM
    if (bytes.length >= 2 &&
        bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true;
    }

    return false;
  }
}