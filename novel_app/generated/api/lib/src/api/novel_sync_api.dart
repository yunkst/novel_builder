//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:dio/dio.dart';

import 'package:built_value/json_object.dart';
import 'package:novel_api/src/api_util.dart';
import 'package:novel_api/src/model/http_validation_error.dart';
import 'package:novel_api/src/model/novel_sync_download_request.dart';
import 'package:novel_api/src/model/novel_sync_download_response.dart';
import 'package:novel_api/src/model/novel_sync_list_response.dart';
import 'package:novel_api/src/model/novel_sync_upload_request.dart';
import 'package:novel_api/src/model/novel_sync_upload_response.dart';

class NovelSyncApi {

  final Dio _dio;

  final Serializers _serializers;

  const NovelSyncApi(this._dio, this._serializers);

  /// Delete Synced Novel
  /// 删除已同步的小说数据.  从服务器删除指定小说的所有同步数据，包括章节、角色、关系和大纲。  **查询参数:** - **novel_url**: 小说URL（作为唯一标识）  **返回值:** - **success**: 是否成功 - **message**: 响应消息  **认证**: 需要X-API-TOKEN header  **注意:** 此操作不可逆，删除后数据无法恢复
  ///
  /// Parameters:
  /// * [novelUrl] 
  /// * [X_API_TOKEN] 
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [JsonObject] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<JsonObject>> deleteSyncedNovelApiNovelSyncDeleteDelete({ 
    required String novelUrl,
    String? X_API_TOKEN,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/novel/sync/delete';
    final _options = Options(
      method: r'DELETE',
      headers: <String, dynamic>{
        r'X-API-TOKEN': X_API_TOKEN,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {
            'type': 'http',
            'scheme': 'bearer',
            'name': 'HTTPBearer',
          },
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      r'novel_url': encodeQueryParameter(_serializers, novelUrl, const FullType(String)),
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    JsonObject? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null ? null : _serializers.deserialize(
        rawResponse,
        specifiedType: const FullType(JsonObject),
      ) as JsonObject;

    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<JsonObject>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Download Novel
  /// 从服务器下载小说数据.  根据小说来源URL（source_url）获取服务器上存储的完整小说数据。 支持选择性下载章节、角色和大纲数据。  **请求参数:** - **device_id**: 设备标识 - **source_url**: 小说来源URL（作为唯一标识，与上传时一致） - **include_chapters**: 是否包含章节内容（默认true） - **include_characters**: 是否包含角色数据（默认true） - **include_outlines**: 是否包含大纲数据（默认true）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novel_data**: 完整的小说数据（如果找到） - **sync_version**: 同步版本号 - **synced_at**: 最后同步时间  **认证**: 需要X-API-TOKEN header  **注意:** 如果小说不存在，返回success&#x3D;false，novel_data&#x3D;null
  ///
  /// Parameters:
  /// * [novelSyncDownloadRequest] 
  /// * [X_API_TOKEN] 
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [NovelSyncDownloadResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<NovelSyncDownloadResponse>> downloadNovelApiNovelSyncDownloadPost({ 
    required NovelSyncDownloadRequest novelSyncDownloadRequest,
    String? X_API_TOKEN,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/novel/sync/download';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'X-API-TOKEN': X_API_TOKEN,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {
            'type': 'http',
            'scheme': 'bearer',
            'name': 'HTTPBearer',
          },
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(NovelSyncDownloadRequest);
      _bodyData = _serializers.serialize(novelSyncDownloadRequest, specifiedType: _type);

    } catch(error, stackTrace) {
      throw DioException(
         requestOptions: _options.compose(
          _dio.options,
          _path,
        ),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    NovelSyncDownloadResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null ? null : _serializers.deserialize(
        rawResponse,
        specifiedType: const FullType(NovelSyncDownloadResponse),
      ) as NovelSyncDownloadResponse;

    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<NovelSyncDownloadResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// List Synced Novels
  /// 获取已同步小说列表.  返回服务器上所有已同步小说的基本信息列表，支持分页。 返回的数据仅包含元数据，不包含章节内容。  **查询参数:** - **page**: 页码（从1开始，默认1） - **page_size**: 每页数量（默认20，最大100）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novels**: 小说元数据列表 - **total_count**: 总数 - **page**: 当前页码 - **page_size**: 每页数量  **认证**: 需要X-API-TOKEN header
  ///
  /// Parameters:
  /// * [page] 
  /// * [pageSize] 
  /// * [X_API_TOKEN] 
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [NovelSyncListResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<NovelSyncListResponse>> listSyncedNovelsApiNovelSyncListGet({ 
    int? page = 1,
    int? pageSize = 20,
    String? X_API_TOKEN,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/novel/sync/list';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{
        r'X-API-TOKEN': X_API_TOKEN,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {
            'type': 'http',
            'scheme': 'bearer',
            'name': 'HTTPBearer',
          },
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (page != null) r'page': encodeQueryParameter(_serializers, page, const FullType(int)),
      if (pageSize != null) r'page_size': encodeQueryParameter(_serializers, pageSize, const FullType(int)),
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    NovelSyncListResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null ? null : _serializers.deserialize(
        rawResponse,
        specifiedType: const FullType(NovelSyncListResponse),
      ) as NovelSyncListResponse;

    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<NovelSyncListResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Upload Novel
  /// 上传小说数据到服务器.  接收APP端上传的完整小说数据，包括章节、角色、关系和大纲等信息。 服务器会根据source_url作为唯一标识存储数据，支持版本控制。  **请求参数:** - **device_id**: 设备标识（用于追踪同步来源） - **novel_data**: 完整的小说数据，包括：     - 基本信息（标题、作者、简介等）     - 章节列表（包括用户插入章节）     - 角色列表     - 角色关系列表     - 大纲列表 - **force_overwrite**: 是否强制覆盖服务器数据（默认false）  **返回值:** - **success**: 是否成功 - **message**: 响应消息 - **novel_id**: 小说ID - **sync_version**: 同步版本号（每次更新递增） - **synced_at**: 同步时间  **认证**: 需要X-API-TOKEN header
  ///
  /// Parameters:
  /// * [novelSyncUploadRequest] 
  /// * [X_API_TOKEN] 
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [NovelSyncUploadResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<NovelSyncUploadResponse>> uploadNovelApiNovelSyncUploadPost({ 
    required NovelSyncUploadRequest novelSyncUploadRequest,
    String? X_API_TOKEN,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/novel/sync/upload';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'X-API-TOKEN': X_API_TOKEN,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {
            'type': 'http',
            'scheme': 'bearer',
            'name': 'HTTPBearer',
          },
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(NovelSyncUploadRequest);
      _bodyData = _serializers.serialize(novelSyncUploadRequest, specifiedType: _type);

    } catch(error, stackTrace) {
      throw DioException(
         requestOptions: _options.compose(
          _dio.options,
          _path,
        ),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    NovelSyncUploadResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null ? null : _serializers.deserialize(
        rawResponse,
        specifiedType: const FullType(NovelSyncUploadResponse),
      ) as NovelSyncUploadResponse;

    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<NovelSyncUploadResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

}
