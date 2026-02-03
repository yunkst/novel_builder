import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/character_avatar_service.dart';
import '../../core/providers/services/cache_service_providers.dart';
import '../../core/providers/database_providers.dart';

/// CharacterAvatarService Provider
///
/// 提供CharacterAvatarService单例实例
/// CharacterAvatarService负责角色头像管理
/// @deprecated 请使用 cache_service_providers.dart 中的 characterAvatarServiceProvider
@Deprecated('请使用 cache_service_providers.dart 中的 characterAvatarServiceProvider')
final characterAvatarServiceProvider = Provider<CharacterAvatarService>((ref) {
  final cacheService = ref.watch(characterImageCacheServiceProvider);
  final databaseService = ref.watch(databaseServiceProvider);
  return CharacterAvatarService(
    databaseService: databaseService,
    cacheService: cacheService,
  );
});
