import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:novel_api/novel_api.dart';
import 'package:built_value/serializer.dart';
import 'dart:io';
import 'dart:typed_data';
import 'logger_service.dart';
import 'preferences_service.dart';

/// API 服务封装层
///
/// 提供统一的 Dio HTTP 客户端配置、后端地址/Token 管理、错误处理与重试。
/// 直接调用 backend REST API（不走 OpenAPI 生成的 DefaultApi），
/// 部分方法使用 novel_api 包定义的类型做反序列化（如 BackupUploadResponse）。
///
/// ## 核心职责
/// 1. **配置管理**：统一管理后端 Host 和 API Token
/// 2. **错误处理**：网络异常的统一处理和重试机制
/// 3. **连接管理**：自动检测连接健康状态，必要时重新初始化
///
/// ## 使用示例
/// ```dart
/// final apiService = ref.watch(apiServiceWrapperProvider);
/// ```
class ApiServiceWrapper {
  static const String _prefsHostKey = 'backend_host';
  static const String _prefsTokenKey = 'backend_token';

  /// 公共构造函数 - 通过依赖注入创建实例
  ///
  /// [dio] Dio HTTP 客户端实例（可选，用于自定义配置）
  ApiServiceWrapper([Dio? dio]) : _dio = dio ?? Dio(BaseOptions());

  Dio _dio;

  /// 只读暴露内部 Dio 实例
  ///
  /// 供单元测试注入 [HttpClientAdapter] 拦截 HTTP 请求，也可用于调试。
  Dio get dio => _dio;

  bool _initialized = false;

  /// 是否已完成 [init]
  bool get isInitialized => _initialized;

  /// 初始化 API 客户端
  ///
  /// 必须在使用前调用一次。此方法会重新配置 Dio 实例。
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

    // 更新 _dio 字段
    _dio = configuredDio;

    _initialized = true;
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

  // ========================================================================
// 统一错误处理
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

  // ======================== ComfyUI 模型分块上传 ========================

