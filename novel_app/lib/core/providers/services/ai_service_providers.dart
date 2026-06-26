/// AI Service Providers
///
/// 此文件定义所有AI相关服务的 Provider。
///
/// **功能**:
/// - 章节生成服务（本地 LLM Provider 流式调用）
/// - 章节历史服务
/// - LLM 配置管理
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
import '../../../services/llm_config_service.dart';
import '../database_providers.dart';
import 'network_service_providers.dart';

part 'ai_service_providers.g.dart';

/// 章节生成服务 Provider
///
/// 提供全局章节生成服务实例，用于 AI 新建章节和大纲细纲的流式生成。
/// 内部委托给本地 LLM Provider（不再依赖远程 Dify）。
///
/// **功能**:
/// - 流式 AI 章节生成
/// - 大纲细纲流式生成
///
/// **依赖**:
/// - [llmConfigServiceProvider] - LLM 配置（通过 DifyService → DifyWorkflowService → AiServiceFactory）
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 需要在设置中配置 LLM API URL 和 Key
@Riverpod(keepAlive: true)
DifyService difyService(Ref ref) {
  return DifyService(ref: ref);
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
@Riverpod(keepAlive: true)
LlmConfigService llmConfigService(Ref ref) {
  return LlmConfigService(ref);
}
