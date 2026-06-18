/// Reader Screen - 阅读器主屏幕
///
/// 职责：
/// - 章节内容加载和显示
/// - AI伴读功能集成
/// - 阅读进度管理
/// - 用户交互处理
/// - 章节导航控制
///
/// 架构：
/// - 使用 ReaderContentController 处理内容加载
/// - 使用 ReaderInteractionController 处理用户交互
/// - 使用 AutoScrollMixin 处理自动滚动
/// - 使用 IllustrationHandlerMixin 处理插图
///
/// 依赖：
/// - ReaderContentController (lib/controllers/reader_content_controller.dart)
/// - ReaderInteractionController (lib/controllers/reader_interaction_controller.dart)
/// - AutoScrollMixin (lib/mixins/reader/auto_scroll_mixin.dart)
/// - IllustrationHandlerMixin (lib/mixins/reader/illustration_handler_mixin.dart)
///
/// 状态管理：
/// - 使用 Riverpod 管理全局设置（字体大小、滚动速度、编辑模式）
/// - 使用 Controller 管理本地状态（内容、交互）

library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../models/ai_companion_response.dart';
import '../models/ai_accompaniment_settings.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../services/api_service_wrapper.dart';
import '../services/dify_service.dart';
import '../services/novel_context_service.dart';
import '../services/dialog_service.dart';
import '../core/interfaces/repositories/i_chapter_repository.dart';
import '../core/interfaces/repositories/i_novel_repository.dart';
import '../core/interfaces/repositories/i_character_repository.dart';
import '../core/interfaces/repositories/i_character_relation_repository.dart';
import '../core/interfaces/repositories/i_illustration_repository.dart';
import '../mixins/dify_streaming_mixin.dart';
import '../mixins/reader/auto_scroll_mixin.dart';
import '../mixins/reader/illustration_handler_mixin.dart';
import '../widgets/character_preview_dialog.dart';
import '../widgets/scene_illustration_dialog.dart';
import '../widgets/reader_settings_dialog.dart'; // 阅读设置合并对话框（字体大小/文字亮度/滚动速度）
import '../widgets/reader_action_buttons.dart'; // 新增导入
import '../widgets/reader/reader_app_bar.dart'; // ReaderAppBar组件
import '../widgets/reader/reader_bottom_bar.dart'; // ReaderBottomBar组件
import '../widgets/reader/reader_content_view.dart'; // ReaderContentView组件
import '../widgets/reader/reader_error_view.dart'; // ReaderErrorView组件
import '../widgets/immersive/immersive_setup_dialog.dart'; // 沉浸体验配置对话框
import '../widgets/immersive/immersive_init_screen.dart'; // 沉浸体验初始化页面
import '../utils/toast_utils.dart';
import '../utils/media_markup_parser.dart';
import '../utils/character_matcher.dart';
import '../controllers/reader_content_controller.dart';
import '../controllers/reader_interaction_controller.dart';
import '../widgets/reader/paragraph_rewrite_dialog.dart';
import '../widgets/reader/chapter_summary_dialog.dart';
import '../widgets/reader/full_rewrite_dialog.dart';
import '../widgets/reader/ai_prompt_tag_extract_sheet.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
// Riverpod Providers
import '../core/providers/service_providers.dart';
import '../core/providers/database_providers.dart';
import '../core/providers/services/network_service_providers.dart';
import '../core/providers/reader_screen_providers.dart';
import '../core/providers/reader_screen_notifier.dart';
import '../core/providers/reader_settings_state.dart';
import '../core/providers/reader_edit_mode_provider.dart';
import '../core/providers/reader_state_providers.dart'; // 新增：细粒度状态Provider
import '../core/providers/reading_context_providers.dart';
import '../widgets/hermes/hermes_floating_button.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final Novel novel;
  final Chapter chapter;
  final List<Chapter> chapters;
  final ChapterSearchResult? searchResult;

  const ReaderScreen({
    super.key,
    required this.novel,
    required this.chapter,
    required this.chapters,
    this.searchResult,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

// ============ State Fields ============
class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with
        TickerProviderStateMixin,
        DifyStreamingMixin,
        AutoScrollMixin,
        IllustrationHandlerMixin {
  late final ApiServiceWrapper _apiService;

  // ========== Repository Getters (替代 DatabaseService) ==========
  INovelRepository get _novelRepo => ref.read(novelRepositoryProvider);
  IChapterRepository get _chapterRepo => ref.read(chapterRepositoryProvider);
  ICharacterRepository get _characterRepo =>
      ref.read(characterRepositoryProvider);
  ICharacterRelationRepository get _relationRepo =>
      ref.read(characterRelationRepositoryProvider);

  final ScrollController _scrollController = ScrollController();

  // ========== 服务实例（通过 ref.read 获取）==========
  late final DifyService _difyService;
  late final NovelContextBuilder _contextBuilder;
  late final DialogService _dialogService;

  // ========== 新增：ReaderContentController ==========
  late ReaderContentController _contentController;

  // ========== 新增：ReaderInteractionController ==========
  late ReaderInteractionController _interactionController;

  // ========== 便捷访问器（向后兼容） ==========
  // ⚠️ 注意：这些 getter 使用 ref.read()，不会触发 UI 重建
  // 在 build() 方法中应该使用 ref.watch() 直接监听 Provider
  bool get _isLoading => _contentController.isLoading;
  String get _errorMessage => _contentController.errorMessage;

  // ========== 计算属性 ==========
  /// 段落列表（缓存分割结果，提升性能）
  List<String> get _paragraphs => _contentController.content
      .split('\n')
      .where((p) => p.trim().isNotEmpty)
      .toList();

  /// 当前章节索引（避免重复查找）
  int get _currentChapterIndex =>
      widget.chapters.indexWhere((c) => c.url == _currentChapter.url);

  late Chapter _currentChapter;
  double? _fontSize;

  // 文字亮度 0.0=最暗, 1.0=最亮（默认）
  double? _textBrightness;

  // ========== AI伴读自动触发防抖标志 ==========
  bool _hasAutoTriggered = false;
  bool _isAutoCompanionRunning = false;

  // 注意：自动滚动相关的字段和方法已提取到 AutoScrollMixin
  // 注意：插图处理相关的方法已提取到 IllustrationHandlerMixin

  // 保留滚动速度配置（供 AutoScrollMixin 使用）
  double? _scrollSpeed; // 滚动速度倍数，1.0为默认速度

  @override
  void initState() {
    super.initState();

    // 使用 Riverpod 获取依赖
    _apiService = ref.read(apiServiceWrapperProvider);
    _difyService = ref.read(difyServiceProvider);
    _contextBuilder = ref.read(novelContextBuilderProvider);
    _dialogService = DialogService(ref);

    _currentChapter = widget.chapter;

    // ========== 加载持久化设置 ==========
    // 设置会在 ReaderSettingsStateNotifier 中自动加载
    // 我们通过 ref.watch 在 build 方法中获取

    // ========== 初始化 ReaderContentController ==========
    // 新版本：不再需要onStateChanged回调，状态通过Riverpod Provider自动管理
    _contentController = ReaderContentController(
      ref: ref,
      apiService: _apiService,
      chapterRepository: ref.read(chapterRepositoryProvider),
      novelRepository: ref.read(novelRepositoryProvider),
      headlessService: ref.read(headlessWebViewContentServiceProvider),
    );

    // ========== 初始化 ReaderInteractionController ==========
    // 新版本：不再需要onStateChanged回调，状态通过Riverpod Provider自动管理
    _interactionController = ReaderInteractionController(ref: ref);

    // 初始化自动滚动控制器
    initAutoScroll(scrollController: _scrollController);

    // 加载默认模型尺寸
    _loadDefaultModelSize();

    // 初始化 ReaderScreenNotifier 的上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initNotifierContext();
      }
    });

    // 设置 Hermes 阅读上下文（小说 + 章节）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(readingContextProvider.notifier).state = ReadingContext(
          novelTitle: widget.novel.title,
          chapterTitle: widget.chapter.title,
          novelUrl: widget.novel.url,
        );
      }
    });

    _initApiAndLoadContent();
  }

  /// 初始化 Notifier 上下文
  void _initNotifierContext() {
    final notifier = ref.read(readerScreenNotifierProvider.notifier);
    notifier.setReadingContext(
      novel: widget.novel,
      chapter: _currentChapter,
      chapters: widget.chapters,
      content: _contentController.content,
    );
  }

  /// 初始化API并加载内容
  Future<void> _initApiAndLoadContent() async {
    try {
      await _contentController.initialize();
      // 初始加载时不重置滚动位置，以保持搜索匹配跳转行为
      _loadChapterContent(resetScrollPosition: false);
      // 新系统不需要 _loadIllustrations()
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        '初始化API并加载内容失败',
        stackTrace: stackTrace,
        category: LogCategory.cache,
        tags: ['initialization', 'load-content'],
      );
      if (mounted) {
        setState(() {
          // _contentController 会处理错误状态
        });
      }
    }
  }

  /// 加载默认T2I模型的尺寸
  Future<void> _loadDefaultModelSize() async {
    try {
      final models = await _apiService.getModels();
      if (!mounted) return; // widget 可能在异步等待期间被销毁
      final t2iModels = models.text2img?.toList() ?? [];

      if (t2iModels.isNotEmpty) {
        // 找到默认模型
        final defaultModel = t2iModels.firstWhere(
          (m) => m.isDefault ?? false,
          orElse: () => t2iModels.first,
        );

        if (defaultModel.width != null && defaultModel.height != null) {
          // 使用Provider更新模型尺寸
          ref.read(modelSizeStateNotifierProvider.notifier).setSize(
                defaultModel.width,
                defaultModel.height,
              );
          LoggerService.instance.i(
            '默认模型尺寸已加载: ${defaultModel.width} × ${defaultModel.height}',
            category: LogCategory.ai,
            tags: ['model', 'illustration'],
          );
        }
      }
    } catch (e, stackTrace) {
      if (!mounted) return; // widget 可能在异步等待期间被销毁
      ErrorHelper.logError(
        '加载默认模型尺寸失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['model', 'illustration'],
      );
      // 使用默认值 704×1280
      ref.read(modelSizeStateNotifierProvider.notifier).resetToDefault();
    }
  }

  // ========== 以下方法已迁移到 ReaderContentController ==========

  @override
  void deactivate() {
    // 清除 Hermes 阅读上下文（必须在 deactivate 中执行，此时 ref 仍有效）
    ref.read(readingContextProvider.notifier).state = const ReadingContext();
    super.deactivate();
  }

  @override
  void dispose() {
    disposeAutoScroll(); // 清理自动滚动资源（AutoScrollMixin）
    _scrollController.dispose();
    super.dispose();
  }

// ============ Chapter Content Loading ============
  Future<void> _loadChapterContent(
      {bool resetScrollPosition = true, bool forceRefresh = false}) async {
    // 如果是强制刷新，重置伴读标记
    if (forceRefresh) {
      await _chapterRepo.resetChapterAccompaniedFlag(
        widget.novel.url,
        _currentChapter.url,
      );
    }

    // 暂停预加载，释放 WebView 给阅读器使用
    final preloadService = ref.read(preloadServiceProvider);
    preloadService.pause();

    try {
      await _contentController.loadChapter(
        _currentChapter,
        widget.novel,
        forceRefresh: forceRefresh,
        resetScrollPosition: resetScrollPosition,
      );
    } finally {
      // 恢复预加载
      preloadService.resume();
    }

    // 标记章节为已读
    await _chapterRepo.markChapterAsRead(
      widget.novel.url,
      _currentChapter.url,
    );

    // 处理滚动位置（保留在 reader_screen 中，因为这涉及到 ScrollController）
    _handleScrollPosition(resetScrollPosition);

    // 启动预加载（保留在 reader_screen 中，因为这需要完整的章节列表）
    await _startPreloadingChapters();

    // 重置防抖标志（章节切换时）
    _hasAutoTriggered = false;

    // 自动触发AI伴读
    await _checkAndAutoTriggerAICompanion();
  }

  /// 启动预加载章节（使用新的PreloadService）
  Future<void> _startPreloadingChapters() async {
    try {
      final currentIndex =
          widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
      if (currentIndex == -1) return;

      final chapterUrls = widget.chapters.map((c) => c.url).toList();

      LoggerService.instance.d(
        '触发预加载: 当前章节=${_currentChapter.title}, '
        '总章节数=${widget.chapters.length}, '
        '当前索引=$currentIndex',
        category: LogCategory.cache,
        tags: ['preload', 'chapter', 'start'],
      );

      // 使用PreloadService进行预加载（通过Provider获取）
      final preloadService = ref.read(preloadServiceProvider);
      await preloadService.enqueueTasks(
        novelUrl: widget.novel.url,
        novelTitle: widget.novel.title,
        chapterUrls: chapterUrls,
        currentIndex: currentIndex,
      );
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        '预加载启动失败',
        stackTrace: stackTrace,
        category: LogCategory.cache,
        tags: ['preload', 'chapter'],
      );
    }
  }

  // 处理段落长按 - 显示操作菜单

