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
    r'eb8bd71ecee934ad42cf3e2e470fcc9b5ee09407';

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
String _$characterExtractionServiceHash() =>
    r'0bcd5b3902fa1b6ffa5e6d880dca313b6cb11a77';

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
/// Copied from [characterExtractionService].
@ProviderFor(characterExtractionService)
final characterExtractionServiceProvider =
    Provider<CharacterExtractionService>.internal(
  characterExtractionService,
  name: r'characterExtractionServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterExtractionServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterExtractionServiceRef = ProviderRef<CharacterExtractionService>;
String _$outlineServiceHash() => r'acf4a41da39f6680ca29292c9f25f4216ff08ae6';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
