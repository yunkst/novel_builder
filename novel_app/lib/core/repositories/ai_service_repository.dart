import '../utils/result.dart';

/// AI服务抽象接口
abstract class AIServiceRepository {
  /// 生成内容重写
  Future<Result<String>> generateRewrite(String originalContent, String requirements);

  /// 生成内容总结
  Future<Result<String>> generateSummary(String content);

  /// 生成章节内容
  Future<Result<String>> generateChapter(String context, String requirements);

  /// 流式生成内容重写
  Stream<Result<String>> generateRewriteStreaming(
    String originalContent,
    String requirements,
  );

  /// 流式生成章节内容
  Stream<Result<String>> generateChapterStreaming(
    String context,
    String requirements,
  );

  /// 检查AI服务是否可用
  Future<Result<bool>> isServiceAvailable();

  /// 获取服务配置
  Future<Result<Map<String, dynamic>>> getServiceConfig();

  /// 更新服务配置
  Future<Result<void>> updateServiceConfig(Map<String, dynamic> config);
}