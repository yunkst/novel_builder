// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookshelf_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bookshelfNovelsHash() => r'52d6085197e593b58b329fea20b9413db29a0969';

/// 书架小说列表
///
/// 根据当前书架ID异步加载小说列表
///
/// Copied from [bookshelfNovels].
@ProviderFor(bookshelfNovels)
final bookshelfNovelsProvider = AutoDisposeFutureProvider<List<Novel>>.internal(
  bookshelfNovels,
  name: r'bookshelfNovelsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bookshelfNovelsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BookshelfNovelsRef = AutoDisposeFutureProviderRef<List<Novel>>;
String _$preloadProgressHash() => r'b7afde9f0050f5443f1d55a6db329a6a246f26dc';

/// 预加载进度流
///
/// 监听预加载服务的进度更新
///
/// Copied from [preloadProgress].
@ProviderFor(preloadProgress)
final preloadProgressProvider =
    AutoDisposeStreamProvider<Map<String, Map<String, int>>>.internal(
  preloadProgress,
  name: r'preloadProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preloadProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PreloadProgressRef
    = AutoDisposeStreamProviderRef<Map<String, Map<String, int>>>;
String _$currentBookshelfIdHash() =>
    r'6ba5ab5f32450d1ab319b8fb2b0aec326a441448';

/// 当前选中的书架ID
///
/// 默认值为 1（"全部小说"书架）
///
/// Copied from [CurrentBookshelfId].
@ProviderFor(CurrentBookshelfId)
final currentBookshelfIdProvider =
    AutoDisposeNotifierProvider<CurrentBookshelfId, int>.internal(
  CurrentBookshelfId.new,
  name: r'currentBookshelfIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentBookshelfIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentBookshelfId = AutoDisposeNotifier<int>;
String _$preloadProgressMapHash() =>
    r'372034ccd7fbc68485a7266bc56360e643315c20';

/// 合并的预加载进度
///
/// 将所有进度更新合并到一个 Map 中
/// 使用 StateProvider 在 UI 中方便地访问
///
/// Copied from [PreloadProgressMap].
@ProviderFor(PreloadProgressMap)
final preloadProgressMapProvider = AutoDisposeNotifierProvider<
    PreloadProgressMap, Map<String, Map<String, int>>>.internal(
  PreloadProgressMap.new,
  name: r'preloadProgressMapProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preloadProgressMapHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PreloadProgressMap
    = AutoDisposeNotifier<Map<String, Map<String, int>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
