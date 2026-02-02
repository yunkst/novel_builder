/// Riverpod Service Providers
///
/// 此文件定义所有服务层的 Provider，使用 @riverpod 注解自动生成代码。
///
/// **功能**:
/// - 提供全局服务实例的统一访问入口
/// - 管理服务之间的依赖关系
/// - 支持服务的生命周期管理
/// - 实现依赖注入和服务定位模式
///
/// **依赖**:
/// - 无（这是最底层的 Provider 定义）
///
/// **使用示例**:
/// ```dart
/// // 在 ConsumerWidget 中监听服务
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final logger = ref.watch(loggerServiceProvider);
///     logger.info('Widget 已构建');
///     return Container();
///   }
/// }
///
/// // 在回调中读取服务（不建立响应式依赖）
/// onPressed: () {
///   final service = ref.read(loggerServiceProvider);
///   service.doSomething();
/// }
/// ```
///
/// **注意事项**:
/// - 大部分服务使用 `keepAlive: true` 确保实例不会被销毁
/// - 部分服务保留了单例模式，通过 `.instance` 访问（向后兼容）
/// - 运行代码生成: `dart run build_runner build --delete-conflicting-outputs`
///
/// **相关 Providers**:
/// - [database_providers.dart] - 数据库和 Repository Providers
/// - [theme_provider.dart] - 主题管理 Providers
/// - [bookshelf_providers.dart] - 书架功能 Providers
/// - [chapter_list_providers.dart] - 章节列表 Providers
/// - [search_screen_providers.dart] - 搜索功能 Providers
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/logger_service.dart';
import '../../services/preferences_service.dart';
import '../../services/api_service_wrapper.dart';
import '../../services/dify_service.dart';
import '../../services/preload_service.dart';
import '../../services/chapter_service.dart';
import '../../services/scene_illustration_service.dart';
import '../../services/role_gallery_cache_service.dart';
import '../../services/character_avatar_sync_service.dart';
import '../../services/character_avatar_service.dart';
import '../../services/chapter_search_service.dart';
import '../../services/cache_search_service.dart';
import '../../services/character_card_service.dart';
import '../../services/character_extraction_service.dart';
import '../../services/outline_service.dart';
import '../../controllers/chapter_list/chapter_loader.dart';
import '../../controllers/chapter_list/chapter_action_handler.dart';
import '../../controllers/chapter_list/chapter_reorder_controller.dart';
import 'database_providers.dart';

part 'service_providers.g.dart';

/// LoggerService Provider
///
/// 提供全局日志服务实例，用于记录应用运行时的日志信息。
///
/// **功能**:
/// - 支持多级别日志（debug, info, warning, error）
/// - 支持日志分类和标签
/// - 持久化日志到本地文件
///
/// **依赖**:
/// - 无（单例服务）
///
/// **使用示例**:
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final logger = ref.watch(loggerServiceProvider);
///     logger.info('Widget 已构建');
///     return Container();
///   }
/// }
/// ```
///
/// **注意事项**:
/// - 使用 `LoggerService.instance` 单例模式
/// - 日志文件位于应用文档目录
/// - 支持异步日志写入
///
/// **相关 Providers**:
/// - [preferencesServiceProvider] - 用于读取日志配置
@riverpod
LoggerService loggerService(LoggerServiceRef ref) {
  return LoggerService.instance;
}

