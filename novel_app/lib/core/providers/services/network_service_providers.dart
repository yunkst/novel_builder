/// Network Service Providers
///
/// 此文件定义所有网络相关服务的 Provider。
///
/// **功能**:
/// - API服务包装器
/// - 预加载服务
/// - 场景插图服务
///
/// **依赖**:
/// - repository_providers.dart - 数据仓库
///
/// **相关 Providers**:
/// - [repository_providers.dart] - Repository 相关 Providers
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';
import '../../../services/api_service_wrapper.dart';
import '../../../services/preload_service.dart';
import '../../../services/scene_illustration_service.dart';
import '../../../services/scene_illustration_cache_service.dart';
import '../../../repositories/chapter_repository.dart';
import '../repository_providers.dart';
import '../../../services/logger_service.dart';

part 'network_service_providers.g.dart';

/// Dio Provider
///
/// 提供全局统一的 HTTP 客户端实例。
///
/// **功能**:
/// - 统一配置超时时间、连接池
/// - 添加日志拦截器
/// - 优化HTTP连接管理
///
/// **配置**:
/// - 连接超时: 10秒
/// - 接收超时: 90秒
/// - 发送超时: 30秒
/// - 最大并发连接: 20/主机
/// - 空闲超时: 60秒
///
/// **使用示例**:
/// ```dart
/// final dio = ref.watch(dioProvider);
/// final response = await dio.get('/api/endpoint');
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 自动添加日志拦截器（调试模式）
/// - 已优化的连接池配置，避免资源耗尽
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 90),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      // CORS headers for web requests
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers':
          'Content-Type, Authorization, X-API-TOKEN',
    },
  ));

  // 配置优化的HttpClientAdapter
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      // 优化连接池配置：减少连接数避免资源耗尽
      client.maxConnectionsPerHost = 20;
      // 设置连接空闲超时，避免长时间占用连接
      client.idleTimeout = const Duration(seconds: 60);
      // 设置连接超时
      client.connectionTimeout = const Duration(seconds: 15);
      return client;
    },
  );

  // 添加日志拦截器
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: false, // 减少日志输出
    logPrint: (obj) => LoggerService.instance.d(
      '[Dio] $obj',
      category: LogCategory.network,
    ),
  ));

  return dio;
}

/// ApiServiceWrapper Provider
///
/// 提供全局 API 服务实例，负责与后端服务器通信。
///
/// **功能**:
/// - 封装后端 API 调用
/// - 自动初始化和配置
/// - 错误处理和重试机制
/// - 支持 OpenAPI 生成的类型安全接口
///
/// **依赖**:
/// - [dioProvider] - HTTP 客户端
///
/// **使用示例**:
/// ```dart
/// // 方式1: 直接使用（已自动初始化）
/// final apiService = ref.watch(apiServiceWrapperProvider);
/// final novels = await apiService.searchNovels('keyword');
///
/// // 方式2: 仅获取 Future（异步场景）
/// final initFuture = ref.watch(apiServiceWrapperInitProvider);
/// await initFuture;
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁
/// - Provider 会自动调用 `init()`，无需手动初始化
/// - 通过依赖注入创建实例，便于测试
@Riverpod(keepAlive: true)
ApiServiceWrapper apiServiceWrapper(Ref ref) {
  // 通过依赖注入创建 ApiServiceWrapper 实例
  // 注入 Dio 实例，统一管理 HTTP 客户端
  final dio = ref.watch(dioProvider);
  final apiService = ApiServiceWrapper(null, dio);

  // 自动初始化（异步，不阻塞返回）
  // 使用 onAddListener 的方式确保初始化只执行一次
  ref.onDispose(() {
    // 清理资源（如果需要）
  });

  // 异步初始化，不阻塞 Provider 返回
  _initializeApiService(apiService);

  return apiService;
}

/// ApiServiceWrapper 初始化 Provider
///
/// 提供 ApiServiceWrapper 的初始化 Future，用于需要等待初始化的场景。
///
/// **使用示例**:
/// ```dart
/// // 在应用启动时等待初始化
/// final initFuture = ref.watch(apiServiceWrapperInitProvider);
/// await initFuture;
/// ```
@Riverpod(keepAlive: true)
Future<void> apiServiceWrapperInit(Ref ref) async {
  final apiService = ref.watch(apiServiceWrapperProvider);
  await apiService.init();
}

