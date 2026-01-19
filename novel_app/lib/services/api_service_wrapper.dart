import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_api/novel_api.dart';
import 'package:built_value/serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/novel.dart' as local;
import '../models/chapter.dart' as local;
import '../models/character.dart';
import '../extensions/api_novel_extension.dart';
import '../extensions/api_chapter_extension.dart';
import '../extensions/api_source_site_extension.dart';
import 'chapter_manager.dart';

/// API 服务封装层
///
/// 这个类封装了自动生成的 API 客户端，提供：
/// 1. 统一的配置管理（host, token）
/// 2. 错误处理
/// 3. 简化的调用接口
/// 4. 类型安全的模型转换（通过扩展方法）
class ApiServiceWrapper {
  static const String _prefsHostKey = 'backend_host';
  static const String _prefsTokenKey = 'backend_token';

  // 单例模式
  static final ApiServiceWrapper _instance = ApiServiceWrapper._internal();
  factory ApiServiceWrapper() => _instance;
  ApiServiceWrapper._internal();

  late Dio _dio;
  late DefaultApi _api;
  late Serializers _serializers;

  /// 章节管理器单例
  final ChapterManager _chapterManager = ChapterManager();

  bool _initialized = false;

  /// 提供对底层 DefaultApi 实例的访问
  DefaultApi get defaultApi {
    _ensureInitialized();
    return _api;
  }

  DateTime? _lastInitTime;
  int _lastErrorCount = 0;
  DateTime? _lastErrorTime;

