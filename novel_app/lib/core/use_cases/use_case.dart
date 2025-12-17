import '../utils/result.dart';

/// UseCase抽象类 - 封装单个业务逻辑
///
/// [T] - 返回类型
/// [P] - 参数类型，如果没有参数使用NoParams
abstract class UseCase<T, P> {
  /// 执行用例
  Future<Result<T>> call(P params);
}

/// 无参数的标记类
class NoParams {
  const NoParams();
}