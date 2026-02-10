// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ui_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$toastNotifierHash() => r'5e6227980861a53aa28452e8fd607ec12e9e99fd';

/// Toast状态管理器
///
/// **职责**:
/// - 管理Toast消息状态
/// - 提供显示各类Toast的接口
/// - 自动触发状态更新通知UI层
///
/// **架构原则**:
/// - Notifier只管理状态，不直接显示Toast
/// - UI层通过ref.listen监听状态变化并显示
/// - 显示后立即清除状态，避免重复显示
///
/// Copied from [ToastNotifier].
@ProviderFor(ToastNotifier)
final toastNotifierProvider =
    AutoDisposeNotifierProvider<ToastNotifier, ToastState>.internal(
  ToastNotifier.new,
  name: r'toastNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$toastNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ToastNotifier = AutoDisposeNotifier<ToastState>;
String _$dialogNotifierHash() => r'05514a5db5a053720d17897138cda2f4e1b568fc';

/// 对话框状态管理器
///
/// **职责**:
/// - 管理对话框显示状态
/// - 提供显示各类对话框的接口
/// - UI层通过ref.listen监听状态变化并显示对话框
///
/// **架构原则**:
/// - Notifier只管理状态，不直接显示对话框
/// - UI层通过ref.listen监听状态变化并显示
/// - 用户操作后通过Notifier方法更新状态
///
/// Copied from [DialogNotifier].
@ProviderFor(DialogNotifier)
final dialogNotifierProvider =
    AutoDisposeNotifierProvider<DialogNotifier, DialogState>.internal(
  DialogNotifier.new,
  name: r'dialogNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dialogNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DialogNotifier = AutoDisposeNotifier<DialogState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
