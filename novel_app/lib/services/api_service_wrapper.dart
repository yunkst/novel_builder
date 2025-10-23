import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_api/novel_api.dart';
import 'package:built_value/serializer.dart';
import 'package:flutter/foundation.dart';
import '../models/novel.dart' as local;
import '../models/chapter.dart' as local;

/// API 服务封装层
///
/// 这个类封装了自动生成的 API 客户端，提供：
/// 1. 统一的配置管理（host, token）
/// 2. 自动注入认证头
/// 3. 错误处理
/// 4. 简化的调用接口
/// 5. 类型转换（built_value -> local model）
class ApiServiceWrapper {
  static const String _prefsHostKey = 'backend_host';
  static const String _prefsTokenKey = 'backend_token';
  static const String _tokenHeader = 'X-API-TOKEN';

  late Dio _dio;
  late DefaultApi _api;
  late Serializers _serializers;

  bool _initialized = false;

  /// 初始化 API 客户端
  ///
  /// 必须在使用前调用一次
  Future<void> init() async {
    final host = await getHost();
    final token = await getToken();

    if (host == null || host.isEmpty) {
      throw Exception('后端 HOST 未配置');
    }

    // 配置 Dio
    _dio = Dio(BaseOptions(
      baseUrl: host,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // CORS headers for web requests
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-TOKEN',
      },
    ));

    // 添加认证拦截器
    if (token != null && token.isNotEmpty) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers[_tokenHeader] = token;
          return handler.next(options);
        },
      ));
    }

    // 添加日志拦截器（仅在调试模式）
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false, // 减少日志输出
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));

    // 初始化生成的 API 客户端
    _serializers = standardSerializers;
    _api = DefaultApi(_dio, _serializers);

    _initialized = true;
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('ApiServiceWrapper 未初始化，请先调用 init()');
    }
  }

  /// 获取配置的 Host
  Future<String?> getHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsHostKey);
  }

  /// 获取配置的 Token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsTokenKey);
  }

  /// 设置后端配置
  Future<void> setConfig({required String host, String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsHostKey, host.trim());
    if (token != null) {
      await prefs.setString(_prefsTokenKey, token.trim());
    }

    // 重新初始化
    await init();
  }

  // ========== 业务方法 ==========

  /// 搜索小说
  Future<List<local.Novel>> searchNovels(String keyword) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      final response = await _api.searchSearchGet(
        keyword: keyword,
        X_API_TOKEN: token,
      );

      // 转换 built_value Novel 到 local Novel
      final novels = response.data?.toList() ?? [];
      return novels.map((novel) => local.Novel(
        title: novel.title,
        author: novel.author,
        url: novel.url,
      )).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取章节列表
  Future<List<local.Chapter>> getChapters(String novelUrl) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      final response = await _api.chaptersChaptersGet(
        url: novelUrl,
        X_API_TOKEN: token,
      );

      // 转换 built_value Chapter 到 local Chapter
      final chapters = response.data?.toList() ?? [];
      return chapters.asMap().entries.map((entry) {
        final index = entry.key;
        final chapter = entry.value;
        return local.Chapter(
          title: chapter.title,
          url: chapter.url,
          chapterIndex: index,
        );
      }).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取章节内容
  Future<String> getChapterContent(String chapterUrl) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      final response = await _api.chapterContentChapterContentGet(
        url: chapterUrl,
        X_API_TOKEN: token,
      );

      return response.data?.content ?? '';
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 统一错误处理
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        return Exception('API 错误: ${error.response?.statusCode} - ${error.response?.data}');
      } else {
        return Exception('网络错误: ${error.message}');
      }
    }
    return Exception('未知错误: $error');
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
