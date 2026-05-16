// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$novelSyncServiceHash() => r'fe21a47880410a75e20ff0593a2258841efc34ae';

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
///
/// Copied from [novelSyncService].
@ProviderFor(novelSyncService)
final novelSyncServiceProvider = Provider<NovelSyncService>.internal(
  novelSyncService,
  name: r'novelSyncServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$novelSyncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NovelSyncServiceRef = ProviderRef<NovelSyncService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
