// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_state_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chapterContentStateNotifierHash() =>
    r'2dc9d7dce40c0dafee331c0af6c803f63b9ee6c3';

/// ChapterContentStateNotifier
///
/// 管理章节内容的加载状态
///
/// Copied from [ChapterContentStateNotifier].
@ProviderFor(ChapterContentStateNotifier)
final chapterContentStateNotifierProvider = AutoDisposeNotifierProvider<
    ChapterContentStateNotifier, ChapterContentState>.internal(
  ChapterContentStateNotifier.new,
  name: r'chapterContentStateNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterContentStateNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChapterContentStateNotifier
    = AutoDisposeNotifier<ChapterContentState>;
String _$readingProgressStateNotifierHash() =>
    r'b357b428aa6b04d5cb959d3095e7335d973cb03b';

/// ReadingProgressStateNotifier
///
/// 管理阅读进度（滚动位置、字符索引等）
///
/// Copied from [ReadingProgressStateNotifier].
@ProviderFor(ReadingProgressStateNotifier)
final readingProgressStateNotifierProvider = AutoDisposeNotifierProvider<
    ReadingProgressStateNotifier, ReadingProgressState>.internal(
  ReadingProgressStateNotifier.new,
  name: r'readingProgressStateNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$readingProgressStateNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ReadingProgressStateNotifier
    = AutoDisposeNotifier<ReadingProgressState>;
String _$interactionStateNotifierHash() =>
    r'd3e7f97042ac5d2cc0dee0d300bf4bcb0b8b04aa';

/// InteractionStateNotifier
///
/// 管理用户交互状态
///
/// Copied from [InteractionStateNotifier].
@ProviderFor(InteractionStateNotifier)
final interactionStateNotifierProvider = AutoDisposeNotifierProvider<
    InteractionStateNotifier, InteractionState>.internal(
  InteractionStateNotifier.new,
  name: r'interactionStateNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$interactionStateNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$InteractionStateNotifier = AutoDisposeNotifier<InteractionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
