// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_screen_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$readerSettingsServiceHash() =>
    r'28ded929d03ad72863e47350e2f2ef65bf67915a';

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
    r'b9fd020570d0ff30945bde7fd25bff0a69a09954';

/// NovelContextBuilder Provider
///
/// 提供小说上下文构建服务实例（单例）
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
String _$characterCardServiceHash() =>
    r'a89d01b01432222a245f1dff623e39c78f6bf510';

/// CharacterCardService Provider
///
/// 提供角色卡服务实例
/// 注意：这个服务每次访问都创建新实例，因为它的使用场景是临时性的
///
/// Copied from [characterCardService].
@ProviderFor(characterCardService)
final characterCardServiceProvider =
    AutoDisposeProvider<CharacterCardService>.internal(
  characterCardService,
  name: r'characterCardServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterCardServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterCardServiceRef = AutoDisposeProviderRef<CharacterCardService>;
String _$preloadServiceHash() => r'884948409649900fa2fde495dc06b95f41bafe20';

/// PreloadService Provider
///
/// 提供预加载服务实例（单例）
///
/// Copied from [preloadService].
@ProviderFor(preloadService)
final preloadServiceProvider = AutoDisposeProvider<PreloadService>.internal(
  preloadService,
  name: r'preloadServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preloadServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PreloadServiceRef = AutoDisposeProviderRef<PreloadService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
