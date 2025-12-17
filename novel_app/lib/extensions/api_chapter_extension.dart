import 'package:novel_api/novel_api.dart' as api;
import '../models/chapter.dart';

/// API Chapter 模型的扩展方法
///
/// 提供类型安全的模型转换，抑制 AI 幻觉
/// 所有字段访问都有编译时检查
extension ApiChapterExtension on api.Chapter {
  /// 将 API Chapter 模型转换为本地 Chapter 模型
  ///
  /// 使用编译时类型检查，确保字段名正确
  /// 任何拼写错误都会被编译器捕获
  Chapter toLocalModel({
    bool isCached = false,
    bool isUserInserted = false,
    int? chapterIndex,
  }) {
    return Chapter(
      title: title, // 编译器检查字段名，防止拼写错误
      url: url, // 编译器检查字段名
      content: null, // API 不提供 content，保持为 null
      isCached: isCached,
      isUserInserted: isUserInserted,
      chapterIndex: chapterIndex,
    );
  }
}