/// PreferencesService Provider
///
/// 提供全局 SharedPreferences 服务实例，用于存储用户偏好设置。
///
/// **功能**:
/// - 持久化键值对存储
/// - 支持多种数据类型（String、int、bool、double、List<String>等）
/// - 线程安全访问
///
/// **依赖**:
/// - 无（单例服务）
///
/// **使用示例**:
/// ```dart
/// final prefs = ref.watch(preferencesServiceProvider);
/// await prefs.setString('theme_mode', 'dark');
/// final themeMode = await prefs.getString('theme_mode');
/// ```
///
/// **注意事项**:
/// - 使用 `PreferencesService.instance` 单例模式
/// - 所有操作都是异步的
/// - 数据存储在本地 SharedPreferences
///
/// **相关 Providers**:
/// - [themeProvider] - 用于主题设置持久化
/// - [databaseServiceProvider] - 用于数据库配置
@riverpod
PreferencesService preferencesService(PreferencesServiceRef ref) {
  return PreferencesService.instance;
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
/// - [preferencesServiceProvider] - 用于读取 API 配置
///
/// **使用示例**:
/// ```dart
/// final apiService = ref.watch(apiServiceWrapperProvider);
/// await apiService.init();
/// final novels = await apiService.searchNovels(' keyword');
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要先调用 `init()` 方法初始化
/// - 内部已经是单例模式，Provider 提供统一访问方式
///
/// **相关 Providers**:
/// - [preferencesServiceProvider] - API 配置存储
/// - [chapterLoaderProvider] - 依赖此 Provider
@Riverpod(keepAlive: true)
ApiServiceWrapper apiServiceWrapper(ApiServiceWrapperRef ref) {
  // ApiServiceWrapper 内部已经是单例模式
  // 这里通过 Provider 提供统一的访问方式
  return ApiServiceWrapper();
}

/// DifyService Provider
///
/// 提供全局 Dify AI 服务实例，用于 AI 内容生成和流式响应。
///
/// **功能**:
/// - 流式 AI 响应处理
/// - 特写功能内容生成
/// - SSE 解析器支持
/// - 多轮对话管理
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final difyService = ref.watch(difyServiceProvider);
/// final stream = difyService.streamGenerate('提示词');
/// await for (final chunk in stream) {
///   print('收到: ${chunk.content}');
/// }
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要配置 Dify URL 和 Token
/// - 支持流式和阻塞两种响应模式
///
/// **相关 Providers**:
/// - [preferencesServiceProvider] - Dify 配置存储
@Riverpod(keepAlive: true)
DifyService difyService(DifyServiceRef ref) {
  return DifyService();
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
///
/// **相关 Providers**:
/// - [chapterLoaderProvider] - 章节加载
/// - [databaseServiceProvider] - 缓存存储
@Riverpod(keepAlive: true)
PreloadService preloadService(PreloadServiceRef ref) {
  return PreloadService();
}

/// ChapterService Provider
///
/// 提供章节服务实例，处理章节数据的业务逻辑。
///
/// **功能**:
/// - 章节 CRUD 操作
/// - 章节索引管理
/// - 用户插入章节保护
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final chapterService = ref.watch(chapterServiceProvider);
/// await chapterService.insertChapter(novelUrl, chapter);
/// final chapters = await chapterService.getChapters(novelUrl);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 依赖 DatabaseService，自动注入
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterLoaderProvider] - 章节加载器
@riverpod
ChapterService chapterService(ChapterServiceRef ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ChapterService(databaseService: databaseService);
}

/// ChapterLoader Provider
///
/// 提供章节加载器实例，负责从 API 和数据库加载章节数据。
///
/// **功能**:
/// - 从 API 获取章节列表
/// - 从数据库加载缓存章节
/// - 刷新章节列表
/// - 最后阅读位置管理
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API 服务
/// - [databaseServiceProvider] - 数据库服务
///
/// **使用示例**:
/// ```dart
/// final chapterLoader = ref.watch(chapterLoaderProvider);
/// await chapterLoader.initApi();
/// final chapters = await chapterLoader.loadChapters(novelUrl);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 需要先调用 `initApi()` 初始化
/// - 自动处理缓存和刷新逻辑
///
/// **相关 Providers**:
/// - [apiServiceWrapperProvider] - API 服务
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterActionHandlerProvider] - 章节操作
@riverpod
ChapterLoader chapterLoader(ChapterLoaderRef ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  return ChapterLoader(
    api: apiService,
    databaseService: databaseService,
  );
}