// ============ User Interaction Handlers ============
  void _handleLongPress(int index) {
    final interactionState = ref.read(interactionStateNotifierProvider);
    if (!_interactionController
        .shouldHandleLongPress(interactionState.isCloseupMode)) {
      return;
    }

    final paragraphs = _paragraphs;

    if (index >= 0 && index < paragraphs.length) {
      final paragraph = paragraphs[index].trim();

      // 显示选项菜单
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '段落操作',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // 段落预览
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    paragraph.length > 100
                        ? '${paragraph.substring(0, 100)}...'
                        : paragraph,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 操作选项
                ListTile(
                  leading: Icon(Icons.add_photo_alternate),
                  title: Text('创建插图'),
                  subtitle: Text('为这个段落生成插图'),
                  onTap: () {
                    Navigator.pop(context);
                    _showIllustrationDialog(paragraph, index);
                  },
                ),
                if (MediaMarkupParser.isMediaMarkup(paragraph)) ...[
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('插图信息'),
                    subtitle: Text('查看插图详情'),
                    onTap: () {
                      Navigator.pop(context);
                      final markup =
                          MediaMarkupParser.parseMediaMarkup(paragraph).first;
                      if (markup.isIllustration) {
                        generateVideoFromIllustration(markup.id); // Mixin方法
                      }
                    },
                  ),
                ],
              ],
            ),
          );
        },
      );
    }
  }

  // 显示插图创建弹窗
  void _showIllustrationDialog(String paragraphText, int paragraphIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SceneIllustrationDialog(
          paragraphText: paragraphText,
          novelUrl: widget.novel.url,
          chapterId: _currentChapter.url,
          paragraphIndex: paragraphIndex,
          onRefresh: (String taskId) {
            // 重新加载章节内容以显示新的插图标记
            _loadChapterContent(resetScrollPosition: false);
          },
        );
      },
    );
  }

  // 处理滚动位置的通用方法
  void _handleScrollPosition(bool resetScrollPosition) {
    // 如果有搜索结果，跳转到匹配位置
    if (widget.searchResult != null &&
        widget.searchResult!.chapterUrl == _currentChapter.url) {
      _scrollToSearchMatch();
    } else if (resetScrollPosition) {
      // 没有搜索结果且需要重置滚动位置时，滚动到顶部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  /// 滚动到搜索匹配位置
  void _scrollToSearchMatch() {
    if (widget.searchResult == null ||
        widget.searchResult!.matchPositions.isEmpty) {
      return;
    }

    // 延迟执行滚动，确保内容已经渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final firstMatch = widget.searchResult!.firstMatch;
        if (firstMatch != null) {
          // 估算滚动位置（基于字符位置的粗略估算）
          // 这里假设平均每个字符占用一定的高度
          final estimatedScrollOffset = (firstMatch.start * 0.3).toDouble();

          final maxScrollExtent = _scrollController.position.maxScrollExtent;
          final targetOffset =
              estimatedScrollOffset.clamp(0.0, maxScrollExtent);

          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          );

          // 显示跳转提示
          ToastUtils.showInfo(
            '已跳转到匹配位置 (${widget.searchResult!.matchCount} 处匹配)',
            context: context,
          );
        }
      }
    });
  }

  /// 导航到指定章节（支持自动滚动状态保持）
  ///
  /// [targetChapter] 目标章节

