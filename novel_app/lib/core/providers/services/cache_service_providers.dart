/// Cache Service Providers
///
/// 此文件定义所有缓存相关服务的 Provider。
///
/// **功能**:
/// - 通用图片缓存管理器
///
/// **依赖**:
/// - database_providers.dart - 数据库服务
/// - network_service_providers.dart - 网络服务
///
/// **相关 Providers**:
/// - [network_service_providers.dart] - 网络相关 Providers
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../utils/image_cache_manager.dart';
import 'network_service_providers.dart';

part 'cache_service_providers.g.dart';

/// ImageCacheManager Provider
///
/// 提供全局图片缓存管理器实例，用于管理插图图片的缓存和生命周期。
///
/// **功能**:
/// - 图片内存缓存和磁盘缓存
/// - 预加载和批量缓存
/// - 缓存有效期管理
/// - LRU 缓存策略
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API服务
///
/// **使用示例**:
/// ```dart
/// final imageCacheManager = ref.read(imageCacheManagerProvider);
/// final imageBytes = await imageCacheManager.getImage(filename);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁
/// - 缓存存储是静态的，所有实例共享同一缓存
/// - 通过依赖注入 ApiServiceWrapper，便于测试
@Riverpod(keepAlive: true)
ImageCacheManager imageCacheManager(Ref ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  return ImageCacheManager(apiService: apiService);
}
