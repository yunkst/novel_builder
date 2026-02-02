// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_list_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentNovelHash() => r'8ddbbf4f395511b15997fd2bb1f21103426a6512';

/// ChapterListScreen 的 Novel 参数 Provider
///
/// 用于在屏幕中传递 novel 参数
///
/// Copied from [currentNovel].
@ProviderFor(currentNovel)
final currentNovelProvider = AutoDisposeProvider<Novel>.internal(
  currentNovel,
  name: r'currentNovelProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentNovelHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentNovelRef = AutoDisposeProviderRef<Novel>;
String _$preloadProgressHash() => r'd1c9cca352e5509c5eef53f9fd1b5ce43d588fd3';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 预加载进度监听 Provider
///
/// 监听 PreloadService 的进度更新
///
/// Copied from [preloadProgress].
@ProviderFor(preloadProgress)
const preloadProgressProvider = PreloadProgressFamily();

/// 预加载进度监听 Provider
///
/// 监听 PreloadService 的进度更新
///
/// Copied from [preloadProgress].
class PreloadProgressFamily extends Family<AsyncValue<PreloadProgressUpdate>> {
  /// 预加载进度监听 Provider
  ///
  /// 监听 PreloadService 的进度更新
  ///
  /// Copied from [preloadProgress].
  const PreloadProgressFamily();

  /// 预加载进度监听 Provider
  ///
  /// 监听 PreloadService 的进度更新
  ///
  /// Copied from [preloadProgress].
  PreloadProgressProvider call(
    Novel novel,
  ) {
    return PreloadProgressProvider(
      novel,
    );
  }

  @override
  PreloadProgressProvider getProviderOverride(
    covariant PreloadProgressProvider provider,
  ) {
    return call(
      provider.novel,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'preloadProgressProvider';
}

/// 预加载进度监听 Provider
///
/// 监听 PreloadService 的进度更新
///
/// Copied from [preloadProgress].
class PreloadProgressProvider
    extends AutoDisposeStreamProvider<PreloadProgressUpdate> {
  /// 预加载进度监听 Provider
  ///
  /// 监听 PreloadService 的进度更新
  ///
  /// Copied from [preloadProgress].
  PreloadProgressProvider(
    Novel novel,
  ) : this._internal(
          (ref) => preloadProgress(
            ref as PreloadProgressRef,
            novel,
          ),
          from: preloadProgressProvider,
          name: r'preloadProgressProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$preloadProgressHash,
          dependencies: PreloadProgressFamily._dependencies,
          allTransitiveDependencies:
              PreloadProgressFamily._allTransitiveDependencies,
          novel: novel,
        );

  PreloadProgressProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.novel,
  }) : super.internal();

  final Novel novel;

  @override
  Override overrideWith(
    Stream<PreloadProgressUpdate> Function(PreloadProgressRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PreloadProgressProvider._internal(
        (ref) => create(ref as PreloadProgressRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        novel: novel,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<PreloadProgressUpdate> createElement() {
    return _PreloadProgressProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PreloadProgressProvider && other.novel == novel;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, novel.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PreloadProgressRef
    on AutoDisposeStreamProviderRef<PreloadProgressUpdate> {
  /// The parameter `novel` of this provider.
  Novel get novel;
}

class _PreloadProgressProviderElement
    extends AutoDisposeStreamProviderElement<PreloadProgressUpdate>
    with PreloadProgressRef {
  _PreloadProgressProviderElement(super.provider);

  @override
  Novel get novel => (origin as PreloadProgressProvider).novel;
}

String _$chapterListHash() => r'2101635155a3746127314a9e39620816f1db4f3e';

abstract class _$ChapterList
    extends BuildlessAutoDisposeNotifier<ChapterListState> {
  late final Novel novel;

  ChapterListState build(
    Novel novel,
  );
}

/// ChapterListStateNotifier
///
/// 管理 ChapterListScreen 的状态
///
/// Copied from [ChapterList].
@ProviderFor(ChapterList)
const chapterListProvider = ChapterListFamily();

/// ChapterListStateNotifier
///
/// 管理 ChapterListScreen 的状态
///
/// Copied from [ChapterList].
class ChapterListFamily extends Family<ChapterListState> {
  /// ChapterListStateNotifier
  ///
  /// 管理 ChapterListScreen 的状态
  ///
  /// Copied from [ChapterList].
  const ChapterListFamily();

  /// ChapterListStateNotifier
  ///
  /// 管理 ChapterListScreen 的状态
  ///
  /// Copied from [ChapterList].
  ChapterListProvider call(
    Novel novel,
  ) {
    return ChapterListProvider(
      novel,
    );
  }

  @override
  ChapterListProvider getProviderOverride(
    covariant ChapterListProvider provider,
  ) {
    return call(
      provider.novel,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chapterListProvider';
}

/// ChapterListStateNotifier
///
/// 管理 ChapterListScreen 的状态
///
/// Copied from [ChapterList].
class ChapterListProvider
    extends AutoDisposeNotifierProviderImpl<ChapterList, ChapterListState> {
  /// ChapterListStateNotifier
  ///
  /// 管理 ChapterListScreen 的状态
  ///
  /// Copied from [ChapterList].
  ChapterListProvider(
    Novel novel,
  ) : this._internal(
          () => ChapterList()..novel = novel,
          from: chapterListProvider,
          name: r'chapterListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chapterListHash,
          dependencies: ChapterListFamily._dependencies,
          allTransitiveDependencies:
              ChapterListFamily._allTransitiveDependencies,
          novel: novel,
        );

  ChapterListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.novel,
  }) : super.internal();

  final Novel novel;

  @override
  ChapterListState runNotifierBuild(
    covariant ChapterList notifier,
  ) {
    return notifier.build(
      novel,
    );
  }

  @override
  Override overrideWith(ChapterList Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChapterListProvider._internal(
        () => create()..novel = novel,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        novel: novel,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ChapterList, ChapterListState>
      createElement() {
    return _ChapterListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChapterListProvider && other.novel == novel;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, novel.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChapterListRef on AutoDisposeNotifierProviderRef<ChapterListState> {
  /// The parameter `novel` of this provider.
  Novel get novel;
}

class _ChapterListProviderElement
    extends AutoDisposeNotifierProviderElement<ChapterList, ChapterListState>
    with ChapterListRef {
  _ChapterListProviderElement(super.provider);

  @override
  Novel get novel => (origin as ChapterListProvider).novel;
}

String _$chapterGenerationHash() => r'36ff47287eb4690778fe19fb758e6356a38b4abc';

/// 生成章节相关的状态
///
/// Copied from [ChapterGeneration].
@ProviderFor(ChapterGeneration)
final chapterGenerationProvider =
    AutoDisposeNotifierProvider<ChapterGeneration, bool>.internal(
  ChapterGeneration.new,
  name: r'chapterGenerationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterGenerationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChapterGeneration = AutoDisposeNotifier<bool>;
String _$generatedContentHash() => r'5e0490a42b0d893b900e04db648f55130f0fb57b';

/// 生成章节内容的状态
///
/// Copied from [GeneratedContent].
@ProviderFor(GeneratedContent)
final generatedContentProvider =
    AutoDisposeNotifierProvider<GeneratedContent, String>.internal(
  GeneratedContent.new,
  name: r'generatedContentProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$generatedContentHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GeneratedContent = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
