// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_scene_management_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatSceneRepositoryHash() =>
    r'024f2c0b2e7f39442d8a93b92b79c65be3bb1854';

/// ChatSceneManagement Provider
///
/// 提供聊天场景数据访问
///
/// Copied from [chatSceneRepository].
@ProviderFor(chatSceneRepository)
final chatSceneRepositoryProvider =
    AutoDisposeProvider<ChatSceneRepository>.internal(
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
typedef ChatSceneRepositoryRef = AutoDisposeProviderRef<ChatSceneRepository>;
String _$chatSceneManagementHash() =>
    r'd3360fcb8730605f7d51ddad866ce207f3556107';

/// ChatSceneManagementState Provider
///
/// 管理聊天场景管理界面的状态
///
/// Copied from [ChatSceneManagement].
@ProviderFor(ChatSceneManagement)
final chatSceneManagementProvider = AutoDisposeNotifierProvider<
    ChatSceneManagement, ChatSceneManagementState>.internal(
  ChatSceneManagement.new,
  name: r'chatSceneManagementProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatSceneManagementHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatSceneManagement = AutoDisposeNotifier<ChatSceneManagementState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
