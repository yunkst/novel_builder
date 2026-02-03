import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'logger_service.dart';
import 'api_service_wrapper.dart';
import '../utils/cache_utils.dart';
import '../utils/format_utils.dart';

/// 场景插图缓存服务
/// 参考RoleGalleryCacheService的实现模式
class SceneIllustrationCacheService {
  /// 构造函数 - 支持依赖注入
  ///
  /// [apiService] 可选的API服务实例，用于测试和依赖注入
  SceneIllustrationCacheService({ApiServiceWrapper? apiService})
      : _apiService = apiService;

  ApiServiceWrapper? _apiService;

  Directory? _cacheDir;
  final Map<String, Uint8List> _memoryCache = {};
  final int _maxMemoryCacheSize = 30; // 场景插图内存缓存数量
  // final int _maxDiskCacheSizeMB = 100; // 场景插图磁盘缓存大小（MB） - 暂未使用

  /// 设置API服务（依赖注入）
  /// @deprecated 请使用构造函数注入
  @Deprecated('请使用构造函数注入 ApiServiceWrapper')
  void setApiService(ApiServiceWrapper apiService) {
    _apiService = apiService;
  }

  /// 确保API服务已初始化
  void _ensureApiService() {
    if (_apiService == null) {
      throw Exception('ApiServiceWrapper 未设置，请先调用 setApiService()');
    }
  }

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

      LoggerService.instance.i(
        '场景插图缓存服务初始化完成',
        category: LogCategory.cache,
        tags: ['illustration', 'init', 'success'],
      );
      LoggerService.instance.d(
        '缓存目录: ${_cacheDir!.path}',
        category: LogCategory.cache,
        tags: ['illustration', 'path'],
      );
    } catch (e) {
      LoggerService.instance.e(
        '场景插图缓存服务初始化失败',
        category: LogCategory.cache,
        tags: ['illustration', 'init', 'error'],
      );
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
    final hash = CacheUtils.generateHashFilename(filename);
    return '${_cacheDir!.path}/$hash.jpg';
  }

  /// 从URL或文件名获取图片字节数据
  /// [filename] 可以是完整URL或相对文件名
  Future<Uint8List?> getImageBytes(String filename) async {
    try {
      _ensureInitialized();

      // 1. 检查内存缓存
      if (_memoryCache.containsKey(filename)) {
        LoggerService.instance.d(
          '从内存缓存获取场景插图',
          category: LogCategory.cache,
          tags: ['illustration', 'memory', 'hit'],
        );
        return _memoryCache[filename];
      }

      // 2. 检查磁盘缓存
      final cacheFilePath = _getCacheFilePath(filename);
      final cacheFile = File(cacheFilePath);
      if (await cacheFile.exists()) {
        LoggerService.instance.d(
          '从磁盘缓存获取场景插图',
          category: LogCategory.cache,
          tags: ['illustration', 'disk', 'hit'],
        );
        final bytes = await cacheFile.readAsBytes();

        // 加载到内存缓存
        _addToMemoryCache(filename, bytes);
        return bytes;
      }

      // 3. 从网络下载
      LoggerService.instance.d(
        '从网络下载场景插图',
        category: LogCategory.cache,
        tags: ['illustration', 'network', 'download'],
      );
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
      LoggerService.instance.e(
        '获取场景插图失败',
        category: LogCategory.cache,
        tags: ['illustration', 'error'],
      );
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
    _ensureApiService();
    final host = await _apiService!.getHost();
    if (host == null) {
      throw Exception('后端HOST未配置');
    }

    final baseUrl =
        host.endsWith('/') ? host.substring(0, host.length - 1) : host;
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
        LoggerService.instance.w(
          '下载图片失败: ${response.statusCode}',
          category: LogCategory.cache,
          tags: ['illustration', 'download', 'http'],
        );
        return null;
      }
    } catch (e) {
      LoggerService.instance.e(
        '下载图片异常',
        category: LogCategory.cache,
        tags: ['illustration', 'download', 'exception'],
      );
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
      LoggerService.instance.d(
        '场景插图已缓存到磁盘',
        category: LogCategory.cache,
        tags: ['illustration', 'disk', 'save'],
      );
    } catch (e) {
      LoggerService.instance.e(
        '保存场景插图到磁盘失败',
        category: LogCategory.cache,
        tags: ['illustration', 'disk', 'error'],
      );
    }
  }

  /// 预加载图片
  Future<void> preloadImages(List<String> filenames) async {
    LoggerService.instance.i(
      '开始预加载场景插图: ${filenames.length} 张',
      category: LogCategory.cache,
      tags: ['illustration', 'preload', 'start'],
    );

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

    LoggerService.instance.i(
      '场景插图预加载完成',
      category: LogCategory.cache,
      tags: ['illustration', 'preload', 'done'],
    );
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
        LoggerService.instance.d(
          '删除场景插图缓存',
          category: LogCategory.cache,
          tags: ['illustration', 'delete'],
        );
      }
    } catch (e) {
      LoggerService.instance.e(
        '删除场景插图缓存失败',
        category: LogCategory.cache,
        tags: ['illustration', 'delete', 'error'],
      );
    }
  }

  /// 清理内存缓存
  void clearMemoryCache() {
    _memoryCache.clear();
    LoggerService.instance.i(
      '场景插图内存缓存已清理',
      category: LogCategory.cache,
      tags: ['illustration', 'memory', 'clear'],
    );
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

      LoggerService.instance.i(
        '场景插图所有缓存已清理',
        category: LogCategory.cache,
        tags: ['illustration', 'clear', 'all'],
      );
    } catch (e) {
      LoggerService.instance.e(
        '清理场景插图缓存失败',
        category: LogCategory.cache,
        tags: ['illustration', 'clear', 'error'],
      );
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
        LoggerService.instance.i(
          '清理了 $deletedCount 个过期的场景插图缓存文件',
          category: LogCategory.cache,
          tags: ['illustration', 'cleanup', 'expired'],
        );
      }
    } catch (e) {
      LoggerService.instance.e(
        '清理过期缓存失败',
        category: LogCategory.cache,
        tags: ['illustration', 'cleanup', 'error'],
      );
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
        'diskCacheSizeFormatted': FormatUtils.formatFileSize(totalSize),
        'cacheDir': _cacheDir!.path,
      };
    } catch (e) {
      LoggerService.instance.e(
        '获取缓存统计失败',
        category: LogCategory.cache,
        tags: ['illustration', 'stats', 'error'],
      );
      return {};
    }
  }
}
