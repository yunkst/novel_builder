import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import '../../models/chat_scene.dart';
import '../../repositories/chat_scene_repository.dart';

part 'chat_scene_management_providers.g.dart';

/// 聊天场景管理状态
class ChatSceneManagementState {
  final List<ChatScene> scenes;
  final List<ChatScene> filteredScenes;
  final bool isLoading;
  final bool isSearching;
  final String searchQuery;

  const ChatSceneManagementState({
    this.scenes = const [],
    this.filteredScenes = const [],
    this.isLoading = true,
    this.isSearching = false,
    this.searchQuery = '',
  });

  ChatSceneManagementState copyWith({
    List<ChatScene>? scenes,
    List<ChatScene>? filteredScenes,
    bool? isLoading,
    bool? isSearching,
    String? searchQuery,
  }) {
    return ChatSceneManagementState(
      scenes: scenes ?? this.scenes,
      filteredScenes: filteredScenes ?? this.filteredScenes,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// ChatSceneManagement Provider
///
/// 提供聊天场景数据访问
@riverpod
ChatSceneRepository chatSceneRepository(Ref ref) {
  return ChatSceneRepository();
}

/// ChatSceneManagementState Provider
///
/// 管理聊天场景管理界面的状态
@riverpod
class ChatSceneManagement extends _$ChatSceneManagement {
  late ChatSceneRepository _repository;

  @override
  ChatSceneManagementState build() {
    // 获取 repository 实例
    _repository = ref.watch(chatSceneRepositoryProvider);

    // 初始化时加载数据
    Future.microtask(() => loadScenes());
    return const ChatSceneManagementState();
  }

  /// 加载所有场景
  Future<void> loadScenes() async {
    state = state.copyWith(isLoading: true);

    try {
      final scenes = await _repository.getAllChatScenes();

      state = state.copyWith(
        scenes: scenes,
        filteredScenes: scenes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// 添加新场景
  Future<void> addScene(ChatScene scene) async {
    await _repository.insertChatScene(scene);
    await loadScenes();
  }

  /// 更新场景
  Future<void> updateScene(ChatScene scene) async {
    await _repository.updateChatScene(scene);
    await loadScenes();
  }

  /// 删除场景
  Future<void> deleteScene(int id) async {
    await _repository.deleteChatScene(id);
    await loadScenes();
  }

  /// 搜索场景
  void searchScenes(String query) {
    if (query.isEmpty) {
      state = state.copyWith(
        filteredScenes: state.scenes,
        searchQuery: '',
      );
    } else {
      final lowerQuery = query.toLowerCase();
      final filtered = state.scenes.where((scene) {
        return scene.title.toLowerCase().contains(lowerQuery) ||
            scene.content.toLowerCase().contains(lowerQuery);
      }).toList();

      state = state.copyWith(
        filteredScenes: filtered,
        searchQuery: query,
      );
    }
  }

  /// 切换搜索状态
  void toggleSearch() {
    final newSearchingState = !state.isSearching;
    state = state.copyWith(
      isSearching: newSearchingState,
      searchQuery: newSearchingState ? state.searchQuery : '',
      filteredScenes: newSearchingState ? state.filteredScenes : state.scenes,
    );

    // 如果关闭搜索，清空搜索结果
    if (!newSearchingState) {
      state = state.copyWith(filteredScenes: state.scenes);
    }
  }
}
