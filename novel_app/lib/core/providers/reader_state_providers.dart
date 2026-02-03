/// Riverpod Reader State Providers
///
/// 细粒度的阅读器状态管理Provider
/// 用于替代Controller的setState回调，实现选择性Widget重建
///
/// 设计原则：
/// 1. 每个Provider只管理一个明确的状态领域
/// 2. 状态更新只影响监听该Provider的Widget
/// 3. 避免全屏setState导致的性能问题
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../models/ai_companion_response.dart';
import '../../services/api_service_wrapper.dart';
import '../interfaces/repositories/i_chapter_repository.dart';

part 'reader_state_providers.g.dart';

/// ChapterContentState
///
/// 章节内容加载状态
class ChapterContentState {
  final String content;
  final bool isLoading;
  final String errorMessage;
  final Chapter? currentChapter;
  final Novel? currentNovel;

  const ChapterContentState({
    this.content = '',
    this.isLoading = false,
    this.errorMessage = '',
    this.currentChapter,
    this.currentNovel,
  });

  ChapterContentState copyWith({
    String? content,
    bool? isLoading,
    String? errorMessage,
    Chapter? currentChapter,
    Novel? currentNovel,
    bool clearCurrentChapter = false,
    bool clearCurrentNovel = false,
  }) {
    return ChapterContentState(
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      currentChapter: clearCurrentChapter ? null : (currentChapter ?? this.currentChapter),
      currentNovel: clearCurrentNovel ? null : (currentNovel ?? this.currentNovel),
    );
  }
}

/// ChapterContentStateNotifier
///
/// 管理章节内容的加载状态
@riverpod
class ChapterContentStateNotifier extends _$ChapterContentStateNotifier {
  @override
  ChapterContentState build() {
    return const ChapterContentState();
  }

  /// 设置加载状态
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// 设置内容
  void setContent(String content) {
    state = state.copyWith(content: content);
  }

  /// 设置当前章节和小说
  void setCurrentContext(Chapter chapter, Novel novel) {
    state = state.copyWith(currentChapter: chapter, currentNovel: novel);
  }

  /// 设置错误信息
  void setError(String error) {
    state = state.copyWith(errorMessage: error, isLoading: false);
  }

  /// 清空内容（用于章节切换）
  void clearContent() {
    state = state.copyWith(content: '');
  }

  /// 清空所有状态
  void clear() {
    state = const ChapterContentState();
  }

  /// 更新内容（用于改写等场景）
  void updateContent(String newContent) {
    state = state.copyWith(content: newContent);
  }
}

/// ReadingProgressState
///
/// 阅读进度状态
class ReadingProgressState {
  final double scrollPosition;
  final int characterIndex;
  final int firstVisibleParagraphIndex;

  const ReadingProgressState({
    this.scrollPosition = 0.0,
    this.characterIndex = 0,
    this.firstVisibleParagraphIndex = 0,
  });

  ReadingProgressState copyWith({
    double? scrollPosition,
    int? characterIndex,
    int? firstVisibleParagraphIndex,
  }) {
    return ReadingProgressState(
      scrollPosition: scrollPosition ?? this.scrollPosition,
      characterIndex: characterIndex ?? this.characterIndex,
      firstVisibleParagraphIndex: firstVisibleParagraphIndex ?? this.firstVisibleParagraphIndex,
    );
  }
}

/// ReadingProgressStateNotifier
///
/// 管理阅读进度（滚动位置、字符索引等）
@riverpod
class ReadingProgressStateNotifier extends _$ReadingProgressStateNotifier {
  @override
  ReadingProgressState build() {
    return const ReadingProgressState();
  }

  /// 更新滚动位置
  void updateScrollPosition(double position) {
    state = state.copyWith(scrollPosition: position);
  }

  /// 更新字符索引
  void updateCharacterIndex(int index) {
    state = state.copyWith(characterIndex: index);
  }

  /// 更新第一可见段落索引
  void updateFirstVisibleParagraphIndex(int index) {
    state = state.copyWith(firstVisibleParagraphIndex: index);
  }

  /// 重置进度
  void reset() {
    state = const ReadingProgressState();
  }
}

/// InteractionState
///
/// 用户交互状态（特写模式、段落选择等）
class InteractionState {
  final bool isCloseupMode;
  final List<int> selectedParagraphIndices;

  const InteractionState({
    this.isCloseupMode = false,
    this.selectedParagraphIndices = const [],
  });

  InteractionState copyWith({
    bool? isCloseupMode,
    List<int>? selectedParagraphIndices,
  }) {
    return InteractionState(
      isCloseupMode: isCloseupMode ?? this.isCloseupMode,
      selectedParagraphIndices: selectedParagraphIndices ?? this.selectedParagraphIndices,
    );
  }

  /// 是否有选中的段落
  bool get hasSelection => selectedParagraphIndices.isNotEmpty;

  /// 选中的段落数量
  int get selectionCount => selectedParagraphIndices.length;
}

/// InteractionStateNotifier
///
/// 管理用户交互状态
@riverpod
class InteractionStateNotifier extends _$InteractionStateNotifier {
  @override
  InteractionState build() {
    return const InteractionState();
  }

  /// 切换特写模式
  void toggleCloseupMode({bool clearSelection = true}) {
    final newMode = !state.isCloseupMode;
    state = InteractionState(
      isCloseupMode: newMode,
      selectedParagraphIndices: (!newMode && clearSelection) ? [] : state.selectedParagraphIndices,
    );
  }

  /// 设置特写模式
  void setCloseupMode(bool value, {bool clearSelection = true}) {
    if (state.isCloseupMode != value) {
      state = InteractionState(
        isCloseupMode: value,
        selectedParagraphIndices: (!value && clearSelection) ? [] : state.selectedParagraphIndices,
      );
    }
  }

  /// 处理段落点击
  void handleParagraphTap(int index, List<String> paragraphs, {bool isMediaMarkup = false}) {
    if (!state.isCloseupMode) return;

    // 媒体标记段落不允许选择
    if (isMediaMarkup) {
      return;
    }

    final newSelection = List<int>.from(state.selectedParagraphIndices);

    if (newSelection.contains(index)) {
      newSelection.remove(index);
    } else {
      newSelection.add(index);
      newSelection.sort();

      // 检查是否连续
      if (!_isConsecutive(newSelection)) {
        // 不连续则只保留当前点击的段落
        newSelection.clear();
        newSelection.add(index);
      }
    }

    state = state.copyWith(selectedParagraphIndices: newSelection);
  }

  /// 清除段落选择
  void clearSelection() {
    if (state.selectedParagraphIndices.isNotEmpty) {
      state = state.copyWith(selectedParagraphIndices: []);
    }
  }

  /// 批量设置选中的段落
  void setSelectedParagraphIndices(List<int> indices) {
    state = state.copyWith(selectedParagraphIndices: List.from(indices));
  }

  /// 检查数组是否连续
  bool _isConsecutive(List<int> indices) {
    if (indices.length <= 1) return true;

    for (int i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) {
        return false;
      }
    }

    return true;
  }

  /// 获取选中的文本
  String getSelectedText(List<String> paragraphs) {
    if (state.selectedParagraphIndices.isEmpty) {
      return '';
    }

    final selectedTexts = <String>[];

    for (final index in state.selectedParagraphIndices) {
      if (index < 0 || index >= paragraphs.length) {
        continue;
      }

      selectedTexts.add(paragraphs[index].trim());
    }

    return selectedTexts.join('\n\n');
  }
}

/// AICompanionState
///
/// AI伴读状态
class AICompanionState {
  final bool isGenerating;
  final AICompanionResponse? response;
  final String? errorMessage;

  const AICompanionState({
    this.isGenerating = false,
    this.response,
    this.errorMessage,
  });

  AICompanionState copyWith({
    bool? isGenerating,
    AICompanionResponse? response,
    String? errorMessage,
    bool clearResponse = false,
    bool clearError = false,
  }) {
    return AICompanionState(
      isGenerating: isGenerating ?? this.isGenerating,
      response: clearResponse ? null : (response ?? this.response),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// AICompanionStateNotifier
///
/// 管理AI伴读状态
@riverpod
class AICompanionStateNotifier extends _$AICompanionStateNotifier {
  @override
  AICompanionState build() {
    return const AICompanionState();
  }

  /// 设置生成状态
  void setGenerating(bool value) {
    state = state.copyWith(isGenerating: value);
  }

  /// 设置响应结果
  void setResponse(AICompanionResponse? response) {
    state = state.copyWith(response: response, isGenerating: false);
  }

  /// 设置错误信息
  void setError(String error) {
    state = state.copyWith(errorMessage: error, isGenerating: false);
  }

  /// 清空响应
  void clearResponse() {
    state = state.copyWith(clearResponse: true);
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 重置状态
  void reset() {
    state = const AICompanionState();
  }
}

/// CharacterCardUpdateState
///
/// 角色卡更新状态
class CharacterCardUpdateState {
  final bool isUpdating;
  final String? errorMessage;

  const CharacterCardUpdateState({
    this.isUpdating = false,
    this.errorMessage,
  });

  CharacterCardUpdateState copyWith({
    bool? isUpdating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CharacterCardUpdateState(
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// CharacterCardUpdateStateNotifier
///
/// 管理角色卡更新状态
@riverpod
class CharacterCardUpdateStateNotifier extends _$CharacterCardUpdateStateNotifier {
  @override
  CharacterCardUpdateState build() {
    return const CharacterCardUpdateState();
  }

  /// 设置更新状态
  void setUpdating(bool value) {
    state = state.copyWith(isUpdating: value);
  }

  /// 设置错误信息
  void setError(String error) {
    state = state.copyWith(errorMessage: error, isUpdating: false);
  }

  /// 清空错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 重置状态
  void reset() {
    state = const CharacterCardUpdateState();
  }
}

/// ModelSizeState
///
/// 模型尺寸状态
class ModelSizeState {
  final int? width;
  final int? height;

  const ModelSizeState({
    this.width,
    this.height,
  });

  ModelSizeState copyWith({
    int? width,
    int? height,
  }) {
    return ModelSizeState(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// ModelSizeStateNotifier
///
/// 管理默认T2I模型尺寸
@riverpod
class ModelSizeStateNotifier extends _$ModelSizeStateNotifier {
  @override
  ModelSizeState build() {
    return const ModelSizeState();
  }

  /// 设置模型尺寸
  void setSize(int? width, int? height) {
    state = ModelSizeState(width: width, height: height);
  }

  /// 重置为默认尺寸
  void resetToDefault() {
    state = const ModelSizeState(width: 704, height: 1280);
  }

  /// 清空尺寸
  void clear() {
    state = const ModelSizeState();
  }
}
