import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/dify_service.dart';

/// DifyService Provider
///
/// 提供DifyService单例实例
/// DifyService负责AI对话和内容生成
final difyServiceProvider = Provider<DifyService>((ref) {
  return DifyService();
});
