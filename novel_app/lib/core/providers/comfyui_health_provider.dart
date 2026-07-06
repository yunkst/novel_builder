/// ComfyUI 健康状态 Provider
///
/// app 运行期间探查一次后端 ComfyUI 健康（GET /text2img/health），
/// 结果缓存到 app 关闭。WritingScenario.tools 据此决定是否向 LLM
/// 注入 list_text2img_models / create_images 两个图片工具。
///
/// 使用旧式 FutureProvider（默认非 autoDispose = keepAlive），
/// 不依赖 build_runner。惰性触发：首次被 read 时才探测，整个 app
/// 生命周期只执行一次（符合"探一次，持久生效到 app 关闭"）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/logger_service.dart';
import 'services/network_service_providers.dart';

/// ComfyUI 是否健康（app 会话级缓存）。
///
/// 探测逻辑：
/// 1. 确保 ApiServiceWrapper 已 init（host/token 已加载）；失败 → false
/// 2. 调 checkComfyuiHealth()，3s 超时；失败/超时 → false
/// 3. status=="healthy" → true
final comfyuiHealthyProvider = FutureProvider<bool>((ref) async {
  final api = ref.read(apiServiceWrapperProvider);
  // 确保 host/token 已加载；未配置后端时 init 抛异常 → 视为不健康
  try {
    await api.init();
  } catch (e) {
    LoggerService.instance.d(
      'comfyuiHealthy: ApiServiceWrapper 未就绪，视为不健康 ($e)',
      category: LogCategory.network,
      tags: ['comfyui', 'health', 'api_not_ready'],
    );
    return false;
  }
  try {
    final (healthy, message) = await api
        .checkComfyuiHealth()
        .timeout(const Duration(seconds: 3));
    LoggerService.instance.i(
      'comfyuiHealthy 探测完成: healthy=$healthy ($message)',
      category: LogCategory.network,
      tags: ['comfyui', 'health', healthy ? 'healthy' : 'unhealthy'],
    );
    return healthy;
  } catch (e) {
    LoggerService.instance.d(
      'comfyuiHealthy 探测异常: $e',
      category: LogCategory.network,
      tags: ['comfyui', 'health', 'timeout_or_error'],
    );
    return false;
  }
});
