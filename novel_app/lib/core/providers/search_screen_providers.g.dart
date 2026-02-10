// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_screen_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchScreenNotifierHash() =>
    r'f2c6481390ecf441a7ad2aafeca13307efcdd8e6';

/// 搜索状态 Provider
///
/// 管理搜索结果和搜索状态
///
/// Copied from [SearchScreenNotifier].
@ProviderFor(SearchScreenNotifier)
final searchScreenNotifierProvider =
    AutoDisposeNotifierProvider<SearchScreenNotifier, SearchState>.internal(
  SearchScreenNotifier.new,
  name: r'searchScreenNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$searchScreenNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchScreenNotifier = AutoDisposeNotifier<SearchState>;
String _$sourceSitesNotifierHash() =>
    r'31854b48209f91848717186a32de0cb9bc83fdab';

/// 源站状态 Provider
///
/// 管理源站列表和筛选状态
///
/// Copied from [SourceSitesNotifier].
@ProviderFor(SourceSitesNotifier)
final sourceSitesNotifierProvider =
    AutoDisposeNotifierProvider<SourceSitesNotifier, SourceSitesState>.internal(
  SourceSitesNotifier.new,
  name: r'sourceSitesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sourceSitesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SourceSitesNotifier = AutoDisposeNotifier<SourceSitesState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
