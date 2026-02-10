import '../../services/preferences_service.dart';
import '../../services/logger_service.dart';

/// Dify配置管理服务
///
/// 负责管理Dify API的配置信息，包括URL和各类Token的获取。
class DifyConfigService {
  /// 获取Dify API基础URL
  Future<String> getDifyUrl() async {
    final url = await PreferencesService.instance.getString('dify_url');
    if (url.isEmpty) {
      throw Exception('请先在设置中配置 Dify URL');
    }
    return url;
  }

  /// 获取流式响应Token
  ///
  /// 用于工作流流式响应模式
  Future<String> getFlowToken() async {
    final token =
        await PreferencesService.instance.getString('dify_flow_token');
    if (token.isEmpty) {
      throw Exception('请先在设置中配置 Flow Token (流式响应)');
    }
    return token;
  }

  /// 获取结构化响应Token
  ///
  /// 用于工作流阻塞式响应模式（runWorkflowBlocking方法）
  /// 如果struct_token不存在，会尝试使用flow_token作为降级选项
  Future<String> getStructToken() async {
    final token =
        await PreferencesService.instance.getString('dify_struct_token');
    if (token.isEmpty) {
      // 如果struct_token不存在，尝试使用flow_token作为降级
      final flowToken =
          await PreferencesService.instance.getString('dify_flow_token');
      if (flowToken.isNotEmpty) {
        LoggerService.instance.w(
          '⚠️ Struct Token未配置，使用Flow Token作为降级',
          category: LogCategory.ai,
          tags: ['warning', 'dify'],
        );
        return flowToken;
      }
      throw Exception('请先在设置中配置 Struct Token (结构化响应)');
    }
    return token;
  }

  /// 获取AI作家设定
  Future<String> getAiWriterSetting() async {
    return await PreferencesService.instance
        .getString('ai_writer_prompt', defaultValue: '');
  }

  /// 检查Dify配置是否完整
  ///
  /// 返回配置状态，包含url、flowToken、structToken的状态
  Future<DifyConfigStatus> checkConfigStatus() async {
    final url = await PreferencesService.instance.getString('dify_url');
    final flowToken =
        await PreferencesService.instance.getString('dify_flow_token');
    final structToken =
        await PreferencesService.instance.getString('dify_struct_token');

    return DifyConfigStatus(
      hasUrl: url.isNotEmpty,
      hasFlowToken: flowToken.isNotEmpty,
      hasStructToken: structToken.isNotEmpty,
      isComplete: url.isNotEmpty && flowToken.isNotEmpty,
    );
  }

  /// 构建完整的API端点URL
  String buildApiEndpoint(String baseUrl, String path) {
    return '$baseUrl$path';
  }
}

/// Dify配置状态
class DifyConfigStatus {
  final bool hasUrl;
  final bool hasFlowToken;
  final bool hasStructToken;
  final bool isComplete;

  const DifyConfigStatus({
    required this.hasUrl,
    required this.hasFlowToken,
    required this.hasStructToken,
    required this.isComplete,
  });

  @override
  String toString() {
    return 'DifyConfigStatus{hasUrl: $hasUrl, hasFlowToken: $hasFlowToken, '
        'hasStructToken: $hasStructToken, isComplete: $isComplete}';
  }
}
