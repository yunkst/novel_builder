import 'package:dio/dio.dart';
import '../failures/network_failure.dart';
import '../utils/result.dart';

/// 统一的API客户端
class ApiClient {
  late Dio _dio;

  ApiClient({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Map<String, String>? headers,
    List<Interceptor>? interceptors,
  }) {
    _dio = Dio(BaseOptions(
      connectTimeout: connectTimeout ?? const Duration(seconds: 30),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
      headers: headers,
    ));

    // 添加默认拦截器
    _dio.interceptors.addAll([
      LogInterceptor(
        request: true,
        requestHeader: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
      ...?interceptors,
    ]);
  }

  /// 设置基础URL
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  /// 设置请求头
  void setHeaders(Map<String, String> headers) {
    _dio.options.headers.addAll(headers);
  }

  /// 设置认证token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 清除认证token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// GET请求
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? parser,
  }) async {
    return _handleRequest<T>(
      () => _dio.get(path, queryParameters: queryParameters, options: options),
      parser: parser,
    );
  }

  /// POST请求
  Future<Result<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? parser,
  }) async {
    return _handleRequest<T>(
      () => _dio.post(path, data: data, queryParameters: queryParameters, options: options),
      parser: parser,
    );
  }

  /// PUT请求
  Future<Result<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? parser,
  }) async {
    return _handleRequest<T>(
      () => _dio.put(path, data: data, queryParameters: queryParameters, options: options),
      parser: parser,
    );
  }

  /// DELETE请求
  Future<Result<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic data)? parser,
  }) async {
    return _handleRequest<T>(
      () => _dio.delete(path, data: data, queryParameters: queryParameters, options: options),
      parser: parser,
    );
  }

  /// 通用请求处理
  Future<Result<T>> _handleRequest<T>(
    Future<Response> Function() requestFunction, {
    T Function(dynamic data)? parser,
  }) async {
    try {
      final response = await requestFunction();

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {

        // 如果没有提供解析器，尝试直接返回数据
        if (parser == null) {
          if (response.data is T) {
            return Result.success(response.data as T);
          } else if (T == String) {
            return Result.success(response.data.toString()) as Result<T>;
          } else {
            return Result.failure(
              NetworkFailure(
                'Invalid response data type',
                statusCode: response.statusCode,
              ),
            );
          }
        } else {
          try {
            final parsedData = parser(response.data);
            return Result.success(parsedData);
          } catch (e) {
            return Result.failure(
              NetworkFailure(
                'Failed to parse response data: $e',
                statusCode: response.statusCode,
              ),
            );
          }
        }
      } else {
        return Result.failure(
          NetworkFailure(
            response.statusMessage ?? 'Unknown error',
            statusCode: response.statusCode,
          ),
        );
      }
    } on DioException catch (e) {
      return Result.failure(_convertDioException(e));
    } catch (e) {
      return Result.failure(
        NetworkFailure('Unexpected error: $e'),
      );
    }
  }

  /// 转换Dio异常为NetworkFailure
  NetworkFailure _convertDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkFailure('Connection timeout');
      case DioExceptionType.sendTimeout:
        return const NetworkFailure('Send timeout');
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('Receive timeout');
      case DioExceptionType.badResponse:
        return NetworkFailure(
          e.message ?? 'Bad response',
          statusCode: e.response?.statusCode,
        );
      case DioExceptionType.cancel:
        return const NetworkFailure('Request cancelled');
      case DioExceptionType.connectionError:
        return const NetworkFailure('Connection error');
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Bad SSL certificate');
      case DioExceptionType.unknown:
        return NetworkFailure('Network error: ${e.message}');
    }
  }

  /// 取消所有请求
  void cancelRequests([CancelToken? token]) {
    token?.cancel('Request cancelled');
  }

  /// 获取Dio实例（用于特殊需求）
  Dio get dio => _dio;
}