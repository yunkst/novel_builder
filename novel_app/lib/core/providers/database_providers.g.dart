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
    r'b74e9e2a4ae22543b30a1190bf11748c662c8370';

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
String _$promptTagCategoryRepositoryHash() =>
    r'cbc4e912675859cba31c3ec93dc79163a8597b48';

/// PromptTagCategoryRepository Provider
///
/// Copied from [promptTagCategoryRepository].
@ProviderFor(promptTagCategoryRepository)
final promptTagCategoryRepositoryProvider =
    AutoDisposeProvider<IPromptTagCategoryRepository>.internal(
  promptTagCategoryRepository,
  name: r'promptTagCategoryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$promptTagCategoryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PromptTagCategoryRepositoryRef
    = AutoDisposeProviderRef<IPromptTagCategoryRepository>;
String _$promptTagRepositoryHash() =>
    r'b0ce6dabefb5203954d02130bfb6a73bcf47e687';

/// PromptTagRepository Provider
///
/// Copied from [promptTagRepository].
@ProviderFor(promptTagRepository)
final promptTagRepositoryProvider =
    AutoDisposeProvider<IPromptTagRepository>.internal(
  promptTagRepository,
  name: r'promptTagRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$promptTagRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PromptTagRepositoryRef = AutoDisposeProviderRef<IPromptTagRepository>;
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
String _$novelExportRepositoryHash() =>
    r'17f2c8cc3d25252a90358f48ae6e468122ded34d';

/// NovelExportRepository Provider
///
/// 用于小说数据的导出和导入操作
/// 依赖其他Repository，不直接依赖数据库连接
///
/// Copied from [novelExportRepository].
@ProviderFor(novelExportRepository)
final novelExportRepositoryProvider =
    AutoDisposeProvider<NovelExportRepository>.internal(
  novelExportRepository,
  name: r'novelExportRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$novelExportRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NovelExportRepositoryRef
    = AutoDisposeProviderRef<NovelExportRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
