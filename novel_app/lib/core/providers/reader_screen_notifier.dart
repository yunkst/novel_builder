/// ReaderScreen Notifier
///
/// 负责管理阅读器屏幕的业务逻辑和状态
/// 包括对话框管理、AI伴读、章节导航等功能
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';
import '../../models/ai_companion_response.dart';
import '../../models/ai_accompaniment_settings.dart';
import '../../models/character.dart';
import '../../models/character_relationship.dart';
import '../../services/dify_service.dart';
import '../../services/novel_context_service.dart';
import '../../utils/character_matcher.dart';
import '../../core/interfaces/repositories/i_chapter_repository.dart';
import '../../core/interfaces/repositories/i_novel_repository.dart';
import '../../core/interfaces/repositories/i_character_repository.dart';
import '../../core/interfaces/repositories/i_character_relation_repository.dart';
import 'service_providers.dart';
import 'database_providers.dart';
import 'reader_screen_providers.dart';

part 'reader_screen_notifier.g.dart';

// ========== 辅助函数：获取背景设定追加内容 ==========
Future<String> _appendBackgroundSetting(
  INovelRepository novelRepo,
  String novelUrl,
  String newBackground,
) async {
  final currentBackground = await novelRepo.getBackgroundSetting(novelUrl);
  return currentBackground == null || currentBackground.isEmpty
      ? newBackground
      : '$currentBackground\n\n$newBackground';
}

/// ReaderScreen 状态
///
/// 管理阅读器屏幕的各种状态变化
class ReaderScreenState {
  /// 对话框显示状态
  final bool showAICompanionDialog;
  final bool showEditDialog;
  final bool showIllustrationDialog;

  /// 加载状态
  final bool isLoading;
  final bool isUpdatingRoleCards;

  /// AI伴读状态
  final bool hasAutoTriggered;
  final bool isAutoCompanionRunning;

  /// 错误信息
  final String errorMessage;

  /// 对话框数据（用于传递AI伴读结果等）
  final AICompanionResponse? aiCompanionData;

  /// 默认构造函数
  const ReaderScreenState({
    this.showAICompanionDialog = false,
    this.showEditDialog = false,
    this.showIllustrationDialog = false,
    this.isLoading = false,
    this.isUpdatingRoleCards = false,
    this.hasAutoTriggered = false,
    this.isAutoCompanionRunning = false,
    this.errorMessage = '',
    this.aiCompanionData,
  });

  /// 复制并修改部分字段
  ReaderScreenState copyWith({
    bool? showAICompanionDialog,
    bool? showEditDialog,
    bool? showIllustrationDialog,
    bool? isLoading,
    bool? isUpdatingRoleCards,
    bool? hasAutoTriggered,
    bool? isAutoCompanionRunning,
    String? errorMessage,
    AICompanionResponse? aiCompanionData,
  }) {
    return ReaderScreenState(
      showAICompanionDialog:
          showAICompanionDialog ?? this.showAICompanionDialog,
      showEditDialog: showEditDialog ?? this.showEditDialog,
      showIllustrationDialog:
          showIllustrationDialog ?? this.showIllustrationDialog,
      isLoading: isLoading ?? this.isLoading,
      isUpdatingRoleCards: isUpdatingRoleCards ?? this.isUpdatingRoleCards,
      hasAutoTriggered: hasAutoTriggered ?? this.hasAutoTriggered,
      isAutoCompanionRunning:
          isAutoCompanionRunning ?? this.isAutoCompanionRunning,
      errorMessage: errorMessage ?? this.errorMessage,
      aiCompanionData: aiCompanionData ?? this.aiCompanionData,
    );
  }
}

/// ReaderScreenNotifier
///
/// 管理阅读器屏幕的业务逻辑，包括：
/// - 对话框状态管理
/// - AI伴读功能
/// - 章节内容刷新
/// - 角色卡更新
/// - TTS朗读
@riverpod
class ReaderScreenNotifier extends _$ReaderScreenNotifier {
  // ========== 依赖服务 ==========
  late final IChapterRepository _chapterRepo;
  late final INovelRepository _novelRepo;
  late final ICharacterRepository _characterRepo;
  late final ICharacterRelationRepository _relationRepo;
  late final DifyService _difyService;
  late final NovelContextBuilder _contextBuilder;

  // ========== 当前数据 ==========
  Novel? _currentNovel;
  Chapter? _currentChapter;
  String? _content;

