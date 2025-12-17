import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../core/di/api_service_provider.dart';
import 'api_service_wrapper.dart';

/// 场景插图缓存服务
/// 参考RoleGalleryCacheService的实现模式
class SceneIllustrationCacheService {
  static final SceneIllustrationCacheService _instance = SceneIllustrationCacheService._internal();
  factory SceneIllustrationCacheService() => _instance;
  SceneIllustrationCacheService._internal();

  Directory? _cacheDir;
  final Map<String, Uint8List> _memoryCache = {};
  final int _maxMemoryCacheSize = 30; // 场景插图内存缓存数量
  // final int _maxDiskCacheSizeMB = 100; // 场景插图磁盘缓存大小（MB） - 暂未使用

  final ApiServiceWrapper _apiService = ApiServiceProvider.instance;

  /// 初始化缓存服务
  Future<void> init() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${documentsDir.path}/scene_illustration_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      // 清理过期的缓存文件
      await _cleanExpiredCache();

      debugPrint('✓ 场景插图缓存服务初始化完成');
      debugPrint('缓存目录: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('❌ 场景插图缓存服务初始化失败: $e');
    }
  }

  /// 确保缓存服务已初始化
  void _ensureInitialized() {
    if (_cacheDir == null) {
      throw Exception('SceneIllustrationCacheService 未初始化，请先调用 init()');
    }
    if (!_cacheDir!.existsSync()) {
      throw Exception('SceneIllustrationCacheService 缓存目录不存在');
    }
  }

  /// 获取缓存文件路径
  String _getCacheFilePath(String filename) {
    _ensureInitialized();
    // 使用MD5哈希作为文件名，避免特殊字符问题
    final hash = md5.convert(utf8.encode(filename)).toString();
    return '${_cacheDir!.path}/$hash.jpg';
  }

  /// 从URL或文件名获取图片字节数据
  /// [filename] 可以是完整URL或相对文件名
  Future<Uint8List?> getImageBytes(String filename) async {
    try {
      _ensureInitialized();

      // 1. 检查内存缓存
      if (_memoryCache.containsKey(filename)) {
        debugPrint('从内存缓存获取场景插图: $filename');
        return _memoryCache[filename];
      }

      // 2. 检查磁盘缓存
      final cacheFilePath = _getCacheFilePath(filename);
      final cacheFile = File(cacheFilePath);
      if (await cacheFile.exists()) {
        debugPrint('从磁盘缓存获取场景插图: $filename');
        final bytes = await cacheFile.readAsBytes();

        // 加载到内存缓存
        _addToMemoryCache(filename, bytes);
        return bytes;
      }

      // 3. 从网络下载
      debugPrint('从网络下载场景插图: $filename');
      final imageUrl = await _buildImageUrl(filename);
      final bytes = await _downloadImage(imageUrl);

      if (bytes != null) {
        // 保存到磁盘缓存
        await _saveToDiskCache(filename, bytes);
        // 加载到内存缓存
        _addToMemoryCache(filename, bytes);
        return bytes;
      }

      return null;
    } catch (e) {
      debugPrint('获取场景插图失败: $filename, 错误: $e');
      return null;
    }
  }

  /// 构建完整的图片URL
  Future<String> _buildImageUrl(String filename) async {
    // 如果已经是完整URL，直接返回
    if (filename.startsWith('http')) {
      return filename;
    }

    // 否则构建后端URL
    final host = await _apiService.getHost();
    if (host == null) {
      throw Exception('后端HOST未配置');
    }

    final baseUrl = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    return '$baseUrl/static/illustrations/$filename';
  }

  /// 下载图片
  Future<Uint8List?> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'Novel-Builder/1.0',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint('下载图片失败: ${response.statusCode} - $imageUrl');
        return null;
      }
    } catch (e) {
      debugPrint('下载图片异常: $imageUrl, 错误: $e');
      return null;
    }
  }

  /// 添加到内存缓存
  void _addToMemoryCache(String filename, Uint8List bytes) {
    // 如果缓存已满，删除最旧的条目
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final firstKey = _memoryCache.keys.first;
      _memoryCache.remove(firstKey);
    }
    _memoryCache[filename] = bytes;
  }

  /// 保存到磁盘缓存
  Future<void> _saveToDiskCache(String filename, Uint8List bytes) async {
    try {
      final cacheFilePath = _getCacheFilePath(filename);
      final cacheFile = File(cacheFilePath);
      await cacheFile.writeAsBytes(bytes);
      debugPrint('场景插图已缓存到磁盘: $filename -> $cacheFilePath');
    } catch (e) {
      debugPrint('保存场景插图到磁盘失败: $filename, 错误: $e');
    }
  }

  /// 预加载图片
  Future<void> preloadImages(List<String> filenames) async {
    debugPrint('开始预加载场景插图: ${filenames.length} 张');

    // 并行预加载，但限制并发数
    final futures = <Future>[];
    const maxConcurrent = 3;

    for (int i = 0; i < filenames.length; i++) {
      futures.add(getImageBytes(filenames[i]));

      // 达到最大并发数时等待
      if (futures.length >= maxConcurrent) {
        await Future.wait(futures);
        futures.clear();
      }
    }

    // 处理剩余的图片
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    debugPrint('场景插图预加载完成');
  }

  /// 删除指定图片的缓存
  Future<void> deleteCachedImage(String filename) async {
    try {
      // 从内存缓存删除
      _memoryCache.remove(filename);

      // 从磁盘缓存删除
      _ensureInitialized();
      final cacheFilePath = _getCacheFilePath(filename);
      final cacheFile = File(cacheFilePath);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
        debugPrint('删除场景插图缓存: $filename');
      }
    } catch (e) {
      debugPrint('删除场景插图缓存失败: $filename, 错误: $e');
    }
  }

  /// 清理内存缓存
  void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('场景插图内存缓存已清理');
  }

  /// 清理所有缓存
  Future<void> clearAllCache() async {
    try {
      // 清理内存缓存
      _memoryCache.clear();

      // 清理磁盘缓存
      _ensureInitialized();
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }

      debugPrint('场景插图所有缓存已清理');
    } catch (e) {
      debugPrint('清理场景插图缓存失败: $e');
    }
  }

  /// 清理过期缓存
  Future<void> _cleanExpiredCache() async {
    try {
      _ensureInitialized();
      if (!await _cacheDir!.exists()) return;

      final files = await _cacheDir!.list().toList();
      final now = DateTime.now();
      const maxAge = Duration(days: 7); // 缓存有效期7天

      int deletedCount = 0;
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          if (now.difference(stat.modified) > maxAge) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint('清理了 $deletedCount 个过期的场景插图缓存文件');
      }
    } catch (e) {
      debugPrint('清理过期缓存失败: $e');
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      _ensureInitialized();

      int totalSize = 0;
      int fileCount = 0;

      if (await _cacheDir!.exists()) {
        final files = await _cacheDir!.list().toList();
        for (final file in files) {
          if (file is File) {
            totalSize += await file.length();
            fileCount++;
          }
        }
      }

      return {
        'memoryCacheCount': _memoryCache.length,
        'diskCacheCount': fileCount,
        'diskCacheSize': totalSize,
        'diskCacheSizeFormatted': _formatBytes(totalSize),
        'cacheDir': _cacheDir!.path,
      };
    } catch (e) {
      debugPrint('获取缓存统计失败: $e');
      return {};
    }
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}