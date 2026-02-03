/// Riverpod Reader Screen Providers
///
/// 此文件定义 ReaderScreen 相关的所有 Provider
/// 包括设置服务、内容状态、交互状态等
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../services/reader_settings_service.dart';
import '../../services/novel_context_service.dart';
import '../../services/preload_service.dart';
import '../providers/database_providers.dart';

part 'reader_screen_providers.g.dart';

/// ReaderSettingsService Provider
///
/// 提供阅读器设置服务实例（单例）
/// 负责字体大小、滚动速度等设置的持久化
@riverpod
ReaderSettingsService readerSettingsService(Ref ref) {
  return ReaderSettingsService.instance;
}

/// NovelContextBuilder Provider
///
/// 提供小说上下文构建服务实例
/// 依赖NovelRepository进行背景设定等数据获取
@riverpod
NovelContextBuilder novelContextBuilder(Ref ref) {
  final novelRepository = ref.watch(novelRepositoryProvider);
  return NovelContextBuilder(novelRepository: novelRepository);
}

/// PreloadService Provider
///
/// 提供预加载服务实例（单例）
@riverpod
PreloadService preloadService(Ref ref) {
  return PreloadService();
}