  // ========== 初始化方法 ==========

  @override
  ReaderScreenState build() {
    // 获取依赖服务
    _chapterRepo = ref.read(chapterRepositoryProvider);
    _novelRepo = ref.read(novelRepositoryProvider);
    _characterRepo = ref.read(characterRepositoryProvider);
    _relationRepo = ref.read(characterRelationRepositoryProvider);
    _difyService = ref.read(difyServiceProvider);
    _contextBuilder = ref.read(novelContextBuilderProvider);

    return const ReaderScreenState();
  }

  /// 设置当前阅读的上下文
  void setReadingContext({
    required Novel novel,
    required Chapter chapter,
    required List<Chapter> chapters,
    String? content,
  }) {
    _currentNovel = novel;
    _currentChapter = chapter;
    _content = content;
  }

  // ========== 对话框管理方法 ==========

  /// 显示AI伴读对话框
  void showAICompanionDialog(AICompanionResponse response) {
    state = state.copyWith(
      showAICompanionDialog: true,
      aiCompanionData: response,
    );
  }

  /// 隐藏AI伴读对话框
  void hideAICompanionDialog() {
    state = state.copyWith(
      showAICompanionDialog: false,
      aiCompanionData: null,
    );
  }

  /// 显示编辑对话框
  void showEditDialog() {
    state = state.copyWith(showEditDialog: true);
  }

  /// 隐藏编辑对话框
  void hideEditDialog() {
    state = state.copyWith(showEditDialog: false);
  }

  /// 显示插图对话框
  void showIllustrationDialog() {
    state = state.copyWith(showIllustrationDialog: true);
  }

  /// 隐藏插图对话框
  void hideIllustrationDialog() {
    state = state.copyWith(showIllustrationDialog: false);
  }

  // ========== 加载状态管理 ==========

  /// 设置加载状态
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// 设置错误信息
  void setError(String errorMessage) {
    state = state.copyWith(errorMessage: errorMessage);
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(errorMessage: '');
  }

  // ========== AI伴读功能 ==========

  /// 检查并自动触发AI伴读
  Future<void> checkAndAutoTriggerAICompanion() async {
    if (_currentNovel == null || _currentChapter == null || _content == null) {
      debugPrint('上下文未设置，跳过AI伴读');
      return;
    }

    // 防抖检查
    if (state.hasAutoTriggered || state.isAutoCompanionRunning) {
      debugPrint('AI伴读已触发或正在运行，跳过');
      return;
    }

    // 检查是否已伴读
    final hasAccompanied = await _chapterRepo.isChapterAccompanied(
      _currentNovel!.url,
      _currentChapter!.url,
    );

    if (hasAccompanied) {
      debugPrint('章节已伴读，跳过自动触发');
      return;
    }

    // 获取AI伴读设置
    final settings = await _novelRepo.getAiAccompanimentSettings(
      _currentNovel!.url,
    );

    if (!settings.autoEnabled) {
      debugPrint('自动伴读未启用');
      return;
    }

    // 检查章节内容
    if (_content!.isEmpty) {
      debugPrint('章节内容为空，跳过AI伴读');
      return;
    }

    // 开始自动伴读
    state = state.copyWith(
      hasAutoTriggered: true,
      isAutoCompanionRunning: true,
    );

    debugPrint('=== 自动触发AI伴读 ===');

    try {
      await _handleAICompanionSilent(settings);
    } catch (e) {
      debugPrint('❌ 自动AI伴读失败: $e');
      // 记录错误日志
      rethrow;
    } finally {
      state = state.copyWith(isAutoCompanionRunning: false);
    }
  }