/// ChapterActionHandler Provider
///
/// 提供章节操作处理器实例，处理章节的增删改查操作。
///
/// **功能**:
/// - 章节缓存状态查询
/// - 章节删除
/// - 章节重排
/// - 批量操作
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库服务
///
/// **使用示例**:
/// ```dart
/// final handler = ref.watch(chapterActionHandlerProvider);
/// final isCached = await handler.isChapterCached(chapterUrl);
/// await handler.deleteChapter(chapterUrl);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 支持批量操作以提高性能
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterReorderControllerProvider] - 章节重排
@riverpod
ChapterActionHandler chapterActionHandler(ChapterActionHandlerRef ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ChapterActionHandler(
    databaseService: databaseService,
  );
}

/// ChapterReorderController Provider
///
/// 提供章节重排控制器实例，管理章节顺序调整。
///
/// **功能**:
/// - 章节拖拽重排
/// - 保存重排结果
/// - 验证重排合法性
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库服务
///
/// **使用示例**:
/// ```dart
/// final reorderController = ref.watch(chapterReorderControllerProvider);
/// final reordered = reorderController.onReorder(
///   oldIndex: 0,
///   newIndex: 2,
///   chapters: chapters,
/// );
/// await reorderController.saveReorderedChapters(novelUrl, reordered);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 保存操作会持久化到数据库
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库服务
/// - [chapterActionHandlerProvider] - 章节操作
@riverpod
ChapterReorderController chapterReorderController(
    ChapterReorderControllerRef ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ChapterReorderController(
    databaseService: databaseService,
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
/// - [databaseServiceProvider] - 数据库访问
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
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库访问
/// - [apiServiceWrapperProvider] - API 服务
@riverpod
SceneIllustrationService sceneIllustrationService(
    SceneIllustrationServiceRef ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final apiService = ref.watch(apiServiceWrapperProvider);
  return SceneIllustrationService(
    databaseService: databaseService,
    apiService: apiService,
  );
}

/// RoleGalleryCacheService Provider
///
/// 提供角色图集缓存服务实例，管理角色图片的缓存。
///
/// **功能**:
/// - 角色图片缓存
/// - 缓存清理
/// - 缓存大小管理
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final cacheService = ref.watch(roleGalleryCacheServiceProvider);
/// await cacheService.cacheRoleImage(roleId, imageUrl);
/// final cachedPath = cacheService.getCachedImagePath(roleId);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 缓存文件存储在应用缓存目录
///
/// **相关 Providers**:
/// - [characterAvatarServiceProvider] - 头像服务
@Riverpod(keepAlive: true)
RoleGalleryCacheService roleGalleryCacheService(
    RoleGalleryCacheServiceRef ref) {
  return RoleGalleryCacheService();
}

/// CharacterAvatarSyncService Provider
///
/// 提供角色头像同步服务实例，同步头像数据到多个来源。
///
/// **功能**:
/// - 头像数据同步
/// - 批量同步
/// - 同步状态跟踪
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final syncService = ref.watch(characterAvatarSyncServiceProvider);
/// await syncService.syncAvatar(characterId);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 同步操作是异步的
///
/// **相关 Providers**:
/// - [characterAvatarServiceProvider] - 头像服务
/// - [characterImageCacheServiceProvider] - 图片缓存
@Riverpod(keepAlive: true)
CharacterAvatarSyncService characterAvatarSyncService(
    CharacterAvatarSyncServiceRef ref) {
  return CharacterAvatarSyncService();
}

/// CharacterAvatarService Provider
///
/// 提供角色头像服务实例，处理角色头像的生成和管理。
///
/// **功能**:
/// - 头像生成
/// - 头像缓存
/// - 头像 URL 管理
///
/// **依赖**:
/// - 无（独立服务）
///
/// **使用示例**:
/// ```dart
/// final avatarService = ref.watch(characterAvatarServiceProvider);
/// final avatarUrl = await avatarService.generateAvatar(character);
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 头像生成是异步操作
///
/// **相关 Providers**:
/// - [characterAvatarSyncServiceProvider] - 同步服务
/// - [characterImageCacheServiceProvider] - 图片缓存
@Riverpod(keepAlive: true)
CharacterAvatarService characterAvatarService(CharacterAvatarServiceRef ref) {
  return CharacterAvatarService();
}

/// ChapterSearchService Provider
///
/// 提供章节搜索服务实例，支持章节内容的全文搜索。
///
/// **功能**:
/// - 章节内容搜索
/// - 搜索结果高亮
/// - 模糊搜索
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final searchService = ref.watch(chapterSearchServiceProvider);
/// final results = await searchService.searchInNovel(novelUrl, '关键词');
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 搜索操作是异步的
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库访问
/// - [cacheSearchServiceProvider] - 缓存搜索
@riverpod
ChapterSearchService chapterSearchService(ChapterSearchServiceRef ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return ChapterSearchService(databaseService: databaseService);
}

/// CacheSearchService Provider
///
/// 提供缓存搜索服务实例，支持缓存内容的搜索和分页。
///
/// **功能**:
/// - 缓存内容搜索
/// - 搜索结果分页
/// - 搜索建议
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final cacheSearch = ref.watch(cacheSearchServiceProvider);
/// final results = await cacheSearch.searchInCache(keyword: '关键词');
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 搜索操作是异步的
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库访问
/// - [chapterSearchServiceProvider] - 章节搜索
@riverpod
CacheSearchService cacheSearchService(CacheSearchServiceRef ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return CacheSearchService(databaseService: databaseService);
}

/// CharacterCardService Provider
///
/// 提供角色卡片服务实例，处理角色卡片的更新和管理。
///
/// **功能**:
/// - 角色卡片更新
/// - AI生成角色信息
/// - 角色信息保存
///
/// **依赖**:
/// - [difyServiceProvider] - Dify AI服务
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final cardService = ref.watch(characterCardServiceProvider);
/// await cardService.updateCharacterCards(
///   novel: novel,
///   chapterContent: content,
/// );
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - AI生成是异步操作
///
/// **相关 Providers**:
/// - [difyServiceProvider] - Dify AI服务
/// - [databaseServiceProvider] - 数据库访问
@riverpod
CharacterCardService characterCardService(CharacterCardServiceRef ref) {
  final difyService = ref.watch(difyServiceProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  return CharacterCardService(
    difyService: difyService,
    databaseService: databaseService,
  );
}

/// CharacterExtractionService Provider
///
/// 提供角色提取服务实例，从章节内容中提取角色相关信息。
///
/// **功能**:
/// - 角色名字搜索
/// - 章节内容匹配
/// - 上下文提取
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final extractionService = ref.watch(characterExtractionServiceProvider);
/// final matches = await extractionService.searchChaptersByName(
///   novelUrl: novelUrl,
///   names: ['张三', '李四'],
/// );
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 搜索操作是异步的
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库访问
@Riverpod(keepAlive: true)
CharacterExtractionService characterExtractionService(
    CharacterExtractionServiceRef ref) {
  return CharacterExtractionService();
}

/// OutlineService Provider
///
/// 提供大纲服务实例，处理小说大纲的管理和生成。
///
/// **功能**:
/// - 大纲CRUD操作
/// - 大纲AI生成
/// - 章节细纲生成
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
///
/// **使用示例**:
/// ```dart
/// final outlineService = ref.watch(outlineServiceProvider);
/// await outlineService.saveOutline(
///   novelUrl: novelUrl,
///   title: title,
///   content: content,
/// );
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - AI生成是异步操作
///
/// **相关 Providers**:
/// - [databaseServiceProvider] - 数据库访问
/// - [difyServiceProvider] - Dify AI服务
@riverpod
OutlineService outlineService(OutlineServiceRef ref) {
  return OutlineService();
}