// ============ Chapter Navigation ============
  Future<void> _navigateToChapter(Chapter targetChapter) async {
    // 记录当前自动滚动状态
    final wasAutoScrolling = shouldAutoScroll;

    // 更新当前章节 - 使用 addPostFrameCallback 避免在构建阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentChapter = targetChapter;
        });
        // 更新 Hermes 阅读上下文中的章节信息
        ref.read(readingContextProvider.notifier).state = ReadingContext(
          novelTitle: widget.novel.title,
          chapterTitle: targetChapter.title,
          novelUrl: widget.novel.url,
        );
      }
    });

    // 等待一帧确保状态更新已生效
    await Future.delayed(const Duration(milliseconds: 50));

    // 加载新章节内容
    await _loadChapterContent(resetScrollPosition: true);

    // 如果之前处于自动滚动状态，则恢复自动滚动
    if (wasAutoScrolling && mounted) {
      // 延迟一帧确保UI已更新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          startAutoScroll();
          LoggerService.instance.d(
            '翻页后恢复自动滚动',
            category: LogCategory.ui,
            tags: ['navigation', 'auto-scroll', 'resume'],
          );
        }
      });
    }
  }

  void _goToPreviousChapter() {
    final currentIndex =
        widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    if (currentIndex > 0) {
      _navigateToChapter(widget.chapters[currentIndex - 1]);
    } else {
      ToastUtils.showInfo('已经是第一章了', context: context);
    }
  }

  void _goToNextChapter() {
    final currentIndex =
        widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    if (currentIndex != -1 && currentIndex < widget.chapters.length - 1) {
      _navigateToChapter(widget.chapters[currentIndex + 1]);
    } else {
      ToastUtils.showInfo('已经是最后一章了', context: context);
    }
  }

  // 刷新当前章节 - 删除本地缓存并重新获取最新内容
  // 注意：自动滚动相关方法已提取到 AutoScrollMixin
  // 注意：使用 startAutoScroll(), pauseAutoScroll(), stopAutoScroll(), toggleAutoScroll()

// ============ Content Refresh ============
  Future<void> _refreshChapter() async {
    // 先显示确认对话框
    final shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh),
            SizedBox(width: 8),
            Text('刷新章节'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将从服务器重新获取最新内容并覆盖本地缓存。'),
            const SizedBox(height: 8),
            Text('这可能会花费一些时间，请确认是否继续？',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('确认刷新'),
          ),
        ],
      ),
    );

    if (shouldRefresh != true) return;

    // 调用重构后的加载方法，并强制刷新
    await _loadChapterContent(resetScrollPosition: true, forceRefresh: true);

    if (mounted && _errorMessage.isEmpty) {
      ToastUtils.showSuccess('章节已刷新到最新内容', context: context);
    }
  }

  // 更新角色卡功能（使用 CharacterCardService）

// ============ Character Card Management ============
  Future<void> _updateCharacterCards() async {
    final cardUpdateNotifier =
        ref.read(characterCardUpdateStateNotifierProvider.notifier);

    // 防重复点击检查
    if (ref.read(characterCardUpdateStateNotifierProvider).isUpdating) {
      ToastUtils.showWarning('角色卡正在更新中,请稍候...', context: context);
      return;
    }

    if (_contentController.content.isEmpty) {
      ToastUtils.showWarning('章节内容为空，无法更新角色卡', context: context);
      return;
    }

    // 设置loading状态
    cardUpdateNotifier.setUpdating(true);

    // 开始后台处理（无loading阻塞，允许用户继续阅读）
    try {
      // 使用 CharacterCardService 预览更新
      final service = ref.read(characterCardServiceProvider);
      final updatedCharacters = await service.previewCharacterUpdates(
        novel: widget.novel,
        chapterContent: _contentController.content,
        onProgress: (message) {
          LoggerService.instance.d(
            message,
            category: LogCategory.character,
            tags: ['character-card', 'progress'],
          );
        },
      );

      // 显示角色预览对话框
      if (mounted) {
        await CharacterPreviewDialog.show(
          context,
          characterUpdates: updatedCharacters,
          onConfirmed: (selectedCharacters) async {
            // 保存用户确认的角色
            final savedCharacters =
                await service.saveCharacters(selectedCharacters);

            if (mounted) {
              ToastUtils.showSuccess('成功更新 ${savedCharacters.length} 个角色卡',
                  context: context, duration: const Duration(seconds: 3));
            }
          },
        );
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '更新角色卡失败',
        stackTrace: stackTrace,
        category: LogCategory.character,
        tags: ['update', 'character-card'],
      );
    } finally {
      // 无论成功或失败都重置状态
      cardUpdateNotifier.setUpdating(false);
    }
  }

  /// 检查并自动触发AI伴读

