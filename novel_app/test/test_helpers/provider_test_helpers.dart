import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lib/services/database_service.dart';
import '../../lib/core/providers/database_providers.dart';

/// 测试工具函数
///
/// 提供标准化的 Provider 容器创建方法，用于单元测试和 Widget 测试

/// 创建测试用的 ProviderContainer
///
/// [databaseService] 可选的 Mock DatabaseService
/// [keepAlive] 是否保持容器活跃（默认false）
///
/// 返回配置好的 ProviderContainer，记得在使用后调用 dispose()
ProviderContainer createTestContainer({
  required DatabaseService databaseService,
  bool keepAlive = false,
}) {
  return ProviderContainer(
    overrides: [
      databaseServiceProvider.overrideWithValue(databaseService),
    ],
  );
}
