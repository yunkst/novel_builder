// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_screen_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$readerScreenNotifierHash() =>
    r'c8037c04f1fb986cc83f12b147b36923b65ac6f3';

/// ReaderScreenNotifier
///
/// 管理阅读器屏幕的业务逻辑，包括：
/// - 对话框状态管理
/// - AI伴读功能
/// - 章节内容刷新
/// - 角色卡更新
/// - TTS朗读
///
/// Copied from [ReaderScreenNotifier].
@ProviderFor(ReaderScreenNotifier)
final readerScreenNotifierProvider = AutoDisposeNotifierProvider<
    ReaderScreenNotifier, ReaderScreenState>.internal(
  ReaderScreenNotifier.new,
  name: r'readerScreenNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$readerScreenNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ReaderScreenNotifier = AutoDisposeNotifier<ReaderScreenState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
