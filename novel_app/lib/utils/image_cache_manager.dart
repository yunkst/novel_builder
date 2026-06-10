import 'package:flutter/foundation.dart';
import '../services/api_service_wrapper.dart';
import '../services/logger_service.dart';
import 'format_utils.dart';

/// 图片缓存管理器
/// 用于管理插图图片的缓存和生命周期，避免重复从后端加载
///
/// ## 架构说明
/// - 缓存存储：静态字段（全局共享，所有实例共用同一缓存）
/// - API 服务：实例字段（通过依赖注入，便于测试）
/// - 使用方式：通过 Provider 获取实例
class ImageCacheManager {
  /// 缓存存储：key 为图片 URL/filename，value 为图片二进制数据
  static final Map<String, Uint8List> _cache = {};

  /// 缓存创建时间：用于 LRU 策略
  static final Map<String, DateTime> _cacheTime = {};

  /// 正在加载中的图片请求（防止重复请求）
  static final Map<String, Future<Uint8List>> _loadingRequests = {};

  /// API 服务包装器（实例字段，通过构造函数注入）
  final ApiServiceWrapper _apiService;

  /// 最大缓存数量
  static const int _maxCacheSize = 50;

  /// 最大单张图片大小（20MB）
  static const int _maxImageSize = 20 * 1024 * 1024;

  /// 构造函数 - 接收注入的 ApiServiceWrapper
  ///
  /// [apiService] API 服务实例（必需）
  const ImageCacheManager({
    required ApiServiceWrapper apiService,
  }) : _apiService = apiService;

  /// 检查缓存是否有效
  bool _isCacheValid(String key) {
    return _cache.containsKey(key) &&
        _cache[key] != null &&
        _cache[key]!.isNotEmpty;
  }

  /// 清理最旧的缓存项（LRU 策略）
  static void _evictOldest() {
    if (_cacheTime.isEmpty) return;

    // 找到最旧的缓存项
    String? oldestKey;
    DateTime? oldestTime;

    _cacheTime.forEach((key, time) {
      if (oldestTime == null || time.isBefore(oldestTime!)) {
        oldestTime = time;
        oldestKey = key;
      }
    });

    if (oldestKey != null) {
      final removed = _cache.remove(oldestKey);
      _cacheTime.remove(oldestKey);
      final size = removed?.length ?? 0;
      LoggerService.instance.d(
        '清理最旧图片缓存: $oldestKey, 大小: ${FormatUtils.formatFileSize(size)}',
        category: LogCategory.cache,
        tags: ['image', 'evict'],
      );
    }
  }

  /// 获取图片数据（带缓存）
  Future<Uint8List> getImage(String imageUrl) async {
    // 检查内存缓存
    if (_isCacheValid(imageUrl)) {
      // 更新访问时间（LRU）
      _cacheTime[imageUrl] = DateTime.now();
      LoggerService.instance.d(
        '命中图片缓存: $imageUrl',
        category: LogCategory.cache,
        tags: ['image', 'hit'],
      );
      return _cache[imageUrl]!;
    }

    // 检查是否正在加载中（防止重复请求）
    if (_loadingRequests.containsKey(imageUrl)) {
      LoggerService.instance.d(
        '等待其他实例加载图片: $imageUrl',
        category: LogCategory.cache,
        tags: ['image', 'loading'],
      );
      return await _loadingRequests[imageUrl]!;
    }

    // 创建新的加载请求
    final loadingRequest = _loadImageFromBackend(imageUrl);
    _loadingRequests[imageUrl] = loadingRequest;

    try {
      final data = await loadingRequest;
      return data;
    } finally {
      // 移除加载标记
      _loadingRequests.remove(imageUrl);
    }
  }