/// 异步初始化 ApiServiceWrapper
///
/// 这个函数会在后台异步执行初始化，不阻塞 Provider 返回。
Future<void> _initializeApiService(ApiServiceWrapper apiService) async {
  try {
    await apiService.init();
    LoggerService.instance.i(
      'ApiServiceWrapper 自动初始化成功',
      category: LogCategory.network,
      tags: ['provider', 'init'],
    );
  } catch (e) {
    LoggerService.instance.e(
      'ApiServiceWrapper 自动初始化失败: $e',
      category: LogCategory.network,
      tags: ['provider', 'init', 'error'],
    );
    // 不抛出异常，允许应用继续运行
    // 实际使用时，apiService 会通过 _ensureInitialized() 检查并重新初始化
  }
}

/// PreloadService Provider
///
/// 提供全局预加载服务实例，用于章节内容的预加载和缓存管理。
///
/// **功能**:
/// - 后台预加载章节内容
/// - 进度流式更新
/// - 并发控制
/// - 任务队列管理
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API 服务
/// - [chapterRepositoryProvider] - 章节数据访问
///
/// **使用示例**:
/// ```dart
/// final preloadService = ref.watch(preloadServiceProvider);
///
/// // 监听预加载进度
/// ref.listen(preloadProgressProvider, (previous, next) {
///   print('预加载进度: ${next.cachedChapters}/${next.totalChapters}');
/// });
///
/// // 开始预加载
/// await preloadService.enqueueTasks(
///   novelUrl: novelUrl,
///   novelTitle: novelTitle,
///   chapterUrls: chapterUrls,
///   currentIndex: currentIndex,
/// );
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 预加载在后台异步执行
/// - 支持通过 progressStream 监听进度
@Riverpod(keepAlive: true)
PreloadService preloadService(Ref ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  final chapterRepository = ref.watch(chapterRepositoryProvider);

  // 类型转换：IChapterRepository -> ChapterRepository
  // 因为 PreloadService 需要具体的 ChapterRepository 实现
  // ignore: unnecessary_cast
  final repository = chapterRepository as ChapterRepository;

  return PreloadService(
    apiService: apiService,
    chapterRepository: repository,
  );
}

/// SceneIllustrationService Provider
///
/// 提供场景插图服务实例，负责场景图片的生成和管理。
///
/// **功能**:
/// - 场景插图生成
/// - 插图缓存管理
/// - 图片 URL 处理
///
/// **依赖**:
/// - [chapterRepositoryProvider] - 章节数据访问
/// - [illustrationRepositoryProvider] - 插图数据访问
/// - [apiServiceWrapperProvider] - API 服务
///
/// **使用示例**:
/// ```dart
/// final illustrationService = ref.watch(sceneIllustrationServiceProvider);
/// final imageUrl = await illustrationService.generateIllustration(scene);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 插图生成是异步操作
@riverpod
SceneIllustrationService sceneIllustrationService(Ref ref) {
  final chapterRepository = ref.watch(chapterRepositoryProvider);
  final illustrationRepository = ref.watch(illustrationRepositoryProvider);
  final apiService = ref.watch(apiServiceWrapperProvider);
  return SceneIllustrationService(
    chapterRepository: chapterRepository,
    illustrationRepository: illustrationRepository,
    apiService: apiService,
  );
}

/// SceneIllustrationCacheService Provider
///
/// 提供场景插图缓存服务实例，管理场景插图的本地缓存。
///
/// **功能**:
/// - 图片内存缓存和磁盘缓存
/// - 预加载和批量缓存
/// - 缓存有效期管理
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API服务
///
/// **使用示例**:
/// ```dart
/// final cacheService = ref.read(sceneIllustrationCacheServiceProvider);
/// await cacheService.init();
/// final imageBytes = await cacheService.getImageBytes(filename);
/// ```
@Riverpod(keepAlive: true)
SceneIllustrationCacheService sceneIllustrationCacheService(Ref ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  return SceneIllustrationCacheService(apiService: apiService);
}