  /// 手动触发AI伴读（业务逻辑）
  ///
  /// 返回AICompanionResponse供UI层使用
  Future<AICompanionResponse?> handleAICompanion() async {
    if (_content == null || _content!.isEmpty) {
      throw Exception('章节内容为空，无法进行AI伴读');
    }

    if (_currentNovel == null) {
      throw Exception('小说信息未设置');
    }

    try {
      // 获取本书的所有角色
      final allCharacters =
          await _characterRepo.getCharacters(_currentNovel!.url);

      // 筛选当前章节出现的角色
      final chapterCharacters = await _filterCharactersInChapter(
        allCharacters,
        _content!,
      );

      // 获取这些角色的关系
      final chapterRelationships = await _getRelationshipsForCharacters(
        _currentNovel!.url,
        chapterCharacters,
      );

      debugPrint('=== AI伴读分析开始 ===');
      debugPrint('小说总角色数: ${allCharacters.length}');
      debugPrint('本章出现角色数: ${chapterCharacters.length}');
      debugPrint('相关关系数: ${chapterRelationships.length}');

      // 使用 NovelContextBuilder 获取背景设定
      final backgroundSetting = await _contextBuilder.getBackgroundSetting(
        _currentNovel!.url,
      );

      // 调用DifyService
      final response = await _difyService.generateAICompanion(
        chaptersContent: _content!,
        backgroundSetting: backgroundSetting,
        characters: chapterCharacters,
        relationships: chapterRelationships,
      );

      if (response == null) {
        throw Exception('AI伴读返回数据为空');
      }

      debugPrint('=== AI伴读分析完成 ===');
      debugPrint('角色更新: ${response.roles.length}');
      debugPrint('关系更新: ${response.relations.length}');
      debugPrint('背景设定新增: ${response.background.length} 字符');
      debugPrint('本章总结: ${response.summery.length} 字符');

      // 通过状态管理触发对话框显示
      showAICompanionDialog(response);

      return response;
    } catch (e) {
      debugPrint('❌ AI伴读失败: $e');
      rethrow;
    }
  }

  /// 静默模式AI伴读（不显示确认对话框）
  Future<void> _handleAICompanionSilent(
      AiAccompanimentSettings settings) async {
    if (_currentNovel == null || _content == null) {
      throw Exception('上下文未设置');
    }

    try {
      // 获取本书的所有角色
      final allCharacters =
          await _characterRepo.getCharacters(_currentNovel!.url);

      // 筛选当前章节出现的角色
      final chapterCharacters = await _filterCharactersInChapter(
        allCharacters,
        _content!,
      );

      // 获取这些角色的关系
      final chapterRelationships = await _getRelationshipsForCharacters(
        _currentNovel!.url,
        chapterCharacters,
      );

      debugPrint('=== AI伴读分析开始（静默模式）===');
      debugPrint('小说总角色数: ${allCharacters.length}');
      debugPrint('本章出现角色数: ${chapterCharacters.length}');
      debugPrint('相关关系数: ${chapterRelationships.length}');

      // 使用 NovelContextBuilder 获取背景设定
      final backgroundSetting = await _contextBuilder.getBackgroundSetting(
        _currentNovel!.url,
      );

      // 调用DifyService
      final response = await _difyService.generateAICompanion(
        chaptersContent: _content!,
        backgroundSetting: backgroundSetting,
        characters: chapterCharacters,
        relationships: chapterRelationships,
      );

      if (response == null) {
        throw Exception('AI伴读返回数据为空');
      }

      debugPrint('=== AI伴读分析完成 ===');
      debugPrint('角色更新: ${response.roles.length}');
      debugPrint('关系更新: ${response.relations.length}');
      debugPrint('背景设定新增: ${response.background.length} 字符');
      debugPrint('本章总结: ${response.summery.length} 字符');

      // 直接执行数据更新（不显示确认对话框）
      await _performAICompanionUpdates(response, isSilent: true);

      // 标记章节为已伴读
      await _chapterRepo.markChapterAsAccompanied(
        _currentNovel!.url,
        _currentChapter!.url,
      );
    } catch (e) {
      debugPrint('❌ 静默AI伴读失败: $e');
      // 静默失败，不打扰用户
      rethrow; // 抛出异常供上层记录日志
    }
  }

  /// 执行AI伴读的数据更新
  Future<void> performAICompanionUpdates(
    AICompanionResponse response, {
    bool isSilent = false,
  }) async {
    if (_currentNovel == null) {
      throw Exception('小说信息未设置');
    }

    await _performAICompanionUpdates(response, isSilent: isSilent);
  }