  /// 列出 backend /app/models 下的一级子目录
  ///
  /// 返回 `[{name, size_bytes}]` 形式的列表
  Future<List<Map<String, dynamic>>> listModelDirs() async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      final response = await _dio.get(
        '/api/models/dirs',
        options: Options(headers: {'X-API-TOKEN': token}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final dirs = (data['dirs'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        return dirs;
      }
      throw Exception('获取模型目录列表失败：${response.statusCode}');
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取模型目录列表失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'models', 'dirs', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 初始化一个分块上传任务
  ///
  /// 返回 `{upload_id, chunk_size, total_chunks}`
  Future<Map<String, dynamic>> initModelUpload({
    required String filename,
    required String targetSubdir,
    required int totalSize,
    required int chunkSize,
    required int totalChunks,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      final response = await _dio.post(
        '/api/models/upload/init',
        data: {
          'filename': filename,
          'target_subdir': targetSubdir,
          'total_size': totalSize,
          'chunk_size': chunkSize,
          'total_chunks': totalChunks,
        },
        options: Options(
          headers: {'X-API-TOKEN': token},
          contentType: 'application/json',
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('初始化上传失败：${response.statusCode}');
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '初始化模型上传失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'models', 'init', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 上传一个分块
  ///
  /// [chunkBytes] 分块二进制数据，[onProgress] 进度回调
  /// 返回 `{index, received_bytes}`
  Future<Map<String, dynamic>> uploadModelChunk({
    required String uploadId,
    required int index,
    required List<int> chunkBytes,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      final response = await _dio.post(
        '/api/models/upload/$uploadId/chunk/$index',
        data: Stream.fromIterable([Uint8List.fromList(chunkBytes)]),
        options: Options(
          headers: {
            'X-API-TOKEN': token,
            'Content-Type': 'application/octet-stream',
          },
          contentType: 'application/octet-stream',
        ),
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('上传分块失败：${response.statusCode}');
    } on DioException catch (e) {
      // 取消时静默抛出，由上层识别
      if (e.type == DioExceptionType.cancel) {
        rethrow;
      }
      LoggerService.instance.e(
        '上传分块失败: uploadId=$uploadId index=$index - ${e.message}',
        category: LogCategory.network,
        tags: ['error', 'models', 'chunk', 'failed'],
      );
      throw _handleError(e);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '上传分块异常: uploadId=$uploadId index=$index',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'models', 'chunk', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 查询分块上传状态
  ///
  /// 返回 `{upload_id, total_chunks, received_indices: [...], complete}`
  Future<Map<String, dynamic>> getModelUploadStatus({
    required String uploadId,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      final response = await _dio.get(
        '/api/models/upload/$uploadId/status',
        options: Options(headers: {'X-API-TOKEN': token}),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('查询上传状态失败：${response.statusCode}');
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询上传状态失败: uploadId=$uploadId',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'models', 'status', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 完成分块上传，触发后端合并
  ///
  /// 返回 `{stored_path, filename, size}`
  Future<Map<String, dynamic>> completeModelUpload({
    required String uploadId,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      final response = await _dio.post(
        '/api/models/upload/$uploadId/complete',
        options: Options(headers: {'X-API-TOKEN': token}),
      );
      if (response.statusCode == 200 && response.data != null) {
        LoggerService.instance.i(
          '模型上传完成: $uploadId',
          category: LogCategory.network,
          tags: ['models', 'complete', 'success'],
        );
        return response.data as Map<String, dynamic>;
      }
      throw Exception('完成上传失败：${response.statusCode}');
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '完成模型上传失败: uploadId=$uploadId',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'models', 'complete', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 取消分块上传，删除 backend 临时分块
  Future<void> cancelModelUpload({required String uploadId}) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      await _dio.delete(
        '/api/models/upload/$uploadId',
        options: Options(headers: {'X-API-TOKEN': token}),
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '取消模型上传失败: uploadId=$uploadId',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'models', 'cancel', 'failed'],
      );
      // 取消失败不抛出，避免影响本地清理
    }
  }

  // ======================== 文生图（ComfyUI） ========================

  /// 检查后端 ComfyUI 健康状态（GET /text2img/health）。
  ///
  /// 不抛异常：成功且 status=="healthy" 返回 (true, message)；
  /// 任何失败/网络错误返回 (false, message)。供 comfyuiHealthy Provider
  /// 决定是否向 Agent 注入图片工具。
  Future<(bool, String)> checkComfyuiHealth() async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return (false, 'API Token未配置');
      }
      final response = await _dio.get(
        '/text2img/health',
        options: Options(headers: {'X-API-TOKEN': token}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'unhealthy';
        final message = data['message'] as String? ?? '';
        return (status == 'healthy', message);
      }
      return (false, 'ComfyUI 健康检查返回 ${response.statusCode}');
    } catch (e) {
      LoggerService.instance.d(
        'ComfyUI 健康检查失败: $e',
        category: LogCategory.network,
        tags: ['text2img', 'health', 'failed'],
      );
      return (false, '健康检查请求失败：$e');
    }
  }

  /// 获取可用文生图工作流列表（GET /api/models 的 text2img 节）。
  ///
  /// 返回精简字段 [{name, description, isDefault, promptSkill}]，name 即工作流标题，
  /// 作为 create_images 的 modelName 参数；promptSkill 是该工作流的提示词写作技巧
  /// （含正向/负向 prompt 的写法建议），为 null 表示后端未配置。
  Future<List<Map<String, dynamic>>> getText2ImgModels() async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      final response = await _dio.get(
        '/api/models',
        options: Options(headers: {'X-API-TOKEN': token}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['text2img'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        // 精简字段：title → name，prompt_skill → promptSkill
        return list
            .map((m) => {
                  'name': m['title'],
                  'description': m['description'],
                  'isDefault': m['is_default'] == true,
                  'promptSkill': m['prompt_skill'],
                })
            .toList();
      }
      throw Exception('获取文生图模型列表失败：${response.statusCode}');
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '获取文生图模型列表失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'text2img', 'models', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 提交一个文生图任务（POST /api/text2img/generate）。
  ///
  /// [prompt] 图片生成提示词；[modelName] 工作流标题（来自 getText2ImgModels），
  /// 不传则后端用默认工作流；[negativePrompt] 负向提示词（可选，仅工作流含
  /// 「负向提示词在这里替换」占位符时生效，否则静默忽略）。返回后端 task_id。
  Future<String> submitText2ImgTask({
    required String prompt,
    String? modelName,
    String? negativePrompt,
  }) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('API Token未配置');
      }
      final response = await _dio.post(
        '/api/text2img/generate',
        data: {
          'prompt': prompt,
          if (modelName != null && modelName.isNotEmpty)
            'model_name': modelName,
          if (negativePrompt != null && negativePrompt.isNotEmpty)
            'negative_prompt': negativePrompt,
        },
        options: Options(
          headers: {'X-API-TOKEN': token},
          contentType: 'application/json',
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final taskId = (response.data as Map<String, dynamic>)['task_id'];
        if (taskId is String && taskId.isNotEmpty) return taskId;
        throw Exception('后端未返回有效的 task_id');
      }
      throw Exception('提交文生图任务失败：${response.statusCode}');
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '提交文生图任务失败: prompt=${prompt.length}字符',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['error', 'text2img', 'generate', 'failed'],
      );
      throw _handleError(e);
    }
  }

  /// 按 task_id 拉取文生图结果（GET /api/text2img/image/{task_id}）。
  ///
  /// 不抛异常，返回 (bytes?, statusCode)：
  /// - 200 → (bytes, 200)，bytes 为 PNG 二进制
  /// - 202 → (null, 202)，图片仍在生成
  /// - 404 → (null, 404)，任务不存在/失败
  /// - 其他/网络错误 → (null, code)
  ///
  /// 上层（_GalleryImage）靠 statusCode 决策 loading / loaded / 刷新。
  Future<(Uint8List?, int)> fetchText2ImgImage(String taskId) async {
    _ensureInitialized();
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return (null, 401);
      }
      final response = await _dio.get(
        '/api/text2img/image/$taskId',
        options: Options(
          headers: {'X-API-TOKEN': token},
          responseType: ResponseType.bytes,
          // 202/404 不当错误抛，统一靠 statusCode 判断
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return ((response.data as Uint8List?) ?? Uint8List(0), 200);
      }
      return (null, response.statusCode ?? 0);
    } on DioException catch (e) {
      // validateStatus 放行的非 2xx 已在上面处理；这里仅网络层错误
      final code = e.response?.statusCode ?? 0;
      LoggerService.instance.d(
        '拉取文生图失败: taskId=$taskId code=$code - ${e.message}',
        category: LogCategory.network,
        tags: ['text2img', 'image', 'fetch', 'failed'],
      );
      return (null, code);
    } catch (e) {
      LoggerService.instance.e(
        '拉取文生图异常: taskId=$taskId',
        category: LogCategory.network,
        tags: ['text2img', 'image', 'fetch', 'error'],
      );
      return (null, 0);
    }
  }
}
