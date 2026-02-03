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
import '../../../services/api_service_wrapper.dart';
import '../../../services/preload_service.dart';
import '../../../services/scene_illustration_service.dart';
import '../repository_providers.dart';

part 'network_service_providers.g.dart';

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
/// - [preferencesServiceProvider] - 用于读取 API 配置
///
/// **使用示例**:
/// ```dart
/// final apiService = ref.watch(apiServiceWrapperProvider);
/// await apiService.init();
/// final novels = await apiService.searchNovels('keyword');
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要先调用 `init()` 方法初始化
/// - 内部已经是单例模式，Provider 提供统一访问方式
@Riverpod(keepAlive: true)
ApiServiceWrapper apiServiceWrapper(Ref ref) {
  // ApiServiceWrapper 内部已经是单例模式
  // 这里通过 Provider 提供统一的访问方式
  return ApiServiceWrapper();
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
/// - 无（独立服务）
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
/// await preloadService.preloadNovel(novelUrl);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 预加载在后台异步执行
/// - 支持通过 progressStream 监听进度
@Riverpod(keepAlive: true)
PreloadService preloadService(Ref ref) {
  return PreloadService();
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
