import '../errors/failure.dart';

/// AI服务相关错误
class AIServiceFailure extends Failure {
  const AIServiceFailure(super.message, {super.code});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIServiceFailure &&
        other.message == message &&
        other.code == code;
  }

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}