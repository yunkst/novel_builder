/// AI Service Providers
///
/// 此文件定义所有AI相关服务的 Provider。
///
/// **功能**:
/// - 章节生成服务（本地 LLM Provider 流式调用）
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
import '../../../services/llm_config_service.dart';
import '../database_providers.dart';

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
