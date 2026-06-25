// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$difyServiceHash() => r'78f6e6b1bc96ec7ec0bc13dd3589082f9151713a';

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
/// Copied from [difyService].
@ProviderFor(difyService)
final difyServiceProvider = Provider<DifyService>.internal(
  difyService,
  name: r'difyServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$difyServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DifyServiceRef = ProviderRef<DifyService>;
String _$chapterHistoryServiceHash() =>
    r'7f719fe06e7bbd9f97289185865e79613594a29e';

/// CharacterCardService 已删除，相关 provider 已移除。
/// ChapterHistoryService Provider
///
/// 提供章节历史服务实例，用于获取历史章节内容（AI生成上下文）。
///
/// **功能**:
/// - 获取历史章节内容
/// - 统一历史章节加载逻辑
/// - 支持缓存和 Headless WebView 获取
///
/// **依赖**:
/// - [chapterRepositoryProvider] - 章节数据访问
/// - [headlessWebViewContentServiceProvider] - Headless WebView 内容服务
///
/// **使用示例**:
/// ```dart
/// final historyService = ref.watch(chapterHistoryServiceProvider);
/// final historyContent = await historyService.fetchHistoryChaptersContent(
///   chapters: widget.chapters,
///   currentChapter: widget.currentChapter,
///   maxHistoryCount: 2,
/// );
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 优先使用缓存，缓存未命中时走 Headless WebView
///
/// Copied from [chapterHistoryService].
@ProviderFor(chapterHistoryService)
final chapterHistoryServiceProvider =
    AutoDisposeProvider<ChapterHistoryService>.internal(
  chapterHistoryService,
  name: r'chapterHistoryServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterHistoryServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChapterHistoryServiceRef
    = AutoDisposeProviderRef<ChapterHistoryService>;
String _$invalidMarkupCleanerHash() =>
    r'91250692eab8f3441876c0c0d227dfb08eeb8d6e';

/// InvalidMarkupCleaner Provider
///
/// 提供无效媒体标记清理服务实例，用于清理章节内容中的无效标记。
///
/// **功能**:
/// - 检测无效媒体标记（插图、视频等）
/// - 自动清理无效标记
/// - 验证标记在数据库中是否存在
///
/// **依赖**:
/// - [chapterRepositoryProvider] - 章节数据访问
/// - [illustrationRepositoryProvider] - 插图数据访问
///
/// **使用示例**:
/// ```dart
/// final cleaner = ref.watch(invalidMarkupCleanerProvider);
/// final cleanedContent = await cleaner.cleanInvalidMarkups(chapterContent);
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每次使用时创建新实例
/// - 清理失败时返回原内容，避免破坏章节内容
///
/// Copied from [invalidMarkupCleaner].
@ProviderFor(invalidMarkupCleaner)
final invalidMarkupCleanerProvider =
    AutoDisposeProvider<InvalidMarkupCleaner>.internal(
  invalidMarkupCleaner,
  name: r'invalidMarkupCleanerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$invalidMarkupCleanerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef InvalidMarkupCleanerRef = AutoDisposeProviderRef<InvalidMarkupCleaner>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