  /// 初始化 API 客户端
  ///
  /// 必须在使用前调用一次
  Future<void> init() async {
    final host = await getHost();

    debugPrint('=== ApiServiceWrapper 初始化 ===');
    debugPrint('Host: $host');

    if (host == null || host.isEmpty) {
      throw Exception('后端 HOST 未配置');
    }

    // 配置 Dio - 简化配置，token通过参数传递
    _dio = Dio(BaseOptions(
      baseUrl: host,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 90),
      sendTimeout: Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // CORS headers for web requests
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers':
            'Content-Type, Authorization, X-API-TOKEN',
      },
    ));

    // 配置优化的HttpClientAdapter
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // 优化连接池配置：减少连接数避免资源耗尽
        client.maxConnectionsPerHost = 20; // 从100减少到20
        // 设置连接空闲超时，避免长时间占用连接
        client.idleTimeout = const Duration(seconds: 60); // 60秒空闲超时
        // 设置连接超时
        client.connectionTimeout = const Duration(seconds: 15);
        return client;
      },
    );

    debugPrint('✅ Dio连接池配置已优化: 20个并发连接/主机，60秒空闲超时');

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
    _lastInitTime = DateTime.now();
    _lastErrorCount = 0;
    _lastErrorTime = null;
    debugPrint('✓ ApiServiceWrapper 初始化完成');
  }

  /// 确保已初始化
  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('ApiServiceWrapper 未初始化，请先调用 init()');
    }
  }

  /// 检查服务是否已初始化（用于调试）
  bool get isInitialized => _initialized;

  /// 获取初始化状态信息（用于调试）
  Map<String, dynamic> getInitStatus() {
    return {
      'initialized': _initialized,
      'lastInitTime': _lastInitTime?.toIso8601String(),
      'lastErrorCount': _lastErrorCount,
      'lastErrorTime': _lastErrorTime?.toIso8601String(),
    };
  }

  /// 检查连接健康状态
  bool _isConnectionHealthy() {
    if (!_initialized) return false;

    // 检查初始化时间是否过期（30分钟）
    if (_lastInitTime != null) {
      final age = DateTime.now().difference(_lastInitTime!);
      if (age.inMinutes > 30) {
        debugPrint('⚠️ 连接过期，需要重新初始化 (${age.inMinutes}分钟)');
        return false;
      }
    }

    // 检查错误频率（如果最近错误过多，认为连接不健康）
    if (_lastErrorTime != null) {
      final timeSinceLastError = DateTime.now().difference(_lastErrorTime!);
      if (timeSinceLastError.inMinutes < 2 && _lastErrorCount >= 3) {
        debugPrint('⚠️ 最近错误频繁，连接可能不稳定');
        return false;
      }
    }

    return true;
  }

  /// 确保连接健康，必要时重新初始化
  Future<void> _ensureHealthyConnection() async {
    if (!_isConnectionHealthy()) {
      debugPrint('🔄 检测到连接不健康，正在重新初始化...');
      await _reinitializeConnection();
    }
  }

  /// 重新初始化连接
  Future<void> _reinitializeConnection() async {
    try {
      debugPrint('🔧 重新初始化API连接...');

      // 强制关闭旧连接（如果存在）
      try {
        _dio.close(force: true);
      } catch (e) {
        debugPrint('关闭旧连接时出错: $e');
      }

      // 重新初始化
      await init();

      debugPrint('✅ API连接重新初始化成功');
    } catch (e) {
      debugPrint('❌ API连接重新初始化失败: $e');
      throw Exception('连接重新初始化失败: $e');
    }
  }

  /// 检查是否为连接错误
  bool _isConnectionError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('closed') ||
        errorStr.contains('connection') ||
        errorStr.contains('establish') ||
        errorStr.contains('dio') ||
        errorStr.contains('socket') ||
        errorStr.contains('timeout') ||
        errorStr.contains('network');
  }

  /// 记录连接错误
  void _recordConnectionError(dynamic error) {
    _lastErrorTime = DateTime.now();
    _lastErrorCount++;

    debugPrint('🔌 记录连接错误 #$_lastErrorCount: $error');

    // 如果错误过多，尝试自动重新初始化
    if (_lastErrorCount >= 3) {
      debugPrint('🔄 错误次数过多，尝试自动恢复连接...');
      _reinitializeConnection().catchError((e) {
        debugPrint('❌ 自动恢复连接失败: $e');
      });
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

  /// 带自动重试的通用请求包装器
  Future<T> _withRetry<T>(
      Future<T> Function() operation, String operationName) async {
    int retryCount = 0;
    const maxRetries = 2; // 最多重试2次

    while (retryCount <= maxRetries) {
      try {
        // 确保连接健康
        await _ensureHealthyConnection();
        _ensureInitialized();

        final result = await operation();

        // 成功时重置错误计数
        if (_lastErrorCount > 0) {
          debugPrint('✅ 请求成功，重置错误计数 (之前: $_lastErrorCount)');
          _lastErrorCount = 0;
          _lastErrorTime = null;
        }

        return result;
      } catch (e) {
        retryCount++;

        // 记录连接错误
        _recordConnectionError(e);

        if (retryCount > maxRetries) {
          debugPrint('❌ $operationName 最终失败: $e');
          throw _handleError(e);
        }

        // 如果是连接错误，尝试重新初始化并重试
        if (_isConnectionError(e)) {
          debugPrint('🔄 检测到连接错误，重新初始化并重试 ($retryCount/$maxRetries)');
          await _reinitializeConnection();
          await Future.delayed(
              Duration(milliseconds: 1000 * retryCount)); // 指数退避
          continue;
        }

        // 其他错误也重试，但延迟更短
        debugPrint('⚠️ $operationName 失败，重试中 ($retryCount/$maxRetries): $e');
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }

    throw Exception('$operationName 重试失败');
  }

  /// 搜索小说
  Future<List<local.Novel>> searchNovels(String keyword,
      {List<String>? sites}) async {
    return _withRetry<List<local.Novel>>(() async {
      final token = await getToken();

      final response = await _api.searchSearchGet(
        keyword: keyword,
        sites: sites?.join(','),
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        return response.data
                ?.map((apiNovel) => apiNovel.toLocalModel())
                .toList() ??
            [];
      } else {
        throw Exception('搜索失败: ${response.statusCode}');
      }
    }, '搜索小说');
  }

  /// 获取源站列表
  Future<List<Map<String, dynamic>>> getSourceSites() async {
    return _withRetry<List<Map<String, dynamic>>>(() async {
      final token = await getToken();

      final response = await _api.getSourceSitesSourceSitesGet(
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        return response.data?.map((site) => site.toLocalModel()).toList() ?? [];
      } else {
        throw Exception('获取源站列表失败: ${response.statusCode}');
      }
    }, '获取源站列表');
  }

  /// 获取章节列表
  Future<List<local.Chapter>> getChapters(String novelUrl) async {
    return _withRetry<List<local.Chapter>>(() async {
      final token = await getToken();
      final response = await _api.chaptersChaptersGet(
        url: novelUrl,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        final chapters = response.data?.toList() ?? [];
        return chapters.asMap().entries.map((entry) {
          final index = entry.key;
          final chapter = entry.value;
          return chapter.toLocalModel(chapterIndex: index);
        }).toList();
      } else {
        throw Exception('获取章节列表失败: ${response.statusCode}');
      }
    }, '获取章节列表');
  }

  /// 获取章节内容
  ///
  /// [forceRefresh] 是否强制刷新，从源站重新获取内容（默认false）
  Future<String> getChapterContent(String chapterUrl,
      {bool forceRefresh = false}) async {
    // 使用章节管理器进行请求去重和管理
    return _chapterManager.getChapterContent(
      chapterUrl,
      forceRefresh: forceRefresh,
      fetchFunction: () => _fetchChapterContentFromNetwork(chapterUrl,
          forceRefresh: forceRefresh),
    );
  }

  /// 从网络获取章节内容的实际实现
  Future<String> _fetchChapterContentFromNetwork(String chapterUrl,
      {bool forceRefresh = false}) async {
    return _withRetry<String>(() async {
      final token = await getToken();
      final response = await _api.chapterContentChapterContentGet(
        url: chapterUrl,
        forceRefresh: forceRefresh,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        return response.data?.content ?? '';
      } else {
        throw Exception('获取章节内容失败: ${response.statusCode}');
      }
    }, '获取章节内容');
  }

  /// 统一错误处理
  Exception _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        return Exception(
            'API 错误: ${error.response?.statusCode} - ${error.response?.data}');
      } else {
        return Exception('网络错误: ${error.message}');
      }
    }
    return Exception('未知错误: $error');
  }

  /// 释放资源
  ///
  /// 注意：由于ApiServiceWrapper使用单例模式，不应关闭共享的Dio实例
  /// 所以此方法改为空操作，避免连接被过早关闭导致后续请求失败
  void dispose() {
    debugPrint(
        'ApiServiceWrapper.dispose() called (no-op to maintain connection)');
    // 不再关闭Dio连接，保持单例连接可用
    // _dio.close(); // 已注释，避免关闭共享连接
  }

  /// 生成人物卡图片
  Future<Map<String, dynamic>> generateRoleCardImages({
    required String roleId,
    required Map<String, dynamic> roles,
    String? modelName, // 添加模型名称参数
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      // 将Map格式的角色数据转换为Character对象，然后转换为RoleInfo列表
      final character = _mapToCharacter(roles);
      final roleInfoList = Character.toRoleInfoList([character]);

      final response = await _api.generateRoleCardImagesApiRoleCardGeneratePost(
        roleCardGenerateRequest: RoleCardGenerateRequest((b) => b
          ..roleId = roleId
          ..roles.replace(BuiltList<RoleInfo>(roleInfoList))
          ..model = modelName), // 传递模型名称参数
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        // 对于 JsonObject 响应，简单地返回成功状态
        debugPrint('角色卡生成请求成功: ${response.data}');
        return {'message': '图片生成中，请耐心等待', 'status': 'success'};
      } else {
        throw Exception('生成人物卡失败：${response.statusCode}');
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 获取角色图集
  Future<Map<String, dynamic>> getRoleGallery(String roleId) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      final response = await _api.getRoleCardGalleryApiRoleCardGalleryRoleIdGet(
        roleId: roleId,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        debugPrint('图集API响应数据类型: ${responseData.runtimeType}'); // 调试日志
        debugPrint('图集API响应数据: $responseData');

        if (responseData != null) {
          try {
            debugPrint('开始解析RoleGalleryResponse对象');

            // 直接处理RoleGalleryResponse对象
            final apiImages = responseData.images; // BuiltList<String>
            final imageList = apiImages.toList();

            debugPrint('直接解析到的图片列表: $imageList');

            return {
              'role_id': responseData.roleId,
              'images': imageList,
              'message': '图集获取成功'
            };
          } catch (e) {
            debugPrint('解析图集数据失败: $e');
            return {'role_id': roleId, 'images': [], 'message': '图集数据解析失败'};
          }
        }
        return {'role_id': roleId, 'images': [], 'message': '图集响应为空'};
      } else {
        throw Exception('获取图集失败：${response.statusCode}');
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 删除角色图片
  Future<bool> deleteRoleImage({
    required String roleId,
    required String imageUrl,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      // 创建删除请求对象
      final deleteRequest = RoleImageDeleteRequest((b) => b
        ..roleId = roleId
        ..imgUrl = imageUrl);

      final response = await _api.deleteRoleCardImageApiRoleCardImageDelete(
        roleImageDeleteRequest: deleteRequest,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        debugPrint('角色图片删除成功: $imageUrl');
        return true;
      } else {
        throw Exception('删除图片失败：${response.statusCode}');
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// 生成更多相似图片
  Future<Map<String, dynamic>> generateMoreImages({
    required String roleId,
    required int count,
    String? referenceImageUrl, // 可选的参考图片URL
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      debugPrint('生成图片请求，角色ID: $roleId, 数量: $count');

      if (referenceImageUrl != null && referenceImageUrl.isNotEmpty) {
        // 使用参考图片生成相似图片
        final regenerateRequest = RoleRegenerateRequest((b) => b
          ..imgUrl = referenceImageUrl
          ..count = count);

        final response =
            await _api.regenerateSimilarImagesApiRoleCardRegeneratePost(
          roleRegenerateRequest: regenerateRequest,
          X_API_TOKEN: token,
        );

        if (response.statusCode == 200) {
          return {
            'message': '图片生成请求已提交，正在根据参考图片生成 $count 张相似图片',
            'count': count,
            'status': 'processing',
            'reference_image': referenceImageUrl
          };
        } else {
          throw Exception('生成图片失败：${response.statusCode}');
        }
      } else {
        // 如果没有参考图片，使用角色ID重新生成
        final generateRequest = RoleCardGenerateRequest((b) => b
          ..roleId = roleId
          ..roles.replace(BuiltList<RoleInfo>([])));

        final response =
            await _api.generateRoleCardImagesApiRoleCardGeneratePost(
          roleCardGenerateRequest: generateRequest,
          X_API_TOKEN: token,
        );

        if (response.statusCode == 200) {
          return {
            'message': '图片生成请求已提交，正在生成 $count 张新图片',
            'count': count,
            'status': 'processing',
            'type': 'new_generation'
          };
        } else {
          throw Exception('生成图片失败：${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ 生成图片失败: $e');
      throw _handleError(e);
    }
  }

  /// 获取 Dio 实例（用于构建图片URL）
  Dio get dio => _dio;

  // ================= 场景插图相关API =================

  /// 创建场景插图任务
  Future<Map<String, dynamic>> createSceneIllustration({
    required String chaptersContent,
    required String taskId,
    required dynamic roles, // 支持新的 List<RoleInfo> 和旧的 Map<String, dynamic> 格式
    required int num,
    String? modelName,
  }) async {
    return _withRetry<Map<String, dynamic>>(() async {
      final token = await getToken();

      // 创建 EnhancedSceneIllustrationRequest
      final request = EnhancedSceneIllustrationRequest((b) => b
        ..chaptersContent = chaptersContent
        ..taskId = taskId
        ..roles.replace(roles is List
            ? BuiltList<RoleInfo>(roles)
            : BuiltList<RoleInfo>([]))
        ..num_ = num
        ..modelName = modelName);

      final response =
          await _api.generateSceneImagesApiSceneIllustrationGeneratePost(
        enhancedSceneIllustrationRequest: request,
        X_API_TOKEN: token,
      );

      if (response.data != null) {
        // 简单返回，让调用方处理 JsonObject
        return {'data': response.data.toString()};
      } else {
        throw Exception('操作失败：响应为空');
      }
    }, '创建场景插图');
  }

  /// 获取场景插图图集
  Future<Map<String, dynamic>> getSceneIllustrationGallery(
      String taskId) async {
    return _withRetry<Map<String, dynamic>>(() async {
      final token = await getToken();

      final response =
          await _api.getSceneGalleryApiSceneIllustrationGalleryTaskIdGet(
        taskId: taskId,
        X_API_TOKEN: token,
      );

      if (response.data != null) {
        // SceneGalleryResponse 转 Map
        return _sceneGalleryResponseToMap(response.data!);
      } else {
        throw Exception('获取场景插图图集失败：响应为空');
      }
    }, '获取场景插图图集');
  }

  /// 删除场景插图图片
  Future<Map<String, dynamic>> deleteSceneIllustrationImage({
    required String taskId,
    required String filename,
  }) async {
    return _withRetry<Map<String, dynamic>>(() async {
      final token = await getToken();

      // 创建 SceneImageDeleteRequest
      final request = SceneImageDeleteRequest((b) => b
        ..taskId = taskId
        ..filename = filename);

      final response =
          await _api.deleteSceneImageApiSceneIllustrationImageDelete(
        sceneImageDeleteRequest: request,
        X_API_TOKEN: token,
      );

      if (response.data != null) {
        // 简单返回，让调用方处理 JsonObject
        return {'data': response.data.toString()};
      } else {
        throw Exception('删除场景插图图片失败：响应为空');
      }
    }, '删除场景插图图片');
  }

  /// 重新生成场景插图图片
  Future<Map<String, dynamic>> regenerateSceneIllustration({
    required String taskId,
    required int count,
    String? model,
  }) async {
    return _withRetry<Map<String, dynamic>>(() async {
      final token = await getToken();

      // 使用生成的 SceneRegenerateRequest 模型
      final request = SceneRegenerateRequest((b) => b
        ..taskId = taskId
        ..count = count
        ..model = model);

      final response =
          await _api.regenerateSceneImagesApiSceneIllustrationRegeneratePost(
        sceneRegenerateRequest: request,
        X_API_TOKEN: token,
      );

      if (response.data != null) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('重新生成场景插图图片失败：响应为空');
      }
    }, '重新生成场景插图图片');
  }

  /// 将 SceneGalleryResponse 转换为 Map
  Map<String, dynamic> _sceneGalleryResponseToMap(
      SceneGalleryResponse response) {
    return {
      'task_id': response.taskId,
      'images': response.images.toList(),
      'model_name': response.modelName,
      'model_width': response.modelWidth,
      'model_height': response.modelHeight,
    };
  }

  /// 获取图片二进制数据
  Future<Uint8List> getImageProxy(String filename) async {
    return _withRetry<Uint8List>(() async {
      final response =
          await _api.getImageProxyText2imgImageFilenameGet(filename: filename);

      if (response.data != null) {
        return response.data!;
      } else {
        throw Exception('获取图片失败：响应为空');
      }
    }, '获取图片');
  }

  /// 将Map格式的角色数据转换为Character对象
  ///
  /// 此方法用于角色卡生成功能，将用户输入的表单数据（Map格式）
  /// 转换为标准的Character对象，然后可以通过toRoleInfoList方法
  /// 进一步转换为API所需的RoleInfo格式。
  ///
  /// [roles] 包含角色信息的Map，键为字段名，值为字段值
  ///
  /// 返回转换后的Character对象
  ///
  /// 支持的字段：
  /// - name: 角色姓名（必需）
  /// - age: 年龄（字符串，会尝试转换为int）
  /// - gender: 性别
  /// - occupation: 职业
  /// - personality: 性格特点
  /// - appearance_features: 外貌特征
  /// - body_type: 身材体型
  /// - clothing_style: 穿衣风格
  /// - background_story: 背景经历
  /// - face_prompts: 面部绘图提示词
  /// - body_prompts: 身材绘图提示词
  Character _mapToCharacter(Map<String, dynamic> roles) {
    return Character(
      id: 0, // 临时ID，由数据库分配
      novelUrl: '', // 临时空值，角色卡功能不需要
      name: roles['name']?.toString() ?? '',
      age: roles['age'] != null ? int.tryParse(roles['age'].toString()) : null,
      gender: roles['gender']?.toString(),
      occupation: roles['occupation']?.toString(),
      personality: roles['personality']?.toString(),
      appearanceFeatures: roles['appearance_features']?.toString(),
      bodyType: roles['body_type']?.toString(),
      clothingStyle: roles['clothing_style']?.toString(),
      backgroundStory: roles['background_story']?.toString(),
      facePrompts: roles['face_prompts']?.toString(),
      bodyPrompts: roles['body_prompts']?.toString(),
      createdAt: DateTime.now(),
    );
  }

  // ============================================================================
  // 图生视频功能
  // ============================================================================

  /// 生成图生视频
  Future<ImageToVideoResponse> generateVideoFromImage({
    required String imgName,
    required String userInput,
    String? modelName,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      final response =
          await _api.generateVideoFromImageApiImageToVideoGeneratePost(
        imageToVideoRequest: ImageToVideoRequest((b) => b
          ..imgName = imgName
          ..userInput = userInput
          ..modelName = modelName),
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        debugPrint('图生视频生成请求成功: ${response.data}');
        return response.data!;
      } else {
        throw Exception('生成图生视频失败：${response.statusCode}');
      }
    } catch (e) {
      debugPrint('生成图生视频异常: $e');
      throw _handleError(e);
    }
  }

  /// 检查图片是否有视频创建
  Future<VideoStatusResponse> checkVideoStatus(String imgName) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      final response =
          await _api.checkVideoStatusApiImageToVideoHasVideoImgNameGet(
        imgName: imgName,
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        return response.data ??
            VideoStatusResponse((b) => b
              ..imgName = imgName
              ..hasVideo = false);
      } else {
        throw Exception('检查视频状态失败：${response.statusCode}');
      }
    } catch (e) {
      debugPrint('检查视频状态异常: $e');
      throw _handleError(e);
    }
  }

  /// 获取视频文件URL
  Future<String> getVideoFileUrl(String imgName) async {
    _ensureInitialized();
    final host = await getHost();
    if (host == null) {
      throw Exception('后端地址未配置');
    }
    return buildVideoUrl(host, imgName);
  }

  /// 构建视频URL（静态方法，直接拼接）
  static String buildVideoUrl(String host, String imgName) {
    return '$host/api/image-to-video/video/${Uri.encodeComponent(imgName)}';
  }

  /// 重新生成场景插图
  Future<Map<String, dynamic>> regenerateSceneIllustrationImages({
    required String taskId,
    required int count,
    String? modelName,
  }) async {
    debugPrint('=== ApiServiceWrapper.regenerateSceneIllustrationImages ===');
    debugPrint('参数: taskId=$taskId, count=$count, modelName=$modelName');

    _ensureInitialized();
    debugPrint('✅ 初始化检查通过');

    try {
      debugPrint('🔄 获取 token...');
      final token = await getToken();
      debugPrint('✅ token获取成功: ${token?.substring(0, 10)}...');

      debugPrint('🔄 构建请求参数...');
      final request = SceneRegenerateRequest((b) => b
        ..taskId = taskId
        ..count = count
        ..model = modelName ?? '');
      debugPrint(
          '请求数据: taskId=${request.taskId}, count=${request.count}, model=${request.model}');

      debugPrint('🔄 发起API请求...');
      final response =
          await _api.regenerateSceneImagesApiSceneIllustrationRegeneratePost(
        sceneRegenerateRequest: request,
        X_API_TOKEN: token,
      );

      debugPrint('✅ API响应收到');
      debugPrint('状态码: ${response.statusCode}');
      debugPrint('响应类型: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        debugPrint('✅ 请求成功');
        debugPrint('响应数据: ${response.data}');
        final result =
            response.data as Map<String, dynamic>? ?? {'status': 'failed'};
        debugPrint('返回结果: $result');
        return result;
      } else {
        debugPrint('❌ 请求失败，状态码: ${response.statusCode}');
        throw Exception('重新生成场景插图失败：${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ API调用异常');
      debugPrint('异常类型: ${e.runtimeType}');
      debugPrint('异常信息: $e');
      debugPrint('堆栈跟踪:\n$stackTrace');
      debugPrint('====================================');
      rethrow;
    }
  }

  /// 获取所有可用模型列表
  Future<ModelsResponse> getModels() async {
    _ensureInitialized();
    try {
      final token = await getToken();

      final response = await _api.getModelsApiModelsGet(
        X_API_TOKEN: token,
      );

      if (response.statusCode == 200) {
        return response.data!;
      } else {
        throw Exception('获取模型列表失败：${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取模型列表异常: $e');
      throw _handleError(e);
    }
  }

  /// 获取指定类型的模型标题列表
  Future<List<String>> getModelTitles({String? apiType}) async {
    try {
      final models = await getModels();

      switch (apiType) {
        case 'i2v':
          final img2videoModels = models.img2video ?? BuiltList<WorkflowInfo>();
          return img2videoModels.map((model) => model.title).toList();
        case 't2i':
          final text2imgModels = models.text2img ?? BuiltList<WorkflowInfo>();
          return text2imgModels.map((model) => model.title).toList();
        default:
          final allModels = <String>[];
          if (models.text2img != null) {
            allModels.addAll(models.text2img!.map((model) => model.title));
          }
          if (models.img2video != null) {
            allModels.addAll(models.img2video!.map((model) => model.title));
          }
          return allModels;
      }
    } catch (e) {
      debugPrint('获取模型标题列表异常: $e');
      throw _handleError(e);
    }
  }
}
