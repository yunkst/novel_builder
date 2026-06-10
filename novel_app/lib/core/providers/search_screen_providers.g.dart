// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_screen_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchScreenNotifierHash() =>
    r'97bb7d1fde7840814a123b45794e166df14883b0';

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
    r'dd1a6a65d657bc54382f6004ad93fc2bbf57718c';

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
