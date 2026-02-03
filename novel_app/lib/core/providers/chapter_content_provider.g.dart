// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter_content_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chapterContentHash() => r'c292da3d1c8e74cb0fe8f23e52a4b654cc858fd8';

/// ChapterContentProvider
///
/// 管理章节内容加载的 Provider
/// 支持从缓存或API加载章节内容
///
/// Copied from [ChapterContent].
@ProviderFor(ChapterContent)
final chapterContentProvider =
    AutoDisposeNotifierProvider<ChapterContent, ChapterContentState>.internal(
  ChapterContent.new,
  name: r'chapterContentProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chapterContentHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChapterContent = AutoDisposeNotifier<ChapterContentState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
