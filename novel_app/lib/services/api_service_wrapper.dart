import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_api/novel_api.dart';
import 'package:built_value/serializer.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/novel.dart' as local;
import '../models/chapter.dart' as local;
import '../models/cache_task.dart';
import 'api_direct.dart';

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

  // 单例模式
  static final ApiServiceWrapper _instance = ApiServiceWrapper._internal();
  factory ApiServiceWrapper() => _instance;
  ApiServiceWrapper._internal();

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

    debugPrint('=== ApiServiceWrapper 初始化 ===');
    debugPrint('Host: $host');
    debugPrint('Token: ${token ?? "NULL"}');
    debugPrint('Token 长度: ${token?.length ?? 0}');

    if (host == null || host.isEmpty) {
      throw Exception('后端 HOST 未配置');
    }

    // 配置 Dio
    _dio = Dio(BaseOptions(
      baseUrl: host,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 90),
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
      debugPrint('✓ 添加认证拦截器，Token: $token');
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint('=== API 请求拦截器 ===');
          debugPrint('URL: ${options.uri}');
          debugPrint('Method: ${options.method}');
          debugPrint('添加 Token: $_tokenHeader = $token');
          options.headers[_tokenHeader] = token;
          debugPrint('最终 Headers: ${options.headers}');
          return handler.next(options);
        },
        onError: (error, handler) {
          debugPrint('=== API 错误拦截器 ===');
          debugPrint('URL: ${error.requestOptions.uri}');
          debugPrint('状态码: ${error.response?.statusCode}');
          debugPrint('错误信息: ${error.response?.data}');
          return handler.next(error);
        },
      ));
    } else {
      debugPrint('✗ Token 为空，未添加认证拦截器');
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
    debugPrint('✓ ApiServiceWrapper 初始化完成');
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

  // ========== 缓存相关方法 ==========

  /// 创建缓存任务
  Future<CacheTask> createCacheTask(String novelUrl) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      final response = await _api.createCacheTaskApiCacheCreatePost(
        novelUrl: novelUrl,
        X_API_TOKEN: token,
      );

      // 从响应中提取任务数据
      final data = response.data;
      if (data != null) {
        // 将 JsonObject 转换为 Map
        final dataMap = _jsonObjectToMap(data);
        if (dataMap.containsKey('task_id')) {
          return CacheTask.fromJson(dataMap);
        }
      }
      throw Exception('创建缓存任务失败：响应格式错误');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取缓存任务列表
  Future<List<CacheTask>> getCacheTasks() async {
    _ensureInitialized();
    try {
      final token = await getToken();
      debugPrint('调用 getCacheTasks API，token: $token');

      final response = await _api.getCacheTasksApiCacheTasksGet(
        X_API_TOKEN: token,
      );

      debugPrint('API 响应状态: ${response.statusCode}');
      debugPrint('API 响应数据类型: ${response.data.runtimeType}');
      debugPrint('API 响应数据: ${response.data}');

      final data = response.data;
      if (data != null) {
        List<dynamic> tasksList = [];

        // 尝试多种方式提取 tasks 数据
        try {
          Map<String, dynamic> dataMap;

          // 强制转换为字符串，然后修复格式并解析 JSON
          final jsonString = data.toString();
          debugPrint('原始数据字符串: $jsonString');

          if (jsonString.isNotEmpty) {
            // 先修复JSON格式，然后再解析
            String fixedJsonString = _fixJsonFormat(jsonString);
            debugPrint('修复后的JSON字符串: $fixedJsonString');

            final parsed = jsonDecode(fixedJsonString);
            if (parsed is Map<String, dynamic>) {
              dataMap = parsed;
            } else {
              throw FormatException('解析结果不是 Map<String, dynamic>');
            }
          } else {
            throw FormatException('数据为空');
          }

          if (dataMap.containsKey('tasks')) {
            tasksList = (dataMap['tasks'] as List<dynamic>?) ?? [];
          }
        } catch (e) {
          debugPrint('解析 JSON 失败，尝试直接提取: $e');
          debugPrint('原始数据类型: ${data.runtimeType}');
          debugPrint('原始数据内容: ${data.toString()}');

          // 最后的备选方案：返回空列表而不是崩溃
          return [];
        }

        debugPrint('提取到 ${tasksList.length} 个任务');

        // 安全地转换每个任务
        List<CacheTask> cacheTasks = [];
        for (var taskData in tasksList) {
          try {
            if (taskData is Map<String, dynamic>) {
              cacheTasks.add(CacheTask.fromJson(taskData));
            } else {
              debugPrint('跳过无效的任务数据类型: ${taskData.runtimeType}');
            }
          } catch (e) {
            debugPrint('解析单个任务失败: $e');
            debugPrint('任务数据: $taskData');
            // 跳过无效的任务而不是崩溃
            continue;
          }
        }

        return cacheTasks;
      }

      return [];
    } catch (e) {
      debugPrint('getCacheTasks 失败，尝试直接 API 调用: $e');

      // 备选方案：使用直接 API 调用
      try {
        final directApi = ApiDirectService();
        await directApi.init();
        final result = await directApi.getCacheTasks();
        directApi.dispose();
        return result;
      } catch (e2) {
        debugPrint('直接 API 调用也失败: $e2');
        throw _handleError(e);
      }
    }
  }

  /// 获取缓存任务状态
  Future<CacheTaskUpdate> getCacheTaskStatus(int taskId) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      final response = await _api.getCacheStatusApiCacheStatusTaskIdGet(
        taskId: taskId,
        X_API_TOKEN: token,
      );

      final data = response.data;
      if (data != null) {
        final dataMap = _jsonObjectToMap(data);
        return CacheTaskUpdate.fromJson(dataMap);
      } else {
        throw Exception('获取缓存状态失败：响应格式错误');
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 取消缓存任务
  Future<bool> cancelCacheTask(int taskId) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      final response = await _api.cancelCacheTaskApiCacheCancelTaskIdPost(
        taskId: taskId,
        X_API_TOKEN: token,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 下载已缓存小说
  Future<String> downloadCachedNovel(int taskId, {String format = 'json'}) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      final response = await _api.downloadCachedNovelApiCacheDownloadTaskIdGet(
        taskId: taskId,
        format: format,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        return response.toString();
      } else {
        throw Exception('下载缓存失败：${response.statusCode}');
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 将 JsonObject 转换为 Map\<String, dynamic\>
  Map<String, dynamic> _jsonObjectToMap(dynamic jsonObject) {
    if (jsonObject is Map<String, dynamic>) {
      return jsonObject;
    }

    // 如果是 BuiltMap/JsonObject，尝试通过 toString 转换
    if (jsonObject.toString().startsWith('{') && jsonObject.toString().endsWith('}')) {
      try {
        final jsonString = jsonObject.toString();
        final parsed = jsonDecode(jsonString);
        return Map<String, dynamic>.from(parsed);
      } catch (e) {
        debugPrint('BuiltMap toString 转换失败: $e');
      }
    }

    // 如果是 JsonObject，尝试转换为字符串再解析
    if (jsonObject != null) {
      try {
        final jsonString = jsonObject.toString();
        debugPrint('原始 JSON 字符串: $jsonString');

        // 修复常见的 JSON 格式问题
        String fixedJsonString = _fixJsonFormat(jsonString);
        debugPrint('修复后的 JSON 字符串: $fixedJsonString');

        final parsed = jsonDecode(fixedJsonString);
        return Map<String, dynamic>.from(parsed);
      } catch (e) {
        // 如果转换失败，返回空 Map
        debugPrint('JSON解析失败: $e');
        debugPrint('原始对象类型: ${jsonObject.runtimeType}');

        // 尝试手动解析简单的格式
        if (jsonObject.toString().startsWith('{tasks:')) {
          return _parseTasksJson(jsonObject.toString());
        }

        return {};
      }
    }

    return {};
  }

  /// 修复常见的 JSON 格式问题
  String _fixJsonFormat(String jsonString) {
    // 移除可能的 BOM 标记
    if (jsonString.startsWith('\uFEFF')) {
      jsonString = jsonString.substring(1);
    }

    debugPrint('开始修复 JSON 格式...');
    debugPrint('原始字符串: $jsonString');

    // 修复缺少引号的键名 - 使用更精确的正则表达式
    // 匹配不在字符串内的键名
    jsonString = jsonString.replaceAllMapped(
      RegExp(r'([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:'),
      (match) {
        final prefix = match.group(1)!;
        final key = match.group(2)!;
        return '$prefix"$key":';
      },
    );

    // 修复未加引号的字符串值 - 分步骤处理更复杂的情况
    // 首先处理简单的字符串值（不包含特殊字符）
    jsonString = jsonString.replaceAllMapped(
      RegExp(r':\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*([,}\]])'),
      (match) {
        final value = match.group(1)!;
        final suffix = match.group(2)!;

        // 跳过已知的数字和布尔值
        if (RegExp(r'^(true|false|null)$').hasMatch(value)) {
          return ': $value$suffix';
        }

        // 如果是纯数字，不加引号
        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
          return ': $value$suffix';
        }

        return ': "$value"$suffix';
      },
    );

    // 处理包含T的日期时间字符串（ISO格式）
    jsonString = jsonString.replaceAllMapped(
      RegExp(r':\s*([a-zA-Z_]*\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?[a-zA-Z_]*)\s*([,}\]])'),
      (match) {
        final value = match.group(1)!;
        final suffix = match.group(2)!;
        return ': "$value"$suffix';
      },
    );

    // 修复空值问题 - 将 : , 形式替换为 : "",
    jsonString = jsonString.replaceAllMapped(
      RegExp(r':\s*,'),
      (match) => ': "",',
    );

    // 修复对象结束前的空值 - 将 : } 形式替换为 : "" }
    jsonString = jsonString.replaceAllMapped(
      RegExp(r':\s*}'),
      (match) => ': "" }',
    );

    // 修复数组结束前的空值 - 将 : ] 形式替换为: "" ]
    jsonString = jsonString.replaceAllMapped(
      RegExp(r':\s*\]'),
      (match) => ': "" ]',
    );

    debugPrint('修复后的字符串: $jsonString');
    return jsonString;
  }

  /// 手动解析 tasks 格式的 JSON
  Map<String, dynamic> _parseTasksJson(String jsonString) {
    try {
      debugPrint('尝试手动解析 tasks JSON');

      // 简单的手动解析，提取 tasks 数组
      final tasksRegex = RegExp(r'tasks:\s*\[(.*?)\]');
      final match = tasksRegex.firstMatch(jsonString);

      if (match != null) {
        final tasksString = match.group(1)!;
        debugPrint('提取的 tasks 字符串: $tasksString');

        // 这里可以进一步解析，但为了简单起见，返回基本结构
        return {
          'tasks': [],
          'total': 0,
        };
      }
    } catch (e) {
      debugPrint('手动解析也失败: $e');
    }

    return {};
  }
}
