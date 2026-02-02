// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$loggerServiceHash() => r'517b7a109d52d09f96accf83448ccbb019465e6f';

/// LoggerService Provider
///
/// 提供全局日志服务实例，用于记录应用运行时的日志信息。
///
/// **功能**:
/// - 支持多级别日志（debug, info, warning, error）
/// - 支持日志分类和标签
/// - 持久化日志到本地文件
///
/// **依赖**:
/// - 无（单例服务）
///
/// **使用示例**:
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final logger = ref.watch(loggerServiceProvider);
///     logger.info('Widget 已构建');
///     return Container();
///   }
/// }
/// ```
///
/// **注意事项**:
/// - 使用 `LoggerService.instance` 单例模式
/// - 日志文件位于应用文档目录
/// - 支持异步日志写入
///
/// Copied from [loggerService].
@ProviderFor(loggerService)
final loggerServiceProvider = AutoDisposeProvider<LoggerService>.internal(
  loggerService,
  name: r'loggerServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loggerServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LoggerServiceRef = AutoDisposeProviderRef<LoggerService>;
String _$preferencesServiceHash() =>
    r'1ea3b212d9f5520c6d39cca0036eafba0aa904e3';

/// PreferencesService Provider
///
/// 提供全局 SharedPreferences 服务实例，用于存储用户偏好设置。
///
/// **功能**:
/// - 持久化键值对存储
/// - 支持多种数据类型（String、int、bool、double、List<String>等）
/// - 线程安全访问
///
/// **依赖**:
/// - 无（单例服务）
///
/// **使用示例**:
/// ```dart
/// final prefs = ref.watch(preferencesServiceProvider);
/// await prefs.setString('theme_mode', 'dark');
/// final themeMode = await prefs.getString('theme_mode');
/// ```
///
/// **注意事项**:
/// - 使用 `PreferencesService.instance` 单例模式
/// - 所有操作都是异步的
/// - 数据存储在本地 SharedPreferences
///
/// Copied from [preferencesService].
@ProviderFor(preferencesService)
final preferencesServiceProvider =
    AutoDisposeProvider<PreferencesService>.internal(
  preferencesService,
  name: r'preferencesServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preferencesServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PreferencesServiceRef = AutoDisposeProviderRef<PreferencesService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
