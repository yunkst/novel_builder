import '../errors/failure.dart';

/// 缓存相关错误
class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CacheFailure &&
        other.message == message &&
        other.code == code;
  }

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}