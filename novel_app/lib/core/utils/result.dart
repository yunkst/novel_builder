import '../errors/failure.dart';
import '../failures/cache_failure.dart';

/// 通用结果类型，用于处理可能失败的操作
class Result<T> {
  final T? data;
  final Failure? failure;

  Result._({this.data, this.failure});

  /// 创建成功结果
  factory Result.success(T data) => Result._(data: data);

  /// 创建失败结果
  factory Result.failure(Failure failure) => Result._(failure: failure);

  /// 是否成功
  bool get isSuccess => failure == null && data != null;

  /// 是否失败
  bool get isFailure => failure != null;

  /// 获取数据或抛出异常
  T get dataOrThrow {
    if (data != null) return data as T;
    throw failure ?? Exception('Unknown error');
  }

  /// 安全获取数据
  T? get dataOrNull => data;

  /// 获取错误或null
  Failure? get failureOrNull => failure;

  /// 映射数据
  Result<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      try {
        return Result.success(mapper(data as T));
      } catch (e) {
        return Result.failure(
          CacheFailure('Data mapping failed: $e'),
        );
      }
    }
    return Result.failure(failure!);
  }

  /// 链式处理
  Result<R> flatMap<R>(Result<R> Function(T data) mapper) {
    if (isSuccess && data != null) {
      return mapper(data as T);
    }
    return Result.failure(failure!);
  }

  /// 当失败时的回调
  Result<T> onFailure(void Function(Failure failure) callback) {
    if (isFailure && failure != null) {
      callback(failure as Failure);
    }
    return this;
  }

  /// 当成功时的回调
  Result<T> onSuccess(void Function(T data) callback) {
    if (isSuccess && data != null) {
      callback(data as T);
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Result<T> &&
        other.data == data &&
        other.failure == failure;
  }

  @override
  int get hashCode => data.hashCode ^ failure.hashCode;

  @override
  String toString() => 'Result(data: $data, failure: $failure)';
}

/// Result类型扩展方法
extension ResultExtensions<T> on Future<Result<T>> {
  /// 当失败时的异步回调
  Future<Result<T>> onFailureAsync(void Function(Failure failure) callback) async {
    final result = await this;
    if (result.isFailure && result.failure != null) {
      callback(result.failure as Failure);
    }
    return result;
  }

  /// 当成功时的异步回调
  Future<Result<T>> onSuccessAsync(void Function(T data) callback) async {
    final result = await this;
    if (result.isSuccess && result.data != null) {
      callback(result.data as T);
    }
    return result;
  }
}