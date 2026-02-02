// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$databaseConnectionHash() =>
    r'c922b4150f1a08804551e45890e9408beaeffbe6';

/// 数据库连接Provider
///
/// 提供全局单例 DatabaseConnection 实例
/// 使用 keepAlive: true 确保数据库连接不会因为没有监听者而被销毁
///
/// Copied from [databaseConnection].
@ProviderFor(databaseConnection)
final databaseConnectionProvider = Provider<DatabaseConnection>.internal(
  databaseConnection,
  name: r'databaseConnectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$databaseConnectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DatabaseConnectionRef = ProviderRef<DatabaseConnection>;
String _$iDatabaseConnectionHash() =>
    r'cf5b77a1084c78147e4f4fd35831b163c6fa74ac';

/// IDatabaseConnection接口Provider
///
/// 提供接口类型的数据库连接，便于依赖注入和测试
///
/// Copied from [iDatabaseConnection].
@ProviderFor(iDatabaseConnection)
final iDatabaseConnectionProvider =
    AutoDisposeProvider<IDatabaseConnection>.internal(
  iDatabaseConnection,
  name: r'iDatabaseConnectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$iDatabaseConnectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IDatabaseConnectionRef = AutoDisposeProviderRef<IDatabaseConnection>;
String _$novelRepositoryHash() => r'db78c68a09195a23080e8da3fa820491d1b1227d';

/// NovelRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [novelRepository].
@ProviderFor(novelRepository)
final novelRepositoryProvider = AutoDisposeProvider<INovelRepository>.internal(
  novelRepository,
  name: r'novelRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$novelRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NovelRepositoryRef = AutoDisposeProviderRef<INovelRepository>;
String _$chapterRepositoryHash() => r'16896315729c603d33914948ef0266482431719c';

/// ChapterRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [chapterRepository].
@ProviderFor(chapterRepository)
final chapterRepositoryProvider =
    AutoDisposeProvider<IChapterRepository>.internal(
  chapterRepository,
  name: r'chapterRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChapterRepositoryRef = AutoDisposeProviderRef<IChapterRepository>;
String _$characterRepositoryHash() =>
    r'88d938991a24b892168a768899b6196a7546688f';

/// CharacterRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [characterRepository].
@ProviderFor(characterRepository)
final characterRepositoryProvider =
    AutoDisposeProvider<ICharacterRepository>.internal(
  characterRepository,
  name: r'characterRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterRepositoryRef = AutoDisposeProviderRef<ICharacterRepository>;
String _$characterRelationRepositoryHash() =>
    r'eb2410d4a7e3db567ccdff1062885190ce3a84d9';

/// CharacterRelationRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [characterRelationRepository].
@ProviderFor(characterRelationRepository)
final characterRelationRepositoryProvider =
    AutoDisposeProvider<ICharacterRelationRepository>.internal(
  characterRelationRepository,
  name: r'characterRelationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$characterRelationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CharacterRelationRepositoryRef
    = AutoDisposeProviderRef<ICharacterRelationRepository>;
String _$illustrationRepositoryHash() =>
    r'7b06c45523f227a39e04d2c1b4d249ad41b486c0';

/// IllustrationRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [illustrationRepository].
@ProviderFor(illustrationRepository)
final illustrationRepositoryProvider =
    AutoDisposeProvider<IIllustrationRepository>.internal(
  illustrationRepository,
  name: r'illustrationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$illustrationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IllustrationRepositoryRef
    = AutoDisposeProviderRef<IIllustrationRepository>;
String _$outlineRepositoryHash() => r'2729584c4249fb2abd7fc024f86002df82fa90a5';

/// OutlineRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [outlineRepository].
@ProviderFor(outlineRepository)
final outlineRepositoryProvider =
    AutoDisposeProvider<IOutlineRepository>.internal(
  outlineRepository,
  name: r'outlineRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$outlineRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OutlineRepositoryRef = AutoDisposeProviderRef<IOutlineRepository>;
String _$chatSceneRepositoryHash() =>
    r'533f26c9557fd2b10c89ed7d025c9a45c0f539a2';

/// ChatSceneRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [chatSceneRepository].
@ProviderFor(chatSceneRepository)
final chatSceneRepositoryProvider =
    AutoDisposeProvider<IChatSceneRepository>.internal(
  chatSceneRepository,
  name: r'chatSceneRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatSceneRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChatSceneRepositoryRef = AutoDisposeProviderRef<IChatSceneRepository>;
String _$bookshelfRepositoryHash() =>
    r'9f12c5aa18a12c4d48303b9f926256e73f2b1d7b';

/// BookshelfRepository Provider
///
/// 使用IDatabaseConnection接口注入，支持测试和依赖替换
///
/// Copied from [bookshelfRepository].
@ProviderFor(bookshelfRepository)
final bookshelfRepositoryProvider =
    AutoDisposeProvider<IBookshelfRepository>.internal(
  bookshelfRepository,
  name: r'bookshelfRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bookshelfRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BookshelfRepositoryRef = AutoDisposeProviderRef<IBookshelfRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
