/// Sync Service Providers
///
/// 此文件定义所有同步相关服务的 Provider。
///
/// **功能**:
/// - 小说同步服务（上传/下载/列表）
///
/// **依赖**:
/// - network_service_providers.dart - API服务
/// - repository_providers.dart - 数据仓库
///
/// **相关 Providers**:
/// - [network_service_providers.dart] - 网络 相关 Providers
/// - [repository_providers.dart] - Repository 相关 Providers
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../../services/novel_sync_service.dart';
import 'network_service_providers.dart';
import '../repository_providers.dart';

part 'sync_service_providers.g.dart';

/// NovelSyncService Provider
///
/// 提供小说同步服务实例，负责小说数据的上传、下载和列表查询。
///
/// **功能**:
/// - 上传小说数据到服务器
/// - 从服务器下载小说数据
/// - 获取已同步小说列表
/// - 删除服务器上的同步数据
///
/// **依赖**:
/// - [apiServiceWrapperProvider] - API服务包装器
/// - [novelExportRepositoryProvider] - 小说导出Repository
///
/// **使用示例**:
/// ```dart
/// final syncService = ref.watch(novelSyncServiceProvider);
///
/// // 上传小说
/// final result = await syncService.uploadNovel(novel);
/// if (result.success) {
///   print('上传成功: ${result.data}');
/// }
///
/// // 下载小说
/// final result = await syncService.downloadNovel(novel);
/// if (result.success) {
///   print('下载成功: ${result.data?['statistics']}');
/// }
///
/// // 获取已同步列表
/// final syncedList = await syncService.listSyncedNovels();
/// for (final info in syncedList) {
///   print('${info.title} - 版本: ${info.syncVersion}');
/// }
/// ```
///
/// **注意事项**:
/// - 使用 `keepAlive: true` 确保实例不会被销毁（单例模式）
/// - 上传/下载操作是异步的
/// - 需要配置有效的 API Token 才能正常工作
@Riverpod(keepAlive: true)
NovelSyncService novelSyncService(Ref ref) {
  final apiService = ref.watch(apiServiceWrapperProvider);
  final exportRepository = ref.watch(novelExportRepositoryProvider);
  final novelRepository = ref.watch(novelRepositoryProvider);

  return NovelSyncService(
    apiServiceWrapper: apiService,
    exportRepository: exportRepository,
    novelRepository: novelRepository,
  );
}