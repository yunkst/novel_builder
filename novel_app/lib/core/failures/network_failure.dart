import '../errors/failure.dart';

/// 网络相关错误
class NetworkFailure extends Failure {
  final int? statusCode;

  const NetworkFailure(super.message, {this.statusCode, super.code});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkFailure &&
        other.message == message &&
        other.statusCode == statusCode &&
        other.code == code;
  }

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode ^ code.hashCode;
}