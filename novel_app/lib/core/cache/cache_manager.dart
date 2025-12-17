import '../utils/result.dart';
import '../failures/cache_failure.dart';
import '../utils/error_handler.dart';

/// 缓存项
class CacheItem<T> {
  final T data;
  final DateTime createdAt;
  final DateTime? expiresAt;

  CacheItem(this.data, {this.expiresAt}) : createdAt = DateTime.now();

  /// 是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 剩余存活时间
  Duration? get timeToLive {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  /// 年龄（创建时间到现在）
  Duration get age => DateTime.now().difference(createdAt);

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory CacheItem.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJson,
  ) {
    final data = fromJson(json['data']);
    final createdAt = DateTime.parse(json['createdAt']);
    final expiresAt = json['expiresAt'] != null
        ? DateTime.parse(json['expiresAt'])
        : null;

    return CacheItem<T>._internal(data, createdAt: createdAt, expiresAt: expiresAt);
  }

  /// 内部构造函数，允许设置创建时间
  CacheItem._internal(
    this.data, {
    required this.createdAt,
    this.expiresAt,
  });
}

/// 统一缓存管理器
class CacheManager {
  final Map<String, CacheItem> _cache = {};
  final int _maxSize;
  final Duration _defaultExpiration;

  CacheManager({
    int maxSize = 1000,
    Duration defaultExpiration = const Duration(hours: 1),
  }) : _maxSize = maxSize,
       _defaultExpiration = defaultExpiration;

  /// 存储数据到缓存
  Future<Result<void>> set<T>(
    String key,
    T data, {
    Duration? expiration,
  }) async {
    try {
      final item = CacheItem<T>(
        data,
        expiresAt: expiration != null
            ? DateTime.now().add(expiration)
            : DateTime.now().add(_defaultExpiration),
      );

      _cache[key] = item;

      // 检查缓存大小，必要时清理
      await _ensureSizeLimit();

      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to set cache: $e'),
        'CacheManager.set',
      );
      return Result.failure(CacheFailure('缓存设置失败: $e'));
    }
  }

  /// 从缓存获取数据
  Future<Result<T?>> get<T>(String key) async {
    try {
      final item = _cache[key];
      if (item == null) {
        return Result.success(null);
      }

      if (item.isExpired) {
        _cache.remove(key);
        return Result.success(null);
      }

      if (item.data is T) {
        return Result.success(item.data as T);
      } else {
        return Result.failure(CacheFailure('缓存数据类型不匹配'));
      }
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to get cache: $e'),
        'CacheManager.get',
      );
      return Result.failure(CacheFailure('缓存获取失败: $e'));
    }
  }

  /// 检查缓存是否存在且未过期
  Future<Result<bool>> has(String key) async {
    try {
      final item = _cache[key];
      if (item == null) {
        return Result.success(false);
      }

      if (item.isExpired) {
        _cache.remove(key);
        return Result.success(false);
      }

      return Result.success(true);
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to check cache existence: $e'),
        'CacheManager.has',
      );
      return Result.failure(CacheFailure('检查缓存失败: $e'));
    }
  }

  /// 删除缓存项
  Future<Result<void>> remove(String key) async {
    try {
      _cache.remove(key);
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to remove cache: $e'),
        'CacheManager.remove',
      );
      return Result.failure(CacheFailure('删除缓存失败: $e'));
    }
  }

  /// 清空所有缓存
  Future<Result<void>> clear() async {
    try {
      _cache.clear();
      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to clear cache: $e'),
        'CacheManager.clear',
      );
      return Result.failure(CacheFailure('清空缓存失败: $e'));
    }
  }

  /// 清理过期缓存
  Future<Result<int>> cleanExpired() async {
    try {
      final expiredKeys = <String>[];
      _cache.forEach((key, item) {
        if (item.isExpired) {
          expiredKeys.add(key);
        }
      });

      for (final key in expiredKeys) {
        _cache.remove(key);
      }

      return Result.success(expiredKeys.length);
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to clean expired cache: $e'),
        'CacheManager.cleanExpired',
      );
      return Result.failure(CacheFailure('清理过期缓存失败: $e'));
    }
  }

  /// 获取缓存统计信息
  CacheStats getStats() {
    var totalSize = 0;
    var expiredCount = 0;
    final ages = <Duration>[];

    _cache.forEach((key, item) {
      totalSize++;
      ages.add(item.age);

      if (item.isExpired) {
        expiredCount++;
      }
    });

    ages.sort();

    return CacheStats(
      totalSize: totalSize,
      maxSize: _maxSize,
      expiredCount: expiredCount,
      averageAge: ages.isEmpty
          ? Duration.zero
          : Duration(
              milliseconds: ages
                  .map((d) => d.inMilliseconds)
                  .reduce((a, b) => a + b) ~/ ages.length,
            ),
      oldestAge: ages.isEmpty ? Duration.zero : ages.last,
      newestAge: ages.isEmpty ? Duration.zero : ages.first,
    );
  }

  /// 确保缓存大小不超过限制
  Future<void> _ensureSizeLimit() async {
    if (_cache.length <= _maxSize) return;

    // 按访问时间排序，删除最旧的项
    final sortedEntries = _cache.entries.toList()
      ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

    final itemsToRemove = _cache.length - _maxSize;
    for (var i = 0; i < itemsToRemove; i++) {
      _cache.remove(sortedEntries[i].key);
    }
  }

  /// 预热缓存（批量设置）
  Future<Result<void>> warmUp<T>(
    Map<String, T> data, {
    Duration? expiration,
  }) async {
    try {
      final expiresAt = expiration != null
          ? DateTime.now().add(expiration)
          : DateTime.now().add(_defaultExpiration);

      data.forEach((key, value) {
        _cache[key] = CacheItem<T>(value, expiresAt: expiresAt);
      });

      await _ensureSizeLimit();

      return Result.success(null);
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to warm up cache: $e'),
        'CacheManager.warmUp',
      );
      return Result.failure(CacheFailure('缓存预热失败: $e'));
    }
  }

  /// 获取或设置缓存（如果不存在则通过fetchFunction获取）
  Future<Result<T>> getOrSet<T>(
    String key,
    Future<T> Function() fetchFunction, {
    Duration? expiration,
  }) async {
    try {
      // 尝试从缓存获取
      final cachedResult = await get<T>(key);
      if (cachedResult.isSuccess && cachedResult.data != null) {
        return Result.success(cachedResult.data as T);
      }

      // 缓存不存在或已过期，通过函数获取
      final data = await fetchFunction();

      // 存储到缓存
      await set(key, data, expiration: expiration);

      return Result.success(data);
    } catch (e) {
      ErrorHandler.logError(
        CacheFailure('Failed to get or set cache: $e'),
        'CacheManager.getOrSet',
      );
      return Result.failure(CacheFailure('缓存获取或设置失败: $e'));
    }
  }
}

/// 缓存统计信息
class CacheStats {
  final int totalSize;
  final int maxSize;
  final int expiredCount;
  final Duration averageAge;
  final Duration oldestAge;
  final Duration newestAge;

  CacheStats({
    required this.totalSize,
    required this.maxSize,
    required this.expiredCount,
    required this.averageAge,
    required this.oldestAge,
    required this.newestAge,
  });

  double get utilizationRate => totalSize / maxSize;
  double get expirationRate => totalSize > 0 ? expiredCount / totalSize : 0.0;

  @override
  String toString() {
    return 'CacheStats('
        'totalSize: $totalSize, '
        'maxSize: $maxSize, '
        'expiredCount: $expiredCount, '
        'utilizationRate: ${(utilizationRate * 100).toStringAsFixed(1)}%, '
        'expirationRate: ${(expirationRate * 100).toStringAsFixed(1)}%, '
        'averageAge: $averageAge'
        ')';
  }
}