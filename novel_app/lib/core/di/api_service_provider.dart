import '../../services/api_service_wrapper.dart';

/// API服务提供者
///
/// @deprecated 请使用 Riverpod Provider 代替
/// 推荐使用方式：
/// ```dart
/// // 在 Widget 中
/// final apiService = ref.watch(apiServiceWrapperProvider);
///
/// // 在其他地方
/// final container = ProviderContainer();
/// final apiService = container.read(apiServiceWrapperProvider);
/// ```
///
/// 确保整个应用使用同一个ApiServiceWrapper实例
/// 此类保留用于向后兼容
@Deprecated('请使用 apiServiceWrapperProvider Provider 代替。'
    '示例: ref.watch(apiServiceWrapperProvider)')
class ApiServiceProvider {
  static ApiServiceWrapper? _instance;

  /// 获取ApiServiceWrapper单例实例
  @Deprecated('请使用 apiServiceWrapperProvider Provider 代替')
  static ApiServiceWrapper get instance {
    _instance ??= ApiServiceWrapper();
    return _instance!;
  }

  /// 初始化API服务
  @Deprecated('请使用 apiServiceWrapperProvider Provider 代替')
  static Future<void> initialize() async {
    _instance ??= ApiServiceWrapper();
    await _instance!.init();
  }

  /// 重置实例（主要用于测试）
  static void reset() {
    _instance = null;
  }
}
