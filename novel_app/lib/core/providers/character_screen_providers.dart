/// Riverpod Character Screen Providers
///
/// 此文件定义角色管理相关屏幕所需的 Provider
/// 使用 @riverpod 注解自动生成代码
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../models/novel.dart';
import '../../models/character.dart';
import '../../services/character_image_cache_service.dart';
import 'database_providers.dart';

part 'character_screen_providers.g.dart';

/// CharacterImageCacheService Provider
///
/// 提供角色图片缓存服务实例
/// 使用 keepAlive: true 确保实例不会被销毁（单例模式）
@Riverpod(keepAlive: true)
CharacterImageCacheService characterImageCacheService(
  CharacterImageCacheServiceRef ref,
) {
  final service = CharacterImageCacheService();

  // 注意：初始化需要在首次使用时手动调用，或在外部初始化
  // 这里不自动初始化，避免 ProviderRef 没有 onFuture 方法的问题

  return service;
}

/// CharacterManagement Screen State
///
/// 管理角色列表屏幕的状态
@riverpod
class CharacterManagementState extends _$CharacterManagementState {
  @override
  Future<List<Character>> build(Novel novel) async {
    final repository = ref.watch(characterRepositoryProvider);
    final characters = await repository.getCharacters(novel.url);

    // 加载每个角色的关系数量
    final relationRepo = ref.watch(characterRelationRepositoryProvider);
    for (final character in characters) {
      if (character.id != null) {
        try {
          await relationRepo.getRelationshipCount(character.id!);
          // 关系数量缓存可以在外部处理
        } catch (e) {
          // 忽略错误
        }
      }
    }

    return characters;
  }

  /// 重新加载角色列表
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(characterRepositoryProvider);
      return await repository.getCharacters(novel.url);
    });
  }

  /// 删除角色
  Future<void> deleteCharacter(int characterId) async {
    final repository = ref.read(characterRepositoryProvider);
    await repository.deleteCharacter(characterId);

    // 刷新列表
    await refresh();
  }

  /// 批量删除角色
  Future<void> deleteCharacters(List<int> characterIds) async {
    final repository = ref.read(characterRepositoryProvider);
    for (final id in characterIds) {
      await repository.deleteCharacter(id);
    }

    // 刷新列表
    await refresh();
  }

  /// 创建角色
  Future<void> createCharacter(Character character) async {
    final repository = ref.read(characterRepositoryProvider);
    await repository.createCharacter(character);

    // 刷新列表
    await refresh();
  }
}

/// 角色关系数量缓存 Provider
///
/// 为每个角色缓存关系数量
@riverpod
Map<int, int> relationshipCountCache(Ref ref) {
  return {};
}

/// Outline 状态 Provider
///
/// 检查小说是否有大纲
@riverpod
Future<bool?> hasOutline(HasOutlineRef ref, String novelUrl) async {
  final repository = ref.watch(outlineRepositoryProvider);
  final outline = await repository.getOutlineByNovelUrl(novelUrl);
  return outline != null;
}

/// CharacterEdit Controller Provider
///
/// 管理角色编辑的状态和逻辑
/// 包括自动保存功能
@riverpod
class CharacterEditController extends _$CharacterEditController {
  @override
  FutureOr<Character?> build({
    required Novel novel,
    Character? character,
  }) async {
    // 如果有传入角色，直接返回
    if (character != null) {
      return character;
    }

    // 新建模式，返回 null
    return null;
  }

  /// 保存角色（新建或更新）
  Future<bool> saveCharacter({
    required String name,
    int? age,
    String? gender,
    String? occupation,
    String? personality,
    String? bodyType,
    String? clothingStyle,
    String? appearanceFeatures,
    String? backgroundStory,
    String? facePrompts,
    String? bodyPrompts,
    List<String>? aliases,
  }) async {
    try {
      final repository = ref.read(characterRepositoryProvider);

      final characterData = Character(
        id: state.value?.id,
        novelUrl: novel.url,
        name: name,
        age: age,
        gender: gender,
        occupation: occupation,
        personality: personality,
        bodyType: bodyType,
        clothingStyle: clothingStyle,
        appearanceFeatures: appearanceFeatures,
        backgroundStory: backgroundStory,
        facePrompts: facePrompts,
        bodyPrompts: bodyPrompts,
        aliases: aliases,
        cachedImageUrl: state.value?.cachedImageUrl,
      );

      if (state.value == null) {
        // 新建角色
        await repository.createCharacter(characterData);
        // 注意：createCharacter 返回的是 int (新ID)，但我们的 state 是 Character?
        // 所以这里不更新 state，让调用方处理
      } else {
        // 更新角色
        await repository.updateCharacter(characterData);
        state = AsyncValue.data(characterData);
      }

      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// 自动保存（用于提示词生成后）
  Future<void> autoSave({
    required String name,
    String? facePrompts,
    String? bodyPrompts,
  }) async {
    if (state.value == null) {
      // 新建模式：先创建基础角色
      await saveCharacter(
        name: name,
        facePrompts: facePrompts,
        bodyPrompts: bodyPrompts,
      );
    } else {
      // 编辑模式：只更新提示词
      final current = state.value!;
      await saveCharacter(
        name: current.name,
        age: current.age,
        gender: current.gender,
        occupation: current.occupation,
        personality: current.personality,
        bodyType: current.bodyType,
        clothingStyle: current.clothingStyle,
        appearanceFeatures: current.appearanceFeatures,
        backgroundStory: current.backgroundStory,
        facePrompts: facePrompts,
        bodyPrompts: bodyPrompts,
        aliases: current.aliases,
      );
    }
  }

  /// 重新加载角色数据
  Future<void> refresh() async {
    if (state.value?.id == null) return;

    final repository = ref.read(characterRepositoryProvider);
    final characters = await repository.getCharacters(novel.url);
    final updated = characters.firstWhere(
      (c) => c.id == state.value!.id,
      orElse: () => state.value!,
    );

    state = AsyncValue.data(updated);
  }
}

/// 自动保存状态 Provider
///
/// 跟踪是否正在自动保存
@riverpod
class AutoSaveState extends _$AutoSaveState {
  @override
  bool build() => false;

  void setSaving(bool saving) {
    state = saving;
  }
}

/// 多选模式状态 Provider
///
/// 管理角色列表的多选状态
@riverpod
class MultiSelectMode extends _$MultiSelectMode {
  @override
  bool build() => false;

  void enterMode(int firstCharacterId) {
    state = true;
    ref.read(selectedCharacterIdsProvider.notifier).add(firstCharacterId);
  }

  void exitMode() {
    state = false;
    ref.read(selectedCharacterIdsProvider.notifier).clear();
  }

  void toggle() {
    state = !state;
    if (!state) {
      ref.read(selectedCharacterIdsProvider.notifier).clear();
    }
  }
}

/// 已选角色ID集合 Provider
///
/// 管理已选中的角色ID列表
@riverpod
class SelectedCharacterIds extends _$SelectedCharacterIds {
  @override
  Set<int> build() => {};

  void add(int characterId) {
    state = {...state, characterId};
  }

  void remove(int characterId) {
    final newState = {...state};
    newState.remove(characterId);
    state = newState;
  }

  void toggle(int characterId) {
    if (state.contains(characterId)) {
      remove(characterId);
    } else {
      add(characterId);
    }
  }

  void clear() {
    state = {};
  }
}
