import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../repositories/novel_repository.dart';
import '../repositories/chapter_repository.dart';
import '../cache/cache_manager.dart';
import '../../services/database_service.dart';
import '../../services/api_service_wrapper.dart';
import '../../services/dify_service.dart';
import '../../services/cache_manager.dart' as services;
import '../../data/repositories/novel_repository_impl.dart';
import '../../data/repositories/chapter_repository_impl.dart';
import 'api_service_provider.dart';

/// 全局服务定位器
final getIt = GetIt.instance;

/// 依赖注入配置
Future<void> configureDependencies() async {
  // 核心服务
  getIt.registerSingleton<DatabaseService>(DatabaseService());
  // 使用ApiServiceProvider确保整个应用使用同一个实例
  getIt.registerSingleton<ApiServiceWrapper>(ApiServiceProvider.instance);
  getIt.registerSingleton<DifyService>(DifyService());
  getIt.registerSingleton<services.CacheManager>(services.CacheManager());
  getIt.registerSingleton<CacheManager>(CacheManager());

  // Repository实现
  getIt.registerLazySingleton<NovelRepository>(
    () => NovelRepositoryImpl(
      databaseService: getIt<DatabaseService>(),
      apiService: getIt<ApiServiceWrapper>(),
    ),
  );

  getIt.registerLazySingleton<ChapterRepository>(
    () => ChapterRepositoryImpl(
      databaseService: getIt<DatabaseService>(),
      apiService: getIt<ApiServiceWrapper>(),
    ),
  );

  // 初始化API服务
  try {
    await ApiServiceProvider.initialize();
  } catch (e) {
    debugPrint('Failed to initialize API service: $e');
  }

  // Use Cases - 将在后续阶段实现
  // getIt.registerLazySingleton<LoadBookshelfUseCase>(
  //   () => LoadBookshelfUseCase(getIt<NovelRepository>()),
  // );

  // 更多用例注册...
}

/// 清理依赖
Future<void> resetDependencies() async {
  await getIt.reset();
}

/// 检查服务是否已注册
bool isRegistered<T extends Object>() {
  return getIt.isRegistered<T>();
}

/// 获取服务
T get<T extends Object>() {
  return getIt<T>();
}

/// 注册单例服务
void registerSingleton<T extends Object>(T instance) {
  getIt.registerSingleton<T>(instance);
}

/// 注册工厂服务
void registerFactory<T extends Object>(T Function() factoryFunc) {
  getIt.registerFactory<T>(factoryFunc);
}

/// 注册延迟单例
void registerLazySingleton<T extends Object>(T Function() factoryFunc) {
  getIt.registerLazySingleton<T>(factoryFunc);
}