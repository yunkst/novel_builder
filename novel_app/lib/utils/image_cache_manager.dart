import 'package:flutter/foundation.dart';
import '../services/api_service_wrapper.dart';
import 'format_utils.dart';

/// 图片缓存管理器
/// 用于管理插图图片的缓存和生命周期，避免重复从后端加载
class ImageCacheManager {
  /// 缓存存储：key 为图片 URL/filename，value 为图片二进制数据
  static final Map<String, Uint8List> _cache = {};

  /// 缓存创建时间：用于 LRU 策略
  static final Map<String, DateTime> _cacheTime = {};

  /// 正在加载中的图片请求（防止重复请求）
  static final Map<String, Future<Uint8List>> _loadingRequests = {};

  /// API 服务包装器
  static ApiServiceWrapper? _apiService;

  /// 最大缓存数量
  static const int _maxCacheSize = 50;

  /// 最大单张图片大小（20MB）
  static const int _maxImageSize = 20 * 1024 * 1024;

  /// 初始化 API 服务
  static void _ensureApiService() {
    _apiService ??= ApiServiceWrapper();
  }

  /// 检查缓存是否有效
  static bool _isCacheValid(String key) {
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
      debugPrint(
          '🗑️ 清理最旧图片缓存: $oldestKey, 大小: ${FormatUtils.formatFileSize(size)}');
    }
  }

  /// 获取图片数据（带缓存）
  static Future<Uint8List> getImage(String imageUrl) async {
    _ensureApiService();

    // 检查内存缓存
    if (_isCacheValid(imageUrl)) {
      // 更新访问时间（LRU）
      _cacheTime[imageUrl] = DateTime.now();
      debugPrint('✅ 命中图片缓存: $imageUrl');
      return _cache[imageUrl]!;
    }

    // 检查是否正在加载中（防止重复请求）
    if (_loadingRequests.containsKey(imageUrl)) {
      debugPrint('⏳ 等待其他实例加载图片: $imageUrl');
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
  static Future<Uint8List> _loadImageFromBackend(String imageUrl) async {
    try {
      debugPrint('📥 从后端加载图片: $imageUrl');

      final data = await _apiService!.getImageProxy(imageUrl);

      // 验证数据大小
      if (data.isEmpty) {
        throw Exception('图片数据为空');
      }

      if (data.length > _maxImageSize) {
        debugPrint('⚠️ 图片过大，跳过缓存: ${FormatUtils.formatFileSize(data.length)}');
        return data;
      }

      // 缓存数量限制
      if (_cache.length >= _maxCacheSize) {
        _evictOldest();
      }

      // 存入缓存
      _cache[imageUrl] = data;
      _cacheTime[imageUrl] = DateTime.now();

      debugPrint(
          '✅ 图片已缓存: $imageUrl, 大小: ${FormatUtils.formatFileSize(data.length)}, '
          '缓存数量: ${_cache.length}/$_maxCacheSize');

      return data;
    } catch (e) {
      debugPrint('❌ 加载图片失败: $imageUrl, 错误: $e');
      rethrow;
    }
  }

  /// 预加载图片（后台加载）
  static Future<void> prefetchImage(String imageUrl) async {
    try {
      await getImage(imageUrl);
      debugPrint('🔄 预加载完成: $imageUrl');
    } catch (e) {
      debugPrint('⚠️ 预加载失败: $imageUrl, 错误: $e');
    }
  }

  /// 批量预加载图片
  static Future<void> prefetchImages(List<String> imageUrls) async {
    debugPrint('🔄 开始批量预加载 ${imageUrls.length} 张图片');
    await Future.wait(
      imageUrls.map((url) => prefetchImage(url)),
      eagerError: false, // 即使某个失败也继续加载其他
    );
    debugPrint('✅ 批量预加载完成');
  }

  /// 清除指定图片的缓存
  static bool removeCache(String imageUrl) {
    final removed = _cache.remove(imageUrl);
    _cacheTime.remove(imageUrl);
    if (removed != null) {
      debugPrint('🗑️ 清除图片缓存: $imageUrl');
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
    debugPrint(
        '🗑️ 清除所有图片缓存: $count 张, 总大小: ${FormatUtils.formatFileSize(totalSize)}');
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
    debugPrint('📊 图片缓存统计:');
    debugPrint('   - 缓存数量: ${info['cachedCount']}/${info['maxCacheSize']} '
        '(${info['usagePercent']}%)');
    debugPrint('   - 总大小: ${info['totalSize']}');
    debugPrint('   - 正在加载: ${info['loadingCount']}');
  }

  /// 获取缓存命中率估算（仅供调试）
  static double getCacheHitRate() {
    // 这是一个简化的估算，实际应该统计请求数
    if (_cache.isEmpty) return 0.0;
    return _cache.length / (_cache.length + _loadingRequests.length);
  }
}
