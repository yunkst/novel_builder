import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:novel_api/novel_api.dart';
import 'package:built_value/serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/character.dart';
import 'logger_service.dart';
import '../utils/logging/log_scope.dart';
import 'preferences_service.dart';

/// API 服务封装层
///
/// 本类是自动生成的 OpenAPI 客户端（novel_api）的包装器，提供统一的接口和配置管理。
///
/// ## 核心职责
/// 1. **配置管理**：统一管理后端 Host 和 API Token
/// 2. **错误处理**：网络异常的统一处理和重试机制
/// 3. **连接管理**：自动检测连接健康状态，必要时重新初始化
/// 4. **类型转换**：通过扩展方法将 API 模型转换为本地模型
/// 5. **请求去重**：通过 ChapterManager 管理并发请求，避免重复获取
///
/// ## 架构设计
/// - 依赖注入模式：通过 Provider 管理生命周期
/// - 自动重试：失败请求最多重试 2 次，支持指数退避
/// - 连接池优化：限制最大并发连接数，避免资源耗尽
/// - 健康检查：定期检测连接状态，自动恢复不健康连接
///
/// ## 使用示例
/// ```dart
/// // 通过 Provider 获取实例（推荐方式）
/// final apiService = ref.watch(apiServiceWrapperProvider);
///
/// // 直接使用（已通过 Provider 初始化）
/// ```
class ApiServiceWrapper {
  static const String _prefsHostKey = 'backend_host';
  static const String _prefsTokenKey = 'backend_token';

  /// 公共构造函数 - 通过依赖注入创建实例
  ///
  /// [api] OpenAPI 生成的 DefaultApi 实例（可选，用于测试）
  /// [dio] Dio HTTP 客户端实例（可选，用于自定义配置）
  ApiServiceWrapper([DefaultApi? api, Dio? dio])
      : _api = api ?? DefaultApi(Dio(), standardSerializers),
        _dio = dio ?? Dio(BaseOptions()) {
    // 如果提供了 dio 但没有提供 api，需要创建 api
    if (dio != null && api == null) {
      _api = DefaultApi(dio, standardSerializers);
    }
  }

  Dio _dio;
  DefaultApi _api;
  final Serializers _serializers = standardSerializers;

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
  /// 必须在使用前调用一次。此方法会重新配置 Dio 实例和创建 DefaultApi。
  Future<void> init() async {
    final host = await getHost();

    LoggerService.instance.d(
      '=== ApiServiceWrapper 初始化 ===',
      category: LogCategory.network,
      tags: ['debug', 'lifecycle'],
    );
    LoggerService.instance.i(
      'Host: $host',
      category: LogCategory.network,
      tags: ['api'],
    );

    if (host == null || host.isEmpty) {
      throw Exception('后端 HOST 未配置');
    }

    // 重新配置 Dio - 更新 baseUrl 和配置
    // 注意：由于 _dio 是 final，我们需要重新创建 _api 实例
    final configuredDio = Dio(BaseOptions(
      baseUrl: host,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 30),
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
    configuredDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // 优化连接池配置：减少连接数避免资源耗尽
        client.maxConnectionsPerHost = 20;
        // 设置连接空闲超时，避免长时间占用连接
        client.idleTimeout = const Duration(seconds: 60);
        // 设置连接超时
        client.connectionTimeout = const Duration(seconds: 15);
        return client;
      },
    );

    LoggerService.instance.i(
      '✅ Dio连接池配置已优化: 20个并发连接/主机，60秒空闲超时',
      category: LogCategory.network,
      tags: ['success', 'api'],
    );

