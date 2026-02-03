// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_screen_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$characterImageCacheServiceHash() =>
    r'a0922279449db6986f2d33ed5209a360c1b526dc';

/// CharacterImageCacheService Provider
///
/// 提供角色图片缓存服务实例
/// 使用 keepAlive: true 确保实例不会被销毁（单例模式）
///
/// Copied from [characterImageCacheService].
@ProviderFor(characterImageCacheService)
final characterImageCacheServiceProvider =
    Provider<CharacterImageCacheService>.internal(
  characterImageCacheService,
  name: r'characterImageCacheServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterImageCacheServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterImageCacheServiceRef = ProviderRef<CharacterImageCacheService>;
String _$relationshipCountCacheHash() =>
    r'65dd262eb42624d2d5933ce6957faa78835bd34b';

/// 角色关系数量缓存 Provider
///
/// 为每个角色缓存关系数量
///
/// Copied from [relationshipCountCache].
@ProviderFor(relationshipCountCache)
final relationshipCountCacheProvider =
    AutoDisposeProvider<Map<int, int>>.internal(
  relationshipCountCache,
  name: r'relationshipCountCacheProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$relationshipCountCacheHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RelationshipCountCacheRef = AutoDisposeProviderRef<Map<int, int>>;
String _$hasOutlineHash() => r'6070a65f9ce0f6838c29a0a86a422d91f84c01a8';

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

/// Outline 状态 Provider
///
/// 检查小说是否有大纲
///
/// Copied from [hasOutline].
@ProviderFor(hasOutline)
const hasOutlineProvider = HasOutlineFamily();

/// Outline 状态 Provider
///
/// 检查小说是否有大纲
///
/// Copied from [hasOutline].
class HasOutlineFamily extends Family<AsyncValue<bool?>> {
  /// Outline 状态 Provider
  ///
  /// 检查小说是否有大纲
  ///
  /// Copied from [hasOutline].
  const HasOutlineFamily();

  /// Outline 状态 Provider
  ///
  /// 检查小说是否有大纲
  ///
  /// Copied from [hasOutline].
  HasOutlineProvider call(
    String novelUrl,
  ) {
    return HasOutlineProvider(
      novelUrl,
    );
  }

  @override
  HasOutlineProvider getProviderOverride(
    covariant HasOutlineProvider provider,
  ) {
    return call(
      provider.novelUrl,
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
  String? get name => r'hasOutlineProvider';
}

/// Outline 状态 Provider
///
/// 检查小说是否有大纲
///
/// Copied from [hasOutline].
class HasOutlineProvider extends AutoDisposeFutureProvider<bool?> {
  /// Outline 状态 Provider
  ///
  /// 检查小说是否有大纲
  ///
  /// Copied from [hasOutline].
  HasOutlineProvider(
    String novelUrl,
  ) : this._internal(
          (ref) => hasOutline(
            ref as HasOutlineRef,
            novelUrl,
          ),
          from: hasOutlineProvider,
          name: r'hasOutlineProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$hasOutlineHash,
          dependencies: HasOutlineFamily._dependencies,
          allTransitiveDependencies:
              HasOutlineFamily._allTransitiveDependencies,
          novelUrl: novelUrl,
        );

  HasOutlineProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.novelUrl,
  }) : super.internal();

  final String novelUrl;

  @override
  Override overrideWith(
    FutureOr<bool?> Function(HasOutlineRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HasOutlineProvider._internal(
        (ref) => create(ref as HasOutlineRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        novelUrl: novelUrl,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool?> createElement() {
    return _HasOutlineProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HasOutlineProvider && other.novelUrl == novelUrl;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, novelUrl.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HasOutlineRef on AutoDisposeFutureProviderRef<bool?> {
  /// The parameter `novelUrl` of this provider.
  String get novelUrl;
}

class _HasOutlineProviderElement extends AutoDisposeFutureProviderElement<bool?>
    with HasOutlineRef {
  _HasOutlineProviderElement(super.provider);

  @override
  String get novelUrl => (origin as HasOutlineProvider).novelUrl;
}

String _$characterManagementStateHash() =>
    r'052dac6a3218174100639b50a9770d9ea5897cfb';

abstract class _$CharacterManagementState
    extends BuildlessAutoDisposeAsyncNotifier<List<Character>> {
  late final Novel novel;

  FutureOr<List<Character>> build(
    Novel novel,
  );
}

/// CharacterManagement Screen State
///
/// 管理角色列表屏幕的状态
///
/// Copied from [CharacterManagementState].
@ProviderFor(CharacterManagementState)
const characterManagementStateProvider = CharacterManagementStateFamily();

/// CharacterManagement Screen State
///
/// 管理角色列表屏幕的状态
///
/// Copied from [CharacterManagementState].
class CharacterManagementStateFamily
    extends Family<AsyncValue<List<Character>>> {
  /// CharacterManagement Screen State
  ///
  /// 管理角色列表屏幕的状态
  ///
  /// Copied from [CharacterManagementState].
  const CharacterManagementStateFamily();

  /// CharacterManagement Screen State
  ///
  /// 管理角色列表屏幕的状态
  ///
  /// Copied from [CharacterManagementState].
  CharacterManagementStateProvider call(
    Novel novel,
  ) {
    return CharacterManagementStateProvider(
      novel,
    );
  }

  @override
  CharacterManagementStateProvider getProviderOverride(
    covariant CharacterManagementStateProvider provider,
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
  String? get name => r'characterManagementStateProvider';
}

/// CharacterManagement Screen State
///
/// 管理角色列表屏幕的状态
///
/// Copied from [CharacterManagementState].
class CharacterManagementStateProvider
    extends AutoDisposeAsyncNotifierProviderImpl<CharacterManagementState,
        List<Character>> {
  /// CharacterManagement Screen State
  ///
  /// 管理角色列表屏幕的状态
  ///
  /// Copied from [CharacterManagementState].
  CharacterManagementStateProvider(
    Novel novel,
  ) : this._internal(
          () => CharacterManagementState()..novel = novel,
          from: characterManagementStateProvider,
          name: r'characterManagementStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$characterManagementStateHash,
          dependencies: CharacterManagementStateFamily._dependencies,
          allTransitiveDependencies:
              CharacterManagementStateFamily._allTransitiveDependencies,
          novel: novel,
        );

  CharacterManagementStateProvider._internal(
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
  FutureOr<List<Character>> runNotifierBuild(
    covariant CharacterManagementState notifier,
  ) {
    return notifier.build(
      novel,
    );
  }

  @override
  Override overrideWith(CharacterManagementState Function() create) {
    return ProviderOverride(
      origin: this,
      override: CharacterManagementStateProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<CharacterManagementState,
      List<Character>> createElement() {
    return _CharacterManagementStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterManagementStateProvider && other.novel == novel;
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
mixin CharacterManagementStateRef
    on AutoDisposeAsyncNotifierProviderRef<List<Character>> {
  /// The parameter `novel` of this provider.
  Novel get novel;
}

class _CharacterManagementStateProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<CharacterManagementState,
        List<Character>> with CharacterManagementStateRef {
  _CharacterManagementStateProviderElement(super.provider);

  @override
  Novel get novel => (origin as CharacterManagementStateProvider).novel;
}

String _$characterEditControllerHash() =>
    r'771266ac9c709021effe0c36f6b8d589d7c878a3';

abstract class _$CharacterEditController
    extends BuildlessAutoDisposeAsyncNotifier<Character?> {
  late final Novel novel;
  late final Character? character;

  FutureOr<Character?> build({
    required Novel novel,
    Character? character,
  });
}

/// CharacterEdit Controller Provider
///
/// 管理角色编辑的状态和逻辑
/// 包括自动保存功能
///
/// Copied from [CharacterEditController].
@ProviderFor(CharacterEditController)
const characterEditControllerProvider = CharacterEditControllerFamily();

/// CharacterEdit Controller Provider
///
/// 管理角色编辑的状态和逻辑
/// 包括自动保存功能
///
/// Copied from [CharacterEditController].
class CharacterEditControllerFamily extends Family<AsyncValue<Character?>> {
  /// CharacterEdit Controller Provider
  ///
  /// 管理角色编辑的状态和逻辑
  /// 包括自动保存功能
  ///
  /// Copied from [CharacterEditController].
  const CharacterEditControllerFamily();

  /// CharacterEdit Controller Provider
  ///
  /// 管理角色编辑的状态和逻辑
  /// 包括自动保存功能
  ///
  /// Copied from [CharacterEditController].
  CharacterEditControllerProvider call({
    required Novel novel,
    Character? character,
  }) {
    return CharacterEditControllerProvider(
      novel: novel,
      character: character,
    );
  }

  @override
  CharacterEditControllerProvider getProviderOverride(
    covariant CharacterEditControllerProvider provider,
  ) {
    return call(
      novel: provider.novel,
      character: provider.character,
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
  String? get name => r'characterEditControllerProvider';
}

/// CharacterEdit Controller Provider
///
/// 管理角色编辑的状态和逻辑
/// 包括自动保存功能
///
/// Copied from [CharacterEditController].
class CharacterEditControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<CharacterEditController,
        Character?> {
  /// CharacterEdit Controller Provider
  ///
  /// 管理角色编辑的状态和逻辑
  /// 包括自动保存功能
  ///
  /// Copied from [CharacterEditController].
  CharacterEditControllerProvider({
    required Novel novel,
    Character? character,
  }) : this._internal(
          () => CharacterEditController()
            ..novel = novel
            ..character = character,
          from: characterEditControllerProvider,
          name: r'characterEditControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$characterEditControllerHash,
          dependencies: CharacterEditControllerFamily._dependencies,
          allTransitiveDependencies:
              CharacterEditControllerFamily._allTransitiveDependencies,
          novel: novel,
          character: character,
        );

  CharacterEditControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.novel,
    required this.character,
  }) : super.internal();

  final Novel novel;
  final Character? character;

  @override
  FutureOr<Character?> runNotifierBuild(
    covariant CharacterEditController notifier,
  ) {
    return notifier.build(
      novel: novel,
      character: character,
    );
  }

  @override
  Override overrideWith(CharacterEditController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CharacterEditControllerProvider._internal(
        () => create()
          ..novel = novel
          ..character = character,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        novel: novel,
        character: character,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<CharacterEditController, Character?>
      createElement() {
    return _CharacterEditControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterEditControllerProvider &&
        other.novel == novel &&
        other.character == character;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, novel.hashCode);
    hash = _SystemHash.combine(hash, character.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CharacterEditControllerRef
    on AutoDisposeAsyncNotifierProviderRef<Character?> {
  /// The parameter `novel` of this provider.
  Novel get novel;

  /// The parameter `character` of this provider.
  Character? get character;
}

class _CharacterEditControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<CharacterEditController,
        Character?> with CharacterEditControllerRef {
  _CharacterEditControllerProviderElement(super.provider);

  @override
  Novel get novel => (origin as CharacterEditControllerProvider).novel;
  @override
  Character? get character =>
      (origin as CharacterEditControllerProvider).character;
}

String _$autoSaveStateHash() => r'5ccf190cb0a1c4c0561f766973c58defd3f2a846';

/// 自动保存状态 Provider
///
/// 跟踪是否正在自动保存
///
/// Copied from [AutoSaveState].
@ProviderFor(AutoSaveState)
final autoSaveStateProvider =
    AutoDisposeNotifierProvider<AutoSaveState, bool>.internal(
  AutoSaveState.new,
  name: r'autoSaveStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$autoSaveStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AutoSaveState = AutoDisposeNotifier<bool>;
String _$multiSelectModeHash() => r'351ad30e7ebe0bcc6e9051ba029619ff66b197a3';

/// 多选模式状态 Provider
///
/// 管理角色列表的多选状态
///
/// Copied from [MultiSelectMode].
@ProviderFor(MultiSelectMode)
final multiSelectModeProvider =
    AutoDisposeNotifierProvider<MultiSelectMode, bool>.internal(
  MultiSelectMode.new,
  name: r'multiSelectModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$multiSelectModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MultiSelectMode = AutoDisposeNotifier<bool>;
String _$selectedCharacterIdsHash() =>
    r'b2c1ee55637efc3c647e99e122dfb4e566ff906d';

/// 已选角色ID集合 Provider
///
/// 管理已选中的角色ID列表
///
/// Copied from [SelectedCharacterIds].
@ProviderFor(SelectedCharacterIds)
final selectedCharacterIdsProvider =
    AutoDisposeNotifierProvider<SelectedCharacterIds, Set<int>>.internal(
  SelectedCharacterIds.new,
  name: r'selectedCharacterIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedCharacterIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedCharacterIds = AutoDisposeNotifier<Set<int>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
