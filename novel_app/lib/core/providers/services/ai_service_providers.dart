/// AI Service Providers
///
/// 此文件定义所有AI相关服务的 Provider。
///
/// **功能**:
/// - Dify AI内容生成服务
/// - 角色卡片AI生成服务
/// - 角色信息提取服务
/// - 大纲AI生成服务
///
/// **依赖**:
/// - database_providers.dart - 数据库服务
///
/// **相关 Providers**:
/// - [database_service_providers.dart] - 数据库相关 Providers
/// - [network_service_providers.dart] - 网络相关 Providers
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../services/dify_service.dart';
import '../../../services/character_card_service.dart';
import '../../../services/character_extraction_service.dart';
import '../../../services/outline_service.dart';
import '../database_providers.dart';

part 'ai_service_providers.g.dart';

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
@Riverpod(keepAlive: true)
DifyService difyService(Ref ref) {
  return DifyService();
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
@riverpod
CharacterCardService characterCardService(Ref ref) {
  final difyService = ref.watch(difyServiceProvider);
  final characterRepository = ref.watch(characterRepositoryProvider);
  return CharacterCardService(
    difyService: difyService,
    characterRepository: characterRepository,
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
@Riverpod(keepAlive: true)
CharacterExtractionService characterExtractionService(Ref ref) {
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
@riverpod
OutlineService outlineService(Ref ref) {
  return OutlineService();
}
