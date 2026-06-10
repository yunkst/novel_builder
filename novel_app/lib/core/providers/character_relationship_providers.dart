import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../models/character_relationship.dart';
import '../../services/logger_service.dart';
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
  LoggerService.instance.d(
    '开始添加角色关系: ${relationship.sourceCharacterId} -> ${relationship.targetCharacterId}',
    category: LogCategory.database,
    tags: ['provider', 'character-relationship', 'add'],
  );
  try {
    final repository = ref.watch(characterRelationRepositoryProvider);
    await repository.createRelationship(relationship);
    LoggerService.instance.i(
      '角色关系添加成功',
      category: LogCategory.ui,
      tags: ['provider', 'character-relationship', 'add'],
    );
    return true;
  } catch (e, st) {
    LoggerService.instance.e(
      '添加角色关系失败: $e',
      stackTrace: st.toString(),
      category: LogCategory.database,
      tags: ['provider', 'character-relationship', 'add'],
    );
    return false;
  }
});

/// 更新关系操作Provider
///
/// 返回成功(true)或失败(false)
final updateRelationshipProvider = FutureProvider.autoDispose
    .family<bool, CharacterRelationship>((ref, relationship) async {
  LoggerService.instance.d(
    '开始更新角色关系: id=${relationship.id}',
    category: LogCategory.database,
    tags: ['provider', 'character-relationship', 'update'],
  );
  try {
    final repository = ref.watch(characterRelationRepositoryProvider);
    await repository.updateRelationship(relationship);
    LoggerService.instance.i(
      '角色关系更新成功',
      category: LogCategory.ui,
      tags: ['provider', 'character-relationship', 'update'],
    );
    return true;
  } catch (e, st) {
    LoggerService.instance.e(
      '更新角色关系失败: $e',
      stackTrace: st.toString(),
      category: LogCategory.database,
      tags: ['provider', 'character-relationship', 'update'],
    );
    return false;
  }
});

/// 删除关系操作Provider
///
/// 返回成功(true)或失败(false)
final deleteRelationshipProvider =
    FutureProvider.autoDispose.family<bool, int>((ref, relationshipId) async {
  LoggerService.instance.d(
    '开始删除角色关系: id=$relationshipId',
    category: LogCategory.database,
    tags: ['provider', 'character-relationship', 'delete'],
  );
  try {
    final repository = ref.watch(characterRelationRepositoryProvider);
    await repository.deleteRelationship(relationshipId);
    LoggerService.instance.i(
      '角色关系删除成功',
      category: LogCategory.ui,
      tags: ['provider', 'character-relationship', 'delete'],
    );
    return true;
  } catch (e, st) {
    LoggerService.instance.e(
      '删除角色关系失败: $e',
      stackTrace: st.toString(),
      category: LogCategory.database,
      tags: ['provider', 'character-relationship', 'delete'],
    );
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
