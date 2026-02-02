/// Riverpod Reader Screen Providers
///
/// 此文件定义 ReaderScreen 相关的所有 Provider
/// 包括设置服务、内容状态、交互状态等
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/reader_settings_service.dart';
import '../../services/novel_context_service.dart';
import '../../services/character_card_service.dart';
import '../../services/preload_service.dart';

part 'reader_screen_providers.g.dart';

/// ReaderSettingsService Provider
///
/// 提供阅读器设置服务实例（单例）
/// 负责字体大小、滚动速度等设置的持久化
@riverpod
ReaderSettingsService readerSettingsService(ReaderSettingsServiceRef ref) {
  return ReaderSettingsService.instance;
}

/// NovelContextBuilder Provider
///
/// 提供小说上下文构建服务实例（单例）
@riverpod
NovelContextBuilder novelContextBuilder(NovelContextBuilderRef ref) {
  return NovelContextBuilder();
}

/// CharacterCardService Provider
///
/// 提供角色卡服务实例
/// 注意：这个服务每次访问都创建新实例，因为它的使用场景是临时性的
@riverpod
CharacterCardService characterCardService(CharacterCardServiceRef ref) {
  return CharacterCardService();
}

/// PreloadService Provider
///
/// 提供预加载服务实例（单例）
@riverpod
PreloadService preloadService(PreloadServiceRef ref) {
  return PreloadService();
}
