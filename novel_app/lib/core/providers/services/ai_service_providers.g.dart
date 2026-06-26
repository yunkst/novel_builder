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
String _$llmConfigServiceHash() => r'0c3a3e6b43fe97db8dec09a97d5f304ea84055aa';

/// InvalidMarkupCleaner Provider 已删除（无任何调用方，清理逻辑现由 ChapterRepository 内联处理）。
/// LlmConfigService Provider
///
/// 提供全局 LLM 配置服务实例，用于统一管理 LLM 配置序列。
///
/// **功能**:
/// - 获取/设置激活配置（全局 + 场景级）
/// - CRUD 配置
/// - 旧配置迁移
/// - 构建 LlmProvider 配置
///
/// **依赖**:
/// - [llmConfigRepositoryProvider] - LLM 配置数据访问
///
/// Copied from [llmConfigService].
@ProviderFor(llmConfigService)
final llmConfigServiceProvider = Provider<LlmConfigService>.internal(
  llmConfigService,
  name: r'llmConfigServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$llmConfigServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LlmConfigServiceRef = ProviderRef<LlmConfigService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