// ============ AI Companion ============
  Future<void> _checkAndAutoTriggerAICompanion() async {
    // 防抖检查
    if (_hasAutoTriggered || _isAutoCompanionRunning) {
      return;
    }

    // 检查是否已伴读
    final hasAccompanied = await _chapterRepo.isChapterAccompanied(
      widget.novel.url,
      _currentChapter.url,
    );

    if (hasAccompanied) {
      return;
    }

    // 获取AI伴读设置
    final settings = await _novelRepo.getAiAccompanimentSettings(
      widget.novel.url,
    );

    if (!settings.autoEnabled) {
      return;
    }

    // 检查章节内容
    if (_contentController.content.isEmpty) {
      return;
    }

    // 开始自动伴读
    _hasAutoTriggered = true;
    _isAutoCompanionRunning = true;

    try {
      await _handleAICompanionSilent(settings);
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        '自动AI伴读失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['auto-companion', 'chapter'],
      );
    } finally {
      _isAutoCompanionRunning = false;
    }
  }

  // AI伴读功能
  Future<void> _handleAICompanion() async {
    if (_contentController.content.isEmpty) {
      _dialogService.showWarning('章节内容为空，无法进行AI伴读', context: context);
      return;
    }

    // 显示loading提示
    _dialogService.showLoading('AI正在分析章节...', context: context);

    try {
      // 使用 Notifier 处理业务逻辑
      final notifier = ref.read(readerScreenNotifierProvider.notifier);

      // 更新 Notifier 的上下文（确保最新内容）
      notifier.setReadingContext(
        novel: widget.novel,
        chapter: _currentChapter,
        chapters: widget.chapters,
        content: _contentController.content,
      );

      // 调用 Notifier 的业务逻辑方法
      // Notifier会通过状态管理触发对话框显示
      await notifier.handleAICompanion();

      // 关闭loading
      if (mounted) {
        _dialogService.dismissToast();
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        'AI伴读失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['companion', 'chapter-analysis'],
      );
      if (mounted) {
        _dialogService.dismissToast();
      }
    }
  }

  /// 显示AI伴读确认对话框（由ref.listen触发）
  Future<void> _showAICompanionDialogFromState(
      AICompanionResponse response) async {
    final confirmed = await _dialogService.showAICompanionConfirm(
      context,
      response: response,
    );

    if (confirmed && mounted) {
      // 用户确认，执行数据更新
      await _dialogService.performAICompanionUpdates(
        context,
        response: response,
        novel: widget.novel,
      );

      // 标记章节为已伴读
      await _chapterRepo.markChapterAsAccompanied(
        widget.novel.url,
        _currentChapter.url,
      );
    }
  }

  /// 静默模式AI伴读（不显示确认对话框）
  Future<void> _handleAICompanionSilent(
      AiAccompanimentSettings settings) async {
    try {
      // 获取本书的所有角色
      final allCharacters = await _characterRepo.getCharacters(
        widget.novel.url,
      );

      // 筛选当前章节出现的角色
      final chapterCharacters = await _filterCharactersInChapter(
        allCharacters,
        _contentController.content,
      );

      // 获取这些角色的关系
      final chapterRelationships = await _getRelationshipsForCharacters(
        widget.novel.url,
        chapterCharacters,
      );

      // 使用 NovelContextBuilder 获取背景设定
      final backgroundSetting = await _contextBuilder.getBackgroundSetting(
        widget.novel.url,
      );

      // 调用DifyService
      final response = await _difyService.generateAICompanion(
        chaptersContent: _contentController.content,
        backgroundSetting: backgroundSetting,
        characters: chapterCharacters,
        relationships: chapterRelationships,
      );

      if (response == null) {
        throw Exception('AI伴读返回数据为空');
      }

      // 直接执行数据更新（不显示确认对话框）
      await _performAICompanionUpdates(response, isSilent: true);

      // 标记章节为已伴读
      await _chapterRepo.markChapterAsAccompanied(
        widget.novel.url,
        _currentChapter.url,
      );

      // 显示Toast提示（根据设置）
      if (settings.infoNotificationEnabled && mounted) {
        final messages = <String>[];
        if (response.roles.isNotEmpty) messages.add('角色');
        if (response.relations.isNotEmpty) messages.add('关系');
        if (response.background.isNotEmpty) messages.add('背景');

        final message =
            messages.isEmpty ? 'AI伴读内容已更新' : 'AI伴读已完成: 更新${messages.join('、')}';

        _dialogService.showSuccess(message, context: context);
      }
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        '静默AI伴读失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['silent-companion', 'auto'],
      );
      // 静默失败，不打扰用户
      rethrow; // 抛出异常供上层记录日志
    }
  }

  /// 执行AI伴读的数据更新
  Future<void> _performAICompanionUpdates(
    AICompanionResponse response, {
    bool isSilent = false,
  }) async {
    try {
      // 仅在非静默模式下显示更新进度
      if (!isSilent) {
        _dialogService.showLoading('正在更新数据...', context: context);
      }

      // 1. 追加背景设定
      if (response.background.isNotEmpty) {
        final currentBackground =
            await _novelRepo.getBackgroundSetting(widget.novel.url);
        final updatedBackground =
            currentBackground == null || currentBackground.isEmpty
                ? response.background
                : '$currentBackground\n\n${response.background}';
        await _novelRepo.updateBackgroundSetting(
            widget.novel.url, updatedBackground);
        LoggerService.instance.i(
          '背景设定追加成功',
          category: LogCategory.database,
          tags: ['companion', 'update', 'background'],
        );
      }

      // 2. 批量更新或插入角色
      int updatedRoles = 0;
      if (response.roles.isNotEmpty) {
        updatedRoles = await _characterRepo.batchUpdateOrInsertCharacters(
          widget.novel.url,
          response.roles,
        );
        LoggerService.instance.i(
          '角色更新成功: $updatedRoles',
          category: LogCategory.database,
          tags: ['companion', 'update', 'characters'],
        );
      }

      // 3. 批量更新或插入关系
      int updatedRelations = 0;
      if (response.relations.isNotEmpty) {
        updatedRelations = await _relationRepo.batchUpdateOrInsertRelationships(
          widget.novel.url,
          response.relations,
          _characterRepo.getCharacters,
        );
        LoggerService.instance.i(
          '关系更新成功: $updatedRelations',
          category: LogCategory.database,
          tags: ['companion', 'update', 'relations'],
        );
      }

      // 关闭进度提示
      if (mounted) {
        if (!isSilent) {
          _dialogService.dismissToast();

          // 仅在非静默模式下显示成功提示
          String successMessage = 'AI伴读更新完成';
          final List<String> updates = [];
          if (response.background.isNotEmpty) {
            updates.add('背景设定');
          }
          if (response.roles.isNotEmpty) {
            updates.add('$updatedRoles 个角色');
          }
          if (response.relations.isNotEmpty) {
            updates.add('$updatedRelations 个关系');
          }
          if (updates.isNotEmpty) {
            successMessage += ' (${updates.join('、')})';
          }

          _dialogService.showSuccess(successMessage, context: context);
        }
      }
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        'AI伴读数据更新失败',
        stackTrace: stackTrace,
        category: LogCategory.database,
        tags: ['companion', 'update'],
      );
      if (mounted && !isSilent) {
        _dialogService.dismissToast();
        _dialogService.showError('数据更新失败: $e', context: context);
      }
    }
  }

  /// 筛选当前章节中出现的角色
  ///
  /// [allCharacters] 小说的所有角色
  /// [chapterContent] 章节内容
  /// 返回本章出现的角色列表
  Future<List<Character>> _filterCharactersInChapter(
    List<Character> allCharacters,
    String chapterContent,
  ) async {
    // 使用工具类进行角色筛选
    final foundCharacters = CharacterMatcher.extractCharactersFromChapter(
      chapterContent,
      allCharacters,
    );

    LoggerService.instance.i(
      '章节角色筛选完成: ${foundCharacters.length}/${allCharacters.length}',
      category: LogCategory.character,
      tags: ['filter', 'chapter'],
    );
    return foundCharacters;
  }

  /// 获取指定角色列表的关系
  ///
  /// [novelUrl] 小说URL
  /// [characters] 角色列表
  /// 返回这些角色之间的关系
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

    LoggerService.instance.i(
      '关系筛选完成: ${filteredRelationships.length}/${allRelationships.length}',
      category: LogCategory.character,
      tags: ['filter', 'relationship'],
    );
    return filteredRelationships;
  }

  // 处理菜单动作

// ============ Dialog Handlers ============
  void _handleMenuAction(String action) {
    switch (action) {
      case 'reader_settings':
        _showReaderSettingsDialog();
        break;
      case 'font_size':
      case 'scroll_speed':
        // 兼容旧菜单项，统一跳转合并的阅读设置对话框
        _showReaderSettingsDialog();
        break;
      case 'summarize':
        _showChapterSummaryDialog(); // 使用新的 Dialog Widget
        break;
      case 'full_rewrite':
        _showFullRewriteDialog(); // 使用新的 Dialog Widget
        break;
      case 'update_character_cards':
        _updateCharacterCards();
        break;
      case 'ai_companion':
        _handleAICompanion();
        break;
      case 'refresh':
        _refreshChapter();
        break;
      case 'ai_extract_tags':
        _showAIExtractTagsSheet();
        break;
    }
  }

  // 显示 AI 提取标签 Sheet
  void _showAIExtractTagsSheet() {
    if (_contentController.content.trim().isEmpty) {
      ToastUtils.showWarning('当前章节无内容，无法提取标签', context: context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AIPromptTagExtractSheet(
        chapterContent: _contentController.content,
      ),
    );
  }

  // 显示阅读设置对话框（合并字体大小、文字亮度、滚动速度）
  void _showReaderSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => ReaderSettingsDialog(
        initialFontSize: _fontSize ?? 18.0,
        initialTextBrightness: _textBrightness ?? 1.0,
        initialScrollSpeed: _scrollSpeed ?? 1.0,
        onConfirm: ({
          required double fontSize,
          required double textBrightness,
          required double scrollSpeed,
        }) async {
          final notifier =
              ref.read(readerSettingsStateNotifierProvider.notifier);
          // 字体大小
          await notifier.setFontSize(fontSize);
          // 文字亮度
          await notifier.setTextBrightness(textBrightness);
          // 滚动速度
          await notifier.setScrollSpeed(scrollSpeed);
          // 速度改变后重新启动自动滚动以应用新速度（Mixin方法）
          startAutoScroll();
        },
      ),
    );
  }

  // ========== 辅助方法 ==========

  // 切换特写模式
  void _toggleCloseupMode() {
    _interactionController.toggleCloseupMode();
  }

  // 处理段落点击
  void _handleParagraphTap(int index) {
    _interactionController.handleParagraphTap(index, _paragraphs);
  }

  // ========== 段落改写功能（使用 ParagraphRewriteDialog）==========

  /// 显示段落改写对话框
  Future<void> _showParagraphRewriteDialog() async {
    final interactionState = ref.read(interactionStateNotifierProvider);
    if (interactionState.selectedParagraphIndices.isEmpty) {
      ToastUtils.showWarning('请先选择要改写的段落', context: context);
      return;
    }

    // ⚠️ 重要：必须传递过滤后的内容，与UI层保持一致
    // UI层使用的是 _paragraphs（过滤空行后的列表）
    // 用户选择的索引也是基于过滤后的列表
    // 如果传递原始内容，会导致索引不匹配
    final filteredContent = _paragraphs.join('\n');

    await showDialog(
      context: context,
      builder: (_) => ParagraphRewriteDialog(
        novel: widget.novel,
        chapters: widget.chapters,
        currentChapter: _currentChapter,
        content: filteredContent, // 使用过滤后的内容
        selectedParagraphIndices: interactionState.selectedParagraphIndices,
        onReplace: (newContent) async {
          // 1. 立即更新 Provider（触发 UI 重建）
          setState(() {
            _contentController.setContent(newContent);
            _interactionController.clearSelection();
            _interactionController.setCloseupMode(false);
          });

          // 2. 持久化到数据库（确保关闭后重新打开仍显示新内容）
          try {
            await _chapterRepo.updateChapterContent(
              _currentChapter.url,
              newContent,
            );
            LoggerService.instance.i(
              '替换内容已保存到数据库: ${newContent.length}字符',
              category: LogCategory.database,
              tags: ['save', 'paragraph-rewrite'],
            );
          } catch (e) {
            LoggerService.instance.e(
              '保存替换内容失败: $e',
              category: LogCategory.database,
              tags: ['save', 'paragraph-rewrite'],
            );
            // 即使保存失败，UI 已更新，用户可以看到新内容
            // 但重新打开后会丢失更改
            if (mounted) {
              ToastUtils.showError(
                '替换成功但保存失败：$e',
                context: context,
              );
            }
          }
        },
      ),
    );
  }

  // ========== 章节总结功能（使用 ChapterSummaryDialog）==========

  /// 显示章节总结对话框
  Future<void> _showChapterSummaryDialog() async {
    await showDialog(
      context: context,
      builder: (_) => ChapterSummaryDialog(
        novel: widget.novel,
        chapters: widget.chapters,
        currentChapter: _currentChapter,
        content: _contentController.content,
      ),
    );
  }

  // ========== 改写功能 ==========

  // 注意：段落改写功能已由 ParagraphRewriteDialog 完整实现
  // 以下旧代码已删除，避免重复：
  // - _showRewriteRequirementDialog (已集成到ParagraphRewriteDialog)
  // - _generateRewrite (已集成到ParagraphRewriteDialog)
  // - _showRewriteResultDialog (已集成到ParagraphRewriteDialog)
  // - _buildCursor (已集成到ParagraphRewriteDialog)
  // - _replaceSelectedParagraphs (已集成到ParagraphRewriteDialog)

  /// 显示全文重写对话框（使用新的 Dialog Widget）
  Future<void> _showFullRewriteDialog() async {
    await showDialog(
      context: context,
      builder: (_) => FullRewriteDialog(
        novel: widget.novel,
        chapters: widget.chapters,
        currentChapter: _currentChapter,
        content: _contentController.content,
        onContentReplace: (newContent) async {
          setState(() {
            _contentController.setContent(newContent);
          });

          // 保存修改后的内容到数据库
          try {
            await _chapterRepo.updateChapterContent(
                _currentChapter.url, newContent);

            if (mounted) {
              ToastUtils.showSuccess('全文重写完成并已保存', context: context);
            }
          } catch (e, stackTrace) {
            if (!mounted) return;
            ErrorHelper.showErrorWithLog(
              context,
              '保存章节内容失败',
              stackTrace: stackTrace,
              category: LogCategory.database,
              tags: ['save', 'chapter-content', 'full-rewrite'],
            );
          }
        },
      ),
    );
  }

  // 保存编辑后的章节内容

// ============ Content Editing ============
  Future<void> _saveEditedContent() async {
    try {
      await _chapterRepo.updateChapterContent(
          _currentChapter.url, _contentController.content);

      if (mounted) {
        ToastUtils.showSuccess('章节内容已保存', context: context);
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '保存编辑内容失败',
        stackTrace: stackTrace,
        category: LogCategory.database,
        tags: ['save', 'chapter-content', 'edit'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 ref.watch 监听设置状态变化
    final settingsState = ref.watch(readerSettingsStateNotifierProvider);
    _fontSize = settingsState.value?.fontSize ?? 18.0;
    _scrollSpeed = settingsState.value?.scrollSpeed ?? 1.0;
    _textBrightness = settingsState.value?.textBrightness ?? 1.0;

    // 使用 ref.watch 监听编辑模式状态
    final isEditMode = ref.watch(readerEditModeProvider);

    // ⭐ 关键修复：监听交互状态变化（特写模式、段落选择），确保UI在状态变化时重建
    final interactionState = ref.watch(interactionStateNotifierProvider);

    // ⭐ 关键修复：监听章节内容状态，确保内容加载后UI重建（修复空白页面问题）
    final contentState = ref.watch(chapterContentStateNotifierProvider);

    // 监听 ReaderScreenNotifier 状态，处理对话框显示
    ref.listen<ReaderScreenState>(
      readerScreenNotifierProvider,
      (previous, next) {
        // 监听AI伴读对话框显示
        if (next.showAICompanionDialog &&
            next.aiCompanionData != null &&
            mounted) {
          _showAICompanionDialogFromState(next.aiCompanionData!);
          // 立即隐藏状态，避免重复显示
          ref
              .read(readerScreenNotifierProvider.notifier)
              .hideAICompanionDialog();
        }
      },
    );

    // ⭐ 关键修复：直接使用 contentState.content，而不是 _content getter
    // _content getter 内部使用 ref.read()，不会触发 UI 重建
    // 这里已经通过 ref.watch(chapterContentStateNotifierProvider) 建立了响应式依赖
    final content = contentState.content;
    final paragraphs =
        content.split('\n').where((p) => p.trim().isNotEmpty).toList();

    return HermesFloatingShell(
      child: Scaffold(
        // 直接返回 Scaffold，不使用 ChangeNotifierProvider 包装
        appBar: ReaderAppBar(
          novel: widget.novel,
          currentChapter: _currentChapter,
          chapters: widget.chapters,
          isEditMode: isEditMode,
          isUpdatingRoleCards: ref
              .watch(characterCardUpdateStateNotifierProvider)
              .isUpdating, // 从Provider读取
          onToggleEditMode: () =>
              ref.read(readerEditModeProvider.notifier).toggle(),
          onSaveAndExitEditMode: () async {
            await _saveEditedContent();
            ref.read(readerEditModeProvider.notifier).toggle();
          },
          onShowImmersiveSetup: _showImmersiveSetup,
          onMenuAction: _handleMenuAction,
        ),
        body: _buildBody(context, isEditMode, paragraphs, interactionState),
        floatingActionButton: _contentController.content.isEmpty
            ? null
            : ReaderActionButtons(
                isCloseupMode: interactionState.isCloseupMode,
                hasSelectedParagraphs:
                    interactionState.selectedParagraphIndices.isNotEmpty,
                isAutoScrolling: isAutoScrolling, // Mixin getter
                isAutoScrollPaused: isAutoScrollPaused, // Mixin getter
                onRewritePressed: () {
                  _showParagraphRewriteDialog(); // 使用新的 Dialog Widget
                },
                onToggleCloseupMode: _toggleCloseupMode,
                onToggleAutoScroll: toggleAutoScroll, // Mixin method
              ),
      ),
    );
  }

  /// 构建阅读器主体内容
  Widget _buildBody(
    BuildContext context,
    bool isEditMode,
    List<String> paragraphs,
    InteractionState interactionState,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return ReaderErrorView(
        errorMessage: _errorMessage,
        onRetry: () => _loadChapterContent(resetScrollPosition: false),
      );
    }

    // 新增：检查内容是否为空（修复空白页面问题）
    if (!_isLoading &&
        _contentController.content.trim().isEmpty &&
        paragraphs.isEmpty) {
      return ReaderErrorView(
        errorMessage: '章节内容为空，请尝试刷新或联系开发者',
        onRetry: () => _loadChapterContent(
          resetScrollPosition: false,
          forceRefresh: true,
        ),
      );
    }

    final currentIndex = _currentChapterIndex;
    final hasPrevious = currentIndex > 0;
    final hasNext =
        currentIndex != -1 && currentIndex < widget.chapters.length - 1;

    return Stack(
      children: [
        // 主要内容区域
        ReaderContentView(
          paragraphs: paragraphs,
          selectedParagraphIndices: interactionState.selectedParagraphIndices,
          fontSize: _fontSize ?? 18.0,
          textBrightness: _textBrightness ?? 1.0,
          isCloseupMode: interactionState.isCloseupMode,
          isEditMode: isEditMode,
          isAutoScrolling: isAutoScrolling,
          onParagraphTap: _handleParagraphTap,
          onParagraphLongPress: _handleLongPress,
          onContentChanged: (index, newContent) {
            // 仅支持全文编辑模式（index=-1）
            assert(index == -1, '只支持全文编辑模式，段落编辑模式已废弃');
            // 使用 addPostFrameCallback 避免在构建阶段调用 setState
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _contentController.setContent(newContent);
              });
            });
          },
          onImageTap: (taskId, imageUrl, imageIndex) =>
              handleImageTap(taskId, imageUrl, imageIndex), // Mixin方法
          onImageDelete: (taskId) =>
              deleteIllustrationByTaskId(taskId), // Mixin方法
          generateVideoFromIllustration:
              generateVideoFromIllustration, // Mixin方法
          modelWidth: ref
              .watch(modelSizeStateNotifierProvider)
              .width, // 从Provider读取模型宽度
          modelHeight: ref
              .watch(modelSizeStateNotifierProvider)
              .height, // 从Provider读取模型高度
          scrollController: _scrollController,
          onPointerDown: () {
            // 手指接触屏幕，暂停自动滚动
            if (isAutoScrolling) {
              handleTouch();
            }
          },
          onPointerUp: () {
            // handleTouch() 已经设置了恢复定时器，所以这里不需要额外处理
          },
          onScrollNotification: (notification) {
            // 保留以兼容现有代码（不再处理用户滚动）
            return handleScrollNotification(notification);
          },
        ),
        // 固定在底部的章节切换按钮
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ReaderBottomBar(
            currentIndex: currentIndex,
            totalChapters: widget.chapters.length,
            hasPrevious: hasPrevious,
            hasNext: hasNext,
            onPreviousChapter: _goToPreviousChapter,
            onNextChapter: _goToNextChapter,
          ),
        ),
      ],
    );
  }

  // 注意：插图处理相关方法已提取到 IllustrationHandlerMixin
  // 包括：generateVideoFromIllustration, handleImageTap, regenerateMoreImages,
  //       generateVideoFromSpecificImage, deleteIllustrationByTaskId

  // ========== AutoScrollMixin 抽象字段实现 ==========

  @override
  ScrollController get scrollController => _scrollController;

  @override
  double get scrollSpeed => _scrollSpeed ?? 1.0;

  // ========== IllustrationHandlerMixin 抽象字段实现 ==========

  @override
  Novel get novel => widget.novel;

  @override
  Chapter get currentChapter => _currentChapter;

  @override
  IChapterRepository get chapterRepository =>
      ref.read(chapterRepositoryProvider);

  @override
  IIllustrationRepository get illustrationRepository =>
      ref.read(illustrationRepositoryProvider);

  @override
  ApiServiceWrapper get apiService => _apiService;

  /// 显示沉浸体验配置对话框
  Future<void> _showImmersiveSetup() async {
    // 加载所有角色
    try {
      final allCharacters =
          await _characterRepo.getCharacters(widget.novel.url);

      if (!mounted) return;

      // 显示配置对话框
      final config = await ImmersiveSetupDialog.show(
        context,
        chapterContent: _contentController.content,
        allCharacters: allCharacters,
      );

      if (config == null) return; // 用户取消

      // 导航到初始化页面
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImmersiveInitScreen(
            novel: widget.novel,
            chapter: _currentChapter,
            chapterContent: _contentController.content,
            config: config,
          ),
        ),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '打开沉浸体验失败',
        stackTrace: stackTrace,
        category: LogCategory.ui,
        tags: ['immersive', 'setup'],
      );
    }
  }
}
