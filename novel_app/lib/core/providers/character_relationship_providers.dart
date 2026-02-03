import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../models/character_relationship.dart';
import 'database_providers.dart';

/// 角色关系Screen的Riverpod Providers
///
/// 提供角色关系管理所需的状态和业务逻辑

/// 出度关系列表Provider（Ta → 其他人）
final outgoingRelationshipsProvider =
    FutureProvider.autoDispose.family<List<CharacterRelationship>, int>(
  (ref, characterId) async {
    final repository = ref.watch(characterRelationRepositoryProvider);
    return repository.getOutgoingRelationships(characterId);
  },
);

/// 入度关系列表Provider（其他人 → Ta）
final incomingRelationshipsProvider =
    FutureProvider.autoDispose.family<List<CharacterRelationship>, int>(
  (ref, characterId) async {
    final repository = ref.watch(characterRelationRepositoryProvider);
    return repository.getIncomingRelationships(characterId);
  },
);

/// 关系列表加载状态Provider
class RelationshipListState extends Equatable {
  final bool isLoading;
  final String? error;

  const RelationshipListState({
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [isLoading, error];
}

class RelationshipListStateNotifier
    extends StateNotifier<RelationshipListState> {
  RelationshipListStateNotifier() : super(const RelationshipListState());

  void setLoading(bool loading) {
    state = RelationshipListState(isLoading: loading);
  }

  void setError(String? error) {
    state = RelationshipListState(
      isLoading: false,
      error: error,
    );
  }

  void reset() {
    state = const RelationshipListState();
  }
}

final relationshipListStateProvider = StateNotifierProvider.autoDispose<
    RelationshipListStateNotifier, RelationshipListState>(
  (ref) => RelationshipListStateNotifier(),
);

/// 添加关系操作Provider
///
/// 返回成功(true)或失败(false)
final addRelationshipProvider = FutureProvider.autoDispose
    .family<bool, CharacterRelationship>((ref, relationship) async {
  try {
    final repository = ref.watch(characterRelationRepositoryProvider);
    await repository.createRelationship(relationship);
    return true;
  } catch (e) {
    return false;
  }
});

/// 更新关系操作Provider
///
/// 返回成功(true)或失败(false)
final updateRelationshipProvider = FutureProvider.autoDispose
    .family<bool, CharacterRelationship>((ref, relationship) async {
  try {
    final repository = ref.watch(characterRelationRepositoryProvider);
    await repository.updateRelationship(relationship);
    return true;
  } catch (e) {
    return false;
  }
});

/// 删除关系操作Provider
///
/// 返回成功(true)或失败(false)
final deleteRelationshipProvider =
    FutureProvider.autoDispose.family<bool, int>((ref, relationshipId) async {
  try {
    final repository = ref.watch(characterRelationRepositoryProvider);
    await repository.deleteRelationship(relationshipId);
    return true;
  } catch (e) {
    return false;
  }
});

/// 刷新关系数据辅助函数
///
/// 使出度/入度关系Provider失效，触发重新加载
void invalidateRelationshipProviders(WidgetRef ref, int characterId) {
  ref.invalidate(outgoingRelationshipsProvider(characterId));
  ref.invalidate(incomingRelationshipsProvider(characterId));
}
