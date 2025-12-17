/// 应用配置文件
///
/// 这个文件包含应用的默认配置，包括后端API地址等
class AppConfig {
  // 后端API配置
  static const String defaultBackendHost = 'http://localhost:3800';
  static const String defaultBackendToken = 'your-api-token-here';

  // Dify AI配置（可选）
  static const String defaultDifyUrl = '';
  static const String defaultDifyToken = '';

  // 应用信息
  static const String appName = 'Novel App';
  static const String appVersion = '1.0.0';

  // 测试配置
  static const bool isDebugMode = true;
  static const bool enableLogging = true;

  // 超时配置
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);

  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // 缓存配置
  static const Duration defaultCacheExpiry = Duration(hours: 24);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB

  // 开发环境配置
  static const bool enableMockData = false;
  static const bool skipSSLVerification = true;
}
