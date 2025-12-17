import '../errors/failure.dart';

/// 数据库相关错误
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DatabaseFailure &&
        other.message == message &&
        other.code == code;
  }

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}