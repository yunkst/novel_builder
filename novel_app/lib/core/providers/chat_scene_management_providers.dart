import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/chat_scene.dart';
import '../../services/logger_service.dart';
import '../interfaces/repositories/i_chat_scene_repository.dart';
import 'database_providers.dart';

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

/// ChatSceneManagementState Provider
///
/// 管理聊天场景管理界面的状态
@riverpod
class ChatSceneManagement extends _$ChatSceneManagement {
  late IChatSceneRepository _repository;

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
    LoggerService.instance.d(
      '开始加载聊天场景',
      category: LogCategory.database,
      tags: ['provider', 'chat-scene', 'load'],
    );
    state = state.copyWith(isLoading: true);

    try {
      final scenes = await _repository.getAllChatScenes();

      state = state.copyWith(
        scenes: scenes,
        filteredScenes: scenes,
        isLoading: false,
      );
      LoggerService.instance.i(
        '聊天场景加载成功: count=${scenes.length}',
        category: LogCategory.ui,
        tags: ['provider', 'chat-scene', 'load'],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        '加载聊天场景失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['provider', 'chat-scene', 'load'],
      );
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// 添加新场景
  Future<void> addScene(ChatScene scene) async {
    LoggerService.instance.d(
      '添加聊天场景: title=${scene.title}',
      category: LogCategory.database,
      tags: ['provider', 'chat-scene', 'add'],
    );
    try {
      await _repository.insertChatScene(scene);
      LoggerService.instance.i(
        '聊天场景添加成功: ${scene.title}',
        category: LogCategory.ui,
        tags: ['provider', 'chat-scene', 'add'],
      );
      await loadScenes();
    } catch (e, st) {
      LoggerService.instance.e(
        '添加聊天场景失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['provider', 'chat-scene', 'add'],
      );
      rethrow;
    }
  }

  /// 更新场景
  Future<void> updateScene(ChatScene scene) async {
    LoggerService.instance.d(
      '更新聊天场景: id=${scene.id}, title=${scene.title}',
      category: LogCategory.database,
      tags: ['provider', 'chat-scene', 'update'],
    );
    try {
      await _repository.updateChatScene(scene);
      LoggerService.instance.i(
        '聊天场景更新成功: ${scene.title}',
        category: LogCategory.ui,
        tags: ['provider', 'chat-scene', 'update'],
      );
      await loadScenes();
    } catch (e, st) {
      LoggerService.instance.e(
        '更新聊天场景失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['provider', 'chat-scene', 'update'],
      );
      rethrow;
    }
  }

  /// 删除场景
  Future<void> deleteScene(int id) async {
    LoggerService.instance.d(
      '删除聊天场景: id=$id',
      category: LogCategory.database,
      tags: ['provider', 'chat-scene', 'delete'],
    );
    try {
      await _repository.deleteChatScene(id);
      LoggerService.instance.i(
        '聊天场景删除成功: id=$id',
        category: LogCategory.ui,
        tags: ['provider', 'chat-scene', 'delete'],
      );
      await loadScenes();
    } catch (e, st) {
      LoggerService.instance.e(
        '删除聊天场景失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['provider', 'chat-scene', 'delete'],
      );
      rethrow;
    }
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
