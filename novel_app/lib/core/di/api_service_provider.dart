import '../../services/api_service_wrapper.dart';

/// API服务提供者
/// 确保整个应用使用同一个ApiServiceWrapper实例
class ApiServiceProvider {
  static ApiServiceWrapper? _instance;

  /// 获取ApiServiceWrapper单例实例
  static ApiServiceWrapper get instance {
    _instance ??= ApiServiceWrapper();
    return _instance!;
  }

  /// 初始化API服务
  static Future<void> initialize() async {
    _instance ??= ApiServiceWrapper();
    await _instance!.init();
  }

  /// 重置实例（主要用于测试）
  static void reset() {
    _instance = null;
  }
}