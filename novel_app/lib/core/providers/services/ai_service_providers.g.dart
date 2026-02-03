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
String _$characterCardServiceHash() =>
    r'828f0c7a640794330fa6c941f600abce0c23c7c8';

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
/// - [characterRepositoryProvider] - 角色数据访问
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
/// Copied from [characterCardService].
@ProviderFor(characterCardService)
final characterCardServiceProvider =
    AutoDisposeProvider<CharacterCardService>.internal(
  characterCardService,
  name: r'characterCardServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterCardServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterCardServiceRef = AutoDisposeProviderRef<CharacterCardService>;
String _$outlineServiceHash() => r'b5fafecb21831f6a172511c4aec65c5318c19c5c';

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
/// Copied from [outlineService].
@ProviderFor(outlineService)
final outlineServiceProvider = AutoDisposeProvider<OutlineService>.internal(
  outlineService,
  name: r'outlineServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$outlineServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OutlineServiceRef = AutoDisposeProviderRef<OutlineService>;
String _$chapterHistoryServiceHash() =>
    r'70f279098bfb6a53723cfc080a7cc4c498f3c808';

/// ChapterHistoryService Provider
///
/// 提供章节历史服务实例，用于获取历史章节内容（AI生成上下文）。
///
/// **功能**:
/// - 获取历史章节内容
/// - 统一历史章节加载逻辑
/// - 支持缓存和API获取
///
/// **依赖**:
/// - [chapterRepositoryProvider] - 章节数据访问
/// - [apiServiceWrapperProvider] - API服务
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
/// - 优先使用缓存，缓存未命中时从API获取
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
String _$ttsPlayerServiceHash() => r'b06c4d1c1a7a7a5d770678dd6ee2332e0ba57052';

/// TtsPlayerService Provider
///
/// 提供TTS播放器服务实例，管理TTS播放状态、章节切换和进度保存。
///
/// **功能**:
/// - TTS播放控制（播放、暂停、停止）
/// - 章节切换和段落导航
/// - 播放进度保存和恢复
/// - 定时播放功能
///
/// **依赖**:
/// - [databaseServiceProvider] - 数据库访问
/// - [apiServiceWrapperProvider] - API服务
///
/// **使用示例**:
/// ```dart
/// final playerService = ref.watch(ttsPlayerServiceProvider);
/// await playerService.initializeWithNovel(
///   novel: novel,
///   chapters: chapters,
///   startChapter: startChapter,
/// );
/// await playerService.play();
/// ```
///
/// **注意事项**:
/// - 不使用 `keepAlive`，每个播放器实例独立
/// - 需要正确调用 dispose() 释放资源
/// - 播放器状态通过 ChangeNotifier 通知
///
/// Copied from [ttsPlayerService].
@ProviderFor(ttsPlayerService)
final ttsPlayerServiceProvider = AutoDisposeProvider<TtsPlayerService>.internal(
  ttsPlayerService,
  name: r'ttsPlayerServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ttsPlayerServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TtsPlayerServiceRef = AutoDisposeProviderRef<TtsPlayerService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
