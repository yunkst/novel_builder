import 'package:novel_api/novel_api.dart' as api;

/// API SourceSite 模型的扩展方法
///
/// 提供类型安全的模型转换，抑制 AI 幻觉
/// 所有字段访问都有编译时检查
extension ApiSourceSiteExtension on api.SourceSite {
  /// 将 API SourceSite 模型转换为本地 Map 格式
  ///
  /// 使用编译时类型检查，确保字段名正确
  /// 任何拼写错误都会被编译器捕获
  Map<String, dynamic> toLocalModel() {
    return {
      'id': id, // 编译器检查字段名
      'name': name, // 编译器检查字段名
      'base_url': baseUrl, // 编译器检查字段名，使用 wireName 映射
      'description': description, // 编译器检查字段名
      'enabled': enabled, // 编译器检查字段名
      'search_enabled': searchEnabled, // 编译器检查字段名，使用 wireName 映射
    };
  }
}
