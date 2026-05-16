import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service_wrapper.dart';
import 'hermes_sse_parser.dart';
import 'logger_service.dart';

/// Hermes Chat 服务配置
class HermesConfig {
  final String backendUrl;
  final String apiToken;

  HermesConfig({
    required this.backendUrl,
    required this.apiToken,
  });

  String get chatUrl => '$backendUrl/hermes/chat/completions';
  String get healthUrl => '$backendUrl/hermes/health';
}

/// Hermes Chat 服务
class HermesChatService {
  final ApiServiceWrapper _apiService;

  HermesChatService({required ApiServiceWrapper apiService})
      : _apiService = apiService;

  /// 获取当前配置
  Future<HermesConfig?> getConfig() async {
    final url = await _apiService.getHost();
    final token = await _apiService.getToken();
    if (url == null || url.isEmpty) return null;
    return HermesConfig(backendUrl: url, apiToken: token ?? '');
  }

  /// 发送聊天消息（流式）
  Future<void> sendMessage({
    required List<Map<String, String>> messages,
    String? sessionId,
    void Function(String content)? onContent,
    void Function(ToolProgress progress)? onToolProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    final cfg = await getConfig();
    if (cfg == null) {
      onError?.call('Hermes 未配置，请先设置后端地址');
      return;
    }

    final payload = {
      'messages': messages,
      'stream': true,
      if (sessionId != null) 'session_id': sessionId,
    };

    LoggerService.instance.d(
      'Hermes: Sending message to ${cfg.chatUrl}',
      category: LogCategory.ai,
      tags: ['hermes', 'chat', 'send'],
    );

    try {
      final dio = _apiService.dio;
      final response = await dio.post<ResponseBody>(
        cfg.chatUrl,
        data: payload,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'X-API-TOKEN': cfg.apiToken,
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
        ),
      );

      final responseStream = response.data?.stream;
      if (responseStream == null) {
        onError?.call('Empty response stream');
        return;
      }

      // 将 Uint8List 流转为 String 流
      final stringStream = responseStream.transform(
        StreamTransformer<Uint8List, String>.fromHandlers(
          handleData: (data, sink) {
            sink.add(utf8.decode(data, allowMalformed: true));
          },
        ),
      );

      // 使用 SSE 解析器
      final eventStream = HermesSSEParser.parseStream(stringStream.cast<String>());

      // 监听文本增量
      HermesSSEParser.extractTextStream(eventStream).listen(
        onContent ?? (_) {},
        onError: (e) => onError?.call(e.toString()),
      );

      // 监听工具进度
      HermesSSEParser.extractToolProgressStream(eventStream).listen(
        onToolProgress ?? (_) {},
        onError: (e) => onError?.call(e.toString()),
      );

      // 等待完成
      final success = await HermesSSEParser.waitForCompletion(eventStream);
      if (success) {
        onDone?.call();
      }
    } on DioException catch (e) {
      LoggerService.instance.e(
        'Hermes request failed: ${e.message}',
        category: LogCategory.ai,
        tags: ['hermes', 'chat', 'error'],
      );
      onError?.call(_formatDioError(e));
    } catch (e) {
      LoggerService.instance.e(
        'Hermes unexpected error: $e',
        category: LogCategory.ai,
        tags: ['hermes', 'chat', 'error'],
      );
      onError?.call(e.toString());
    }
  }

  /// 检查 Hermes 健康状态
  Future<Map<String, dynamic>> healthCheck() async {
    final cfg = await getConfig();
    if (cfg == null) {
      return {'status': 'unconfigured', 'message': '后端未配置'};
    }

    try {
      final dio = _apiService.dio;
      final response = await dio.get<Map<String, dynamic>>(
        cfg.healthUrl,
        options: Options(headers: {'X-API-TOKEN': cfg.apiToken}),
      );
      return response.data ?? {'status': 'unknown'};
    } on DioException catch (e) {
      return {'status': 'error', 'message': _formatDioError(e)};
    }
  }

  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查后端地址';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) return 'API Token 无效';
        if (code == 503) return 'Hermes 服务未配置';
        return '服务器错误 ($code)';
      default:
        return e.message ?? '未知错误';
    }
  }
}