    // 添加日志拦截器（仅在调试模式）
    configuredDio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: false, // 减少日志输出
      logPrint: (obj) => LoggerService.instance.d(
        '[API] $obj',
        category: LogCategory.network,
        tags: ['interceptor'],
      ),
    ));

    // 使用配置好的 Dio 重新创建 API 客户端
    _api = DefaultApi(configuredDio, _serializers);
    // 更新 _dio 字段，确保 dio getter 返回正确配置的实例
    _dio = configuredDio;

    _initialized = true;
    _lastInitTime = DateTime.now();
    _lastErrorCount = 0;
    _lastErrorTime = null;
    LoggerService.instance.d(
      '✓ ApiServiceWrapper 初始化完成',
      category: LogCategory.network,
      tags: ['debug', 'lifecycle'],
    );
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
        LoggerService.instance.w(
          '⚠️ 连接过期，需要重新初始化 (${age.inMinutes}分钟)',
          category: LogCategory.network,
          tags: ['warning', 'api'],
        );
        return false;
      }
    }

    // 检查错误频率（如果最近错误过多，认为连接不健康）
    if (_lastErrorTime != null) {
      final timeSinceLastError = DateTime.now().difference(_lastErrorTime!);
      if (timeSinceLastError.inMinutes < 2 && _lastErrorCount >= 3) {
        LoggerService.instance.e(
          '⚠️ 最近错误频繁，连接可能不稳定',
          category: LogCategory.network,
          tags: ['error', 'api'],
        );
        return false;
      }
    }

    return true;
  }

  /// 确保连接健康，必要时重新初始化
  Future<void> _ensureHealthyConnection() async {
    if (!_isConnectionHealthy()) {
      LoggerService.instance.i(
        '🔄 检测到连接不健康，正在重新初始化...',
        category: LogCategory.network,
        tags: ['retry', 'reinit'],
      );
      await _reinitializeConnection();
    }
  }

  /// 重新初始化连接
  Future<void> _reinitializeConnection() async {
    try {
      LoggerService.instance.i(
        '🔧 重新初始化API连接...',
        category: LogCategory.network,
        tags: ['retry', 'reinit'],
      );

      // 强制关闭旧连接（如果存在）
      try {
        _dio.close(force: true);
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          '关闭旧连接时出错',
          stackTrace: stackTrace.toString(),
          category: LogCategory.network,
          tags: ['error', 'api', 'dispose'],
        );
        LoggerService.instance.i(
          '关闭旧连接时出错: $e',
          category: LogCategory.network,
          tags: ['api'],
        );
      }

      // 重新初始化
      await init();

      LoggerService.instance.i(
        '✅ API连接重新初始化成功',
        category: LogCategory.network,
        tags: ['success', 'api'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '❌ API连接重新初始化失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'api', 'reinit', 'failed'],
      );
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

    LoggerService.instance.e(
      '🔌 记录连接错误 #$_lastErrorCount: $error',
      category: LogCategory.network,
      tags: ['error', 'api'],
    );

    // 如果错误过多，尝试自动重新初始化
    if (_lastErrorCount >= 3) {
      LoggerService.instance.e(
        '🔄 错误次数过多，尝试自动恢复连接...',
        category: LogCategory.network,
        tags: ['error', 'api'],
      );
      _reinitializeConnection().catchError((e, stackTrace) {
        LoggerService.instance.e(
          '❌ 自动恢复连接失败: $e',
          category: LogCategory.network,
          tags: ['error', 'api'],
        );
        LoggerService.instance.e(
          '自动恢复连接失败',
          stackTrace: stackTrace.toString(),
          category: LogCategory.network,
          tags: ['error', 'api', 'reinit', 'failed'],
        );
      });
    }
  }

  // ========================================================================
  // 配置管理
  // ========================================================================

  /// 获取配置的 Host
  Future<String?> getHost() async {
    return await PreferencesService.instance.getString(_prefsHostKey);
  }

  /// 获取配置的 Token
  Future<String?> getToken() async {
    return await PreferencesService.instance.getString(_prefsTokenKey);
  }

  /// 设置后端配置
  Future<void> setConfig({required String host, String? token}) async {
    await PreferencesService.instance.setString(_prefsHostKey, host.trim());
    if (token != null) {
      await PreferencesService.instance.setString(_prefsTokenKey, token.trim());
    }

    // 重新初始化
    await init();
  }

  // ========================================================================
  // 请求重试与错误处理
  // ========================================================================

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
          _lastErrorCount = 0;
          _lastErrorTime = null;
        }

        return result;
      } catch (e, stackTrace) {
        retryCount++;

        // 记录连接错误
        _recordConnectionError(e);

        if (retryCount > maxRetries) {
          LoggerService.instance.e(
            '❌ $operationName 最终失败: $e',
            stackTrace: stackTrace.toString(),
            category: LogCategory.network,
            tags: ['error', 'api', 'retry', 'failed'],
          );
          throw _handleError(e);
        }

        // 如果是连接错误，尝试重新初始化并重试
        if (_isConnectionError(e)) {
          LoggerService.instance.d(
            '$operationName 重试 #$retryCount（连接错误）',
            category: LogCategory.network,
            tags: ['api', 'retry', operationName, 'connection'],
          );
          await _reinitializeConnection();
          await Future.delayed(
              Duration(milliseconds: 1000 * retryCount)); // 指数退避
          continue;
        }

        // 其他错误也重试，但延迟更短
        LoggerService.instance.d(
          '$operationName 重试 #$retryCount（其它错误）',
          category: LogCategory.network,
          tags: ['api', 'retry', operationName],
        );
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }

    throw Exception('$operationName 重试失败');
  }

  // ========================================================================
  // 小说相关 API
  // ========================================================================

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
  /// 注意：ApiServiceWrapper 由 Provider 管理，不需要手动释放资源。
  /// Provider 会自动管理实例的生命周期。
  void dispose() {
    LoggerService.instance.i(
      'ApiServiceWrapper.dispose() called (managed by Provider)',
      category: LogCategory.network,
      tags: ['lifecycle', 'dispose'],
    );
    // Provider 会管理资源生命周期，这里不需要手动释放
  }

  // ========================================================================
  // 角色卡相关 API
  // ========================================================================

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
        LoggerService.instance.i(
          '角色卡生成请求成功: ${response.data}',
          category: LogCategory.network,
          tags: ['success', 'api'],
        );
        return {'message': '图片生成中，请耐心等待', 'status': 'success'};
      } else {
        throw Exception('生成人物卡失败：${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '生成人物卡失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'api', 'role_card', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 获取角色图集
  Future<Map<String, dynamic>> getRoleGallery(String roleId) async {
    return LogScope.capture(
      name: '获取角色图集',
      category: LogCategory.network,
      tags: ['api', 'gallery'],
      context: {'roleId': roleId},
      action: () async {
        _ensureInitialized();
        final token = await getToken();

        final response =
            await _api.getRoleCardGalleryApiRoleCardGalleryRoleIdGet(
          roleId: roleId,
          X_API_TOKEN: token,
        );

        if (response.statusCode == 200) {
          final responseData = response.data;
          if (responseData != null) {
            final apiImages = responseData.images;
            final imageList = apiImages.toList();
            return {
              'role_id': responseData.roleId,
              'images': imageList,
              'message': '图集获取成功'
            };
          }
          return {'role_id': roleId, 'images': [], 'message': '图集响应为空'};
        } else {
          throw Exception('获取图集失败：${response.statusCode}');
        }
      },
    );
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
        LoggerService.instance.i(
          '角色图片删除成功: $imageUrl',
          category: LogCategory.network,
          tags: ['success', 'api'],
        );
        return true;
      } else {
        throw Exception('删除图片失败：${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除角色图片失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'api', 'delete', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 生成更多相似图片
  Future<Map<String, dynamic>> generateMoreImages({
    required String roleId,
    required int count,
    String? referenceImageUrl,
    String? modelName,
  }) async {
    return LogScope.capture(
      name: '生成更多图片',
      category: LogCategory.network,
      tags: ['api', 'generate'],
      context: {
        'roleId': roleId,
        'count': count,
        if (referenceImageUrl != null) 'hasReference': true,
        if (modelName != null) 'modelName': modelName,
      },
      action: () async {
        _ensureInitialized();
        final token = await getToken();

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
      },
    );
  }

  /// 获取 Dio 实例（用于构建图片URL和下载）
  Dio get dio {
    // 允许在未初始化时访问，因为有些测试需要这样做
    // 但在实际使用中应该先调用 init()
    if (!_initialized) {
      LoggerService.instance.w(
        'Dio 实例访问时 ApiServiceWrapper 尚未初始化',
        category: LogCategory.network,
        tags: ['api', 'dio', 'not_initialized'],
      );
    }
    return _dio;
  }

  // ========================================================================
  // 场景插图相关 API
  // ========================================================================

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
        // 使用生成的SceneIllustrationResponse类型
        final sceneResponse = response.data!;
        return {
          'task_id': sceneResponse.taskId,
          'status': sceneResponse.status,
          'message': sceneResponse.message,
        };
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
        // 删除图片响应没有特定模型，直接返回成功
        return {'success': true, 'message': '删除成功'};
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
        // 使用生成的SceneRegenerateResponse类型
        final sceneResponse = response.data!;
        return {
          'task_id': sceneResponse.taskId,
          'total_prompts': sceneResponse.totalPrompts,
          'message': sceneResponse.message,
        };
      } else {
        throw Exception('重新生成场景插图图片失败：响应为空');
      }
    }, '重新生成场景插图图片');
  }

  /// 将 SceneGalleryResponse 转换为 Map
  Map<String, dynamic> _sceneGalleryResponseToMap(
      SceneGalleryResponse response) {
    // 转换 images: list<ImageWithModel> -> list<Map>
    final imagesList = response.images.map((img) {
      return {
        'url': img.url,
        'model_name': img.modelName,
      };
    }).toList();

    return {
      'task_id': response.taskId,
      'images': imagesList, // 改为对象列表
      'model_name': response.modelName, // 保留用于兼容
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

  // ========================================================================
  // 图生视频相关 API
  // ========================================================================

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
        LoggerService.instance.i(
          '图生视频生成请求成功: ${response.data}',
          category: LogCategory.network,
          tags: ['success', 'api'],
        );
        return response.data!;
      } else {
        throw Exception('生成图生视频失败：${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '生成图生视频失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'api', 'video', 'failed'],
      );
      LoggerService.instance.e(
        '生成图生视频异常: $e',
        category: LogCategory.network,
        tags: ['error', 'api'],
      );
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
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '检查视频状态失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'api', 'video', 'failed'],
      );
      LoggerService.instance.e(
        '检查视频状态异常: $e',
        category: LogCategory.network,
        tags: ['error', 'api'],
      );
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
    return LogScope.capture(
      name: '重新生成场景插图',
      category: LogCategory.network,
      tags: ['api', 'scene_illustration'],
      context: {
        'taskId': taskId,
        'count': count,
        if (modelName != null) 'model': modelName,
      },
      action: () async {
        _ensureInitialized();
        final token = await getToken();
        final request = SceneRegenerateRequest((b) => b
          ..taskId = taskId
          ..count = count
          ..model = modelName ?? '');

        final response =
            await _api.regenerateSceneImagesApiSceneIllustrationRegeneratePost(
          sceneRegenerateRequest: request,
          X_API_TOKEN: token,
        );

        if (response.statusCode == 200) {
          final data = response.data;
          if (data != null) {
            return {
              'task_id': data.taskId,
              'total_prompts': data.totalPrompts,
              'message': data.message,
            };
          }
          throw Exception('重新生成场景插图失败：响应数据为空');
        } else {
          throw Exception('重新生成场景插图失败：${response.statusCode}');
        }
      },
    );
  }

  // ========================================================================
  // 模型管理相关 API
  // ========================================================================

  /// 获取所有可用模型列表
  Future<ModelsResponse> getModels() async {
    return LogScope.capture(
      name: '获取模型列表',
      category: LogCategory.network,
      tags: ['api', 'models'],
      action: () async {
        _ensureInitialized();
        final token = await getToken();

        final response = await _api.getModelsApiModelsGet(
          X_API_TOKEN: token,
        );

        if (response.statusCode == 200) {
          return response.data!;
        } else {
          throw Exception('获取模型列表失败：${response.statusCode}');
        }
      },
    );
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
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取模型标题列表失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'api', 'models', 'failed'],
      );
      LoggerService.instance.e(
        '获取模型标题列表异常: $e',
        category: LogCategory.network,
        tags: ['error', 'api'],
      );
      throw _handleError(e);
    }
  }

  // ========================================================================
  // 备份相关 API
  // ========================================================================

  /// 上传数据库备份
  ///
  /// [dbFile] 数据库文件
  /// [onProgress] 上传进度回调
  ///
  /// 返回BackupUploadResponse，包含上传结果信息
  Future<BackupUploadResponse> uploadBackup({
    required File dbFile,
    ProgressCallback? onProgress,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }

      // 直接用 Dio 构造 multipart 请求，绕过生成的 BackupApi
      // （生成的 BackupApi 的 encodeFormParameter 处理文件路径时格式不正确，导致 422）
      final fileName = dbFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          dbFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/api/backup/upload',
        data: formData,
        options: Options(
          headers: {'X-API-TOKEN': token},
          contentType: 'multipart/form-data',
        ),
        onSendProgress: onProgress,
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = standardSerializers.deserialize(
          response.data,
          specifiedType: const FullType(BackupUploadResponse),
        ) as BackupUploadResponse;

        LoggerService.instance.i(
          '备份上传成功: ${result.storedPath}',
          category: LogCategory.network,
          tags: ['backup', 'success'],
        );
        return result;
      } else {
        throw Exception('备份上传失败：${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '备份上传失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'backup', 'failed'],
      );
      LoggerService.instance.e(
        '备份上传异常: $e',
        category: LogCategory.network,
        tags: ['error', 'backup'],
      );
      throw _handleError(e);
    }
  }

  /// 获取服务器备份列表
  ///
  /// 返回服务器上所有备份文件的信息（按时间倒序）
  /// 直接使用 _dio 绕过 OpenAPI 生成代码
  Future<List<Map<String, dynamic>>> getBackupList() async {
    _ensureInitialized();
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }

      final response = await _dio.get(
        '/api/backup/list',
        options: Options(
          headers: {'X-API-TOKEN': token},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final backups = (data['backups'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        LoggerService.instance.i(
          '获取备份列表成功: ${backups.length} 条',
          category: LogCategory.network,
          tags: ['backup', 'list', 'success'],
        );
        return backups;
      } else {
        throw Exception('获取备份列表失败：${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取备份列表失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'backup', 'list', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 下载备份到本地文件
  ///
  /// [backupId] 备份唯一标识（如 "2025-07-15/novel_app_backup.db"）
  /// [savePath] 本地保存路径
  /// [onProgress] 下载进度回调（可选）
  ///
  /// 返回本地保存的文件路径
  Future<String> downloadBackup({
    required String backupId,
    required String savePath,
    ProgressCallback? onProgress,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }

      // 对 backupId 进行 URL 编码（路径含 /）
      final encodedId = Uri.encodeComponent(backupId);

      await _dio.download(
        '/api/backup/download/$encodedId',
        savePath,
        options: Options(
          headers: {'X-API-TOKEN': token},
        ),
        onReceiveProgress: onProgress,
      );

      LoggerService.instance.i(
        '备份下载成功: $backupId -> $savePath',
        category: LogCategory.network,
        tags: ['backup', 'download', 'success'],
      );
      return savePath;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '备份下载失败: $backupId',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'backup', 'download', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 删除服务器上的备份
  ///
  /// [backupId] 备份唯一标识（如 "2025-07-15/novel_app_backup.db"）
  Future<void> deleteBackupOnServer({required String backupId}) async {
    _ensureInitialized();
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }

      final encodedId = Uri.encodeComponent(backupId);

      final response = await _dio.delete(
        '/api/backup/delete/$encodedId',
        options: Options(
          headers: {'X-API-TOKEN': token},
        ),
      );

      if (response.statusCode == 200) {
        LoggerService.instance.i(
          '备份删除成功: $backupId',
          category: LogCategory.network,
          tags: ['backup', 'delete', 'success'],
        );
      } else {
        throw Exception('备份删除失败：${response.statusCode}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '备份删除失败: $backupId',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'backup', 'delete', 'failed'],
      );
      throw _handleError(e);
    }
  }
}