  /// 从后端加载图片
  Future<Uint8List> _loadImageFromBackend(String imageUrl) async {
    try {
      LoggerService.instance.i(
        '从后端加载图片: $imageUrl',
        category: LogCategory.cache,
        tags: ['image', 'load'],
      );

      final data = await _apiService.getImageProxy(imageUrl);

      // 验证数据大小
      if (data.isEmpty) {
        throw Exception('图片数据为空');
      }

      if (data.length > _maxImageSize) {
        LoggerService.instance.w(
          '图片过大，跳过缓存: ${FormatUtils.formatFileSize(data.length)}',
          category: LogCategory.cache,
          tags: ['image', 'oversize'],
        );
        return data;
      }

      // 缓存数量限制
      if (_cache.length >= _maxCacheSize) {
        _evictOldest();
      }

      // 存入缓存
      _cache[imageUrl] = data;
      _cacheTime[imageUrl] = DateTime.now();

      LoggerService.instance.i(
        '图片已缓存: $imageUrl, 大小: ${FormatUtils.formatFileSize(data.length)}, '
            '缓存数量: ${_cache.length}/$_maxCacheSize',
        category: LogCategory.cache,
        tags: ['image', 'cached'],
      );

      return data;
    } catch (e) {
      LoggerService.instance.e(
        '加载图片失败: $imageUrl, 错误: $e',
        category: LogCategory.cache,
        tags: ['image', 'load', 'error'],
      );
      rethrow;
    }
  }

  /// 预加载图片（后台加载）
  Future<void> prefetchImage(String imageUrl) async {
    try {
      await getImage(imageUrl);
      LoggerService.instance.d(
        '预加载完成: $imageUrl',
        category: LogCategory.cache,
        tags: ['image', 'prefetch'],
      );
    } catch (e) {
      LoggerService.instance.w(
        '预加载失败: $imageUrl, 错误: $e',
        category: LogCategory.cache,
        tags: ['image', 'prefetch', 'error'],
      );
    }
  }

  /// 批量预加载图片
  Future<void> prefetchImages(List<String> imageUrls) async {
    LoggerService.instance.i(
      '开始批量预加载 ${imageUrls.length} 张图片',
      category: LogCategory.cache,
      tags: ['image', 'prefetch', 'batch'],
    );
    await Future.wait(
      imageUrls.map((url) => prefetchImage(url)),
      eagerError: false, // 即使某个失败也继续加载其他
    );
    LoggerService.instance.i(
      '批量预加载完成',
      category: LogCategory.cache,
      tags: ['image', 'prefetch', 'batch', 'done'],
    );
  }

  /// 清除指定图片的缓存
  static bool removeCache(String imageUrl) {
    final removed = _cache.remove(imageUrl);
    _cacheTime.remove(imageUrl);
    if (removed != null) {
      LoggerService.instance.d(
        '清除图片缓存: $imageUrl',
        category: LogCategory.cache,
        tags: ['image', 'remove'],
      );
      return true;
    }
    return false;
  }

  /// 清除所有缓存
  static void clearAll() {
    final totalSize =
        _cache.values.fold<int>(0, (sum, data) => sum + data.length);
    final count = _cache.length;
    _cache.clear();
    _cacheTime.clear();
    _loadingRequests.clear();
    LoggerService.instance.i(
      '清除所有图片缓存: $count 张, 总大小: ${FormatUtils.formatFileSize(totalSize)}',
      category: LogCategory.cache,
      tags: ['image', 'clear'],
    );
  }

  /// 获取缓存统计信息
  static Map<String, dynamic> getCacheInfo() {
    final totalSize =
        _cache.values.fold<int>(0, (sum, data) => sum + data.length);

    return {
      'cachedCount': _cache.length,
      'maxCacheSize': _maxCacheSize,
      'totalSize': FormatUtils.formatFileSize(totalSize),
      'totalSizeBytes': totalSize,
      'loadingCount': _loadingRequests.length,
      'cachedUrls': _cache.keys.toList(),
      'usagePercent': (_cache.length / _maxCacheSize * 100).toStringAsFixed(1),
    };
  }

  /// 打印缓存统计信息（用于调试）
  static void printCacheInfo() {
    final info = getCacheInfo();
    LoggerService.instance.i(
      '图片缓存统计: 缓存数量=${info['cachedCount']}/${info['maxCacheSize']} '
          '(${info['usagePercent']}%), 总大小=${info['totalSize']}, '
          '正在加载=${info['loadingCount']}',
      category: LogCategory.cache,
      tags: ['image', 'stats'],
    );
  }

  /// 获取缓存命中率估算（仅供调试）
  static double getCacheHitRate() {
    // 这是一个简化的估算，实际应该统计请求数
    if (_cache.isEmpty) return 0.0;
    return _cache.length / (_cache.length + _loadingRequests.length);
  }
}
