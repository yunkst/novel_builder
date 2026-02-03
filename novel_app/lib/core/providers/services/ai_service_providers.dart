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
/// - network_service_providers.dart - 网络服务
///
/// **相关 Providers**:
/// - [database_service_providers.dart] - 数据库相关 Providers
/// - [network_service_providers.dart] - 网络相关 Providers
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../services/dify_service.dart';
import '../../../services/character_card_service.dart';
import '../../../services/outline_service.dart';
import '../../../services/chapter_history_service.dart';
import '../../../services/invalid_markup_cleaner.dart';
import '../../../services/tts_player_service.dart';
import '../database_providers.dart';
import 'network_service_providers.dart';

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
  final outlineRepository = ref.watch(outlineRepositoryProvider);
  return OutlineService(outlineRepo: outlineRepository);
}

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
@riverpod
ChapterHistoryService chapterHistoryService(Ref ref) {
  final chapterRepository = ref.watch(chapterRepositoryProvider);
  final apiService = ref.watch(apiServiceWrapperProvider);
  return ChapterHistoryService(
    chapterRepo: chapterRepository,
    apiService: apiService,
  );
}

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
@riverpod
InvalidMarkupCleaner invalidMarkupCleaner(Ref ref) {
  final chapterRepository = ref.watch(chapterRepositoryProvider);
  final illustrationRepository = ref.watch(illustrationRepositoryProvider);
  return InvalidMarkupCleaner(
    chapterRepo: chapterRepository,
    illustrationRepo: illustrationRepository,
  );
}

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
@riverpod
TtsPlayerService ttsPlayerService(Ref ref) {
  final chapterRepository = ref.watch(chapterRepositoryProvider);
  final apiService = ref.watch(apiServiceWrapperProvider);
  return TtsPlayerService(
    chapterRepository: chapterRepository,
    apiService: apiService,
  );
}
