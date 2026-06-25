/// AI Service Providers
///
/// 此文件定义所有AI相关服务的 Provider。
///
/// **功能**:
/// - Dify AI内容生成服务
/// - 章节历史服务
/// - 无效标记清理服务
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
import '../../../services/chapter_history_service.dart';
import '../../../services/invalid_markup_cleaner.dart';
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
@riverpod
ChapterHistoryService chapterHistoryService(Ref ref) {
  final chapterRepository = ref.watch(chapterRepositoryProvider);
  final headlessService = ref.watch(headlessWebViewContentServiceProvider);
  return ChapterHistoryService(
    chapterRepo: chapterRepository,
    headlessService: headlessService,
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
