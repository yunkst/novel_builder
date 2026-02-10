// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_screen_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$readerSettingsServiceHash() =>
    r'31222f7d9fbe916f42bd1062231ff481ce24cd34';

/// ReaderSettingsService Provider
///
/// 提供阅读器设置服务实例（单例）
/// 负责字体大小、滚动速度等设置的持久化
///
/// Copied from [readerSettingsService].
@ProviderFor(readerSettingsService)
final readerSettingsServiceProvider =
    AutoDisposeProvider<ReaderSettingsService>.internal(
  readerSettingsService,
  name: r'readerSettingsServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$readerSettingsServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReaderSettingsServiceRef
    = AutoDisposeProviderRef<ReaderSettingsService>;
String _$novelContextBuilderHash() =>
    r'1b52c461768c7e5914b0ba58fa14af7319eea280';

/// NovelContextBuilder Provider
///
/// 提供小说上下文构建服务实例
/// 依赖NovelRepository进行背景设定等数据获取
///
/// Copied from [novelContextBuilder].
@ProviderFor(novelContextBuilder)
final novelContextBuilderProvider =
    AutoDisposeProvider<NovelContextBuilder>.internal(
  novelContextBuilder,
  name: r'novelContextBuilderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$novelContextBuilderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NovelContextBuilderRef = AutoDisposeProviderRef<NovelContextBuilder>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
