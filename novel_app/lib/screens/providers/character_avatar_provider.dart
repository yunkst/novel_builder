import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/character_avatar_service.dart';

/// CharacterAvatarService Provider
///
/// 提供CharacterAvatarService单例实例
/// CharacterAvatarService负责角色头像管理
final characterAvatarServiceProvider = Provider<CharacterAvatarService>((ref) {
  return CharacterAvatarService();
});