  /// 内部方法：执行AI伴读的数据更新
  Future<void> _performAICompanionUpdates(
    AICompanionResponse response, {
    bool isSilent = false,
  }) async {
    try {
      // 1. 追加背景设定
      if (response.background.isNotEmpty) {
        final updatedBackground = await _appendBackgroundSetting(
          _novelRepo,
          _currentNovel!.url,
          response.background,
        );
        await _novelRepo.updateBackgroundSetting(
          _currentNovel!.url,
          updatedBackground,
        );
        debugPrint('✅ 背景设定追加成功');
      }

      // 2. 批量更新或插入角色
      int updatedRoles = 0;
      if (response.roles.isNotEmpty) {
        updatedRoles = await _characterRepo.batchUpdateOrInsertCharacters(
          _currentNovel!.url,
          response.roles,
        );
        debugPrint('✅ 角色更新成功: $updatedRoles');
      }

      // 3. 批量更新或插入关系
      int updatedRelations = 0;
      if (response.relations.isNotEmpty) {
        updatedRelations = await _relationRepo.batchUpdateOrInsertRelationships(
          _currentNovel!.url,
          response.relations,
          _characterRepo.getCharacters,
        );
        debugPrint('✅ 关系更新成功: $updatedRelations');
      }

      debugPrint('✅ AI伴读数据更新完成');
    } catch (e) {
      debugPrint('❌ AI伴读数据更新失败: $e');
      rethrow;
    }
  }

  /// 标记章节为已伴读
  Future<void> markChapterAsAccompanied() async {
    if (_currentNovel == null || _currentChapter == null) {
      throw Exception('上下文未设置');
    }

    await _chapterRepo.markChapterAsAccompanied(
      _currentNovel!.url,
      _currentChapter!.url,
    );
  }

  // ========== 角色管理功能 ==========

  /// 更新角色卡功能
  Future<void> updateCharacterCards({
    required void Function(List<Character>) onPreviewCharacters,
    required void Function(String) onError,
  }) async {
    // 防重复点击检查
    if (state.isUpdatingRoleCards) {
      onError('角色卡正在更新中,请稍候...');
      return;
    }

    if (_content == null || _content!.isEmpty) {
      onError('章节内容为空，无法更新角色卡');
      return;
    }

    if (_currentNovel == null) {
      onError('小说信息未设置');
      return;
    }

    // 设置loading状态
    state = state.copyWith(isUpdatingRoleCards: true);

    try {
      // 这里应该调用 CharacterCardService
      // 但为了避免循环依赖，我们通过回调暴露给UI层
      // UI层会使用 ref.read(characterCardServiceProvider) 获取服务

      // 实际的角色卡更新逻辑应该由UI层处理
      // 这里只是管理状态
    } catch (e) {
      onError('更新角色卡失败: $e');
    } finally {
      // 无论成功或失败都重置状态
      state = state.copyWith(isUpdatingRoleCards: false);
    }
  }

  // ========== 私有辅助方法 ==========

  /// 筛选当前章节中出现的角色
  Future<List<Character>> _filterCharactersInChapter(
    List<Character> allCharacters,
    String chapterContent,
  ) async {
    // 使用工具类进行角色筛选
    final foundCharacters = CharacterMatcher.extractCharactersFromChapter(
      chapterContent,
      allCharacters,
    );

    debugPrint('✅ 章节角色筛选完成: ${foundCharacters.length}/${allCharacters.length}');
    return foundCharacters;
  }

  /// 获取指定角色列表的关系
  Future<List<CharacterRelationship>> _getRelationshipsForCharacters(
    String novelUrl,
    List<Character> characters,
  ) async {
    if (characters.isEmpty) {
      return [];
    }

    // 获取角色ID集合
    final characterIds = characters.map((c) => c.id).whereType<int>().toSet();

    final allRelationships = await _relationRepo.getAllRelationships(novelUrl);

    // 筛选出涉及这些角色的关系
    final filteredRelationships = allRelationships.where((rel) {
      return characterIds.contains(rel.sourceCharacterId) ||
          characterIds.contains(rel.targetCharacterId);
    }).toList();

    debugPrint(
        '✅ 关系筛选完成: ${filteredRelationships.length}/${allRelationships.length}');
    return filteredRelationships;
  }

  // ========== 章节重置 ==========

  /// 重置章节伴读标记（用于强制刷新）
  Future<void> resetChapterAccompaniedFlag() async {
    if (_currentNovel == null || _currentChapter == null) {
      throw Exception('上下文未设置');
    }

    await _chapterRepo.resetChapterAccompaniedFlag(
      _currentNovel!.url,
      _currentChapter!.url,
    );
  }

  /// 检查章节是否已伴读
  Future<bool> isChapterAccompanied() async {
    if (_currentNovel == null || _currentChapter == null) {
      return false;
    }

    return await _chapterRepo.isChapterAccompanied(
      _currentNovel!.url,
      _currentChapter!.url,
    );
  }
}
