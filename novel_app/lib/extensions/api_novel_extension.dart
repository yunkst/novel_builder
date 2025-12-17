import 'package:novel_api/novel_api.dart' as api;
import '../models/novel.dart';

/// API Novel 模型的扩展方法
///
/// 提供类型安全的模型转换，抑制 AI 幻觉
/// 所有字段访问都有编译时检查
extension ApiNovelExtension on api.Novel {
  /// 将 API Novel 模型转换为本地 Novel 模型
  ///
  /// 使用编译时类型检查，确保字段名正确
  /// 任何拼写错误都会被编译器捕获
  Novel toLocalModel({bool isInBookshelf = false}) {
    return Novel(
      title: title, // 编译器检查字段名，防止 titel 等拼写错误
      author: author, // 编译器检查字段名，防止 auther 等拼写错误
      url: url, // 编译器检查字段名
      isInBookshelf: isInBookshelf,
      coverUrl: null, // API 不提供这些字段，保持为 null
      description: null, // API 不提供这些字段，保持为 null
      backgroundSetting: null, // API 不提供这些字段，保持为 null
    );
  }
}
