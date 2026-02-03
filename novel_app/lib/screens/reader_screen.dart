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
import '../services/database_service.dart';
import '../services/preload_service.dart';
import '../services/dify_service.dart';
import '../services/novel_context_service.dart';
import '../core/interfaces/repositories/i_chapter_repository.dart';
import '../core/interfaces/repositories/i_illustration_repository.dart';
import '../mixins/dify_streaming_mixin.dart';
import '../mixins/reader/auto_scroll_mixin.dart';
import '../mixins/reader/illustration_handler_mixin.dart';
import '../widgets/character_preview_dialog.dart';
import '../widgets/scene_illustration_dialog.dart';
import '../widgets/font_size_adjuster_dialog.dart'; // 新增导入
import '../widgets/scroll_speed_adjuster_dialog.dart'; // 新增导入
import '../widgets/reader_action_buttons.dart'; // 新增导入
import '../widgets/paragraph_widget.dart'; // 新增导入
import '../widgets/immersive/immersive_setup_dialog.dart'; // 沉浸体验配置对话框
import '../widgets/immersive/immersive_init_screen.dart'; // 沉浸体验初始化页面
import '../widgets/reader/ai_companion_confirm_dialog.dart';
import '../utils/toast_utils.dart';
import '../utils/media_markup_parser.dart';
import '../utils/character_matcher.dart';
import '../controllers/reader_content_controller.dart';
import '../controllers/reader_interaction_controller.dart';
import '../widgets/reader/paragraph_rewrite_dialog.dart';
import '../widgets/reader/chapter_summary_dialog.dart';
import '../widgets/reader/full_rewrite_dialog.dart';
import 'tts_player_screen.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
// Riverpod Providers
import '../core/providers/service_providers.dart';
import '../core/providers/database_providers.dart';
import '../core/providers/reader_screen_providers.dart';
import '../core/providers/reader_settings_state.dart';
import '../core/providers/reader_edit_mode_provider.dart';

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

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with
        TickerProviderStateMixin,
        DifyStreamingMixin,
        AutoScrollMixin,
        IllustrationHandlerMixin {
  late final ApiServiceWrapper _apiService;
  late final DatabaseService _databaseService;
  final ScrollController _scrollController = ScrollController();

  // ========== 服务实例（通过 ref.read 获取）==========
  late final DifyService _difyService;
  late final NovelContextBuilder _contextBuilder;

  // ========== 新增：ReaderContentController ==========
  late ReaderContentController _contentController;

  // ========== 新增：ReaderInteractionController ==========
  late ReaderInteractionController _interactionController;

  // ========== 便捷访问器（向后兼容） ==========
  String get _content => _contentController.content;
  set _content(String value) => _contentController.content = value;
  bool get _isLoading => _contentController.isLoading;
  String get _errorMessage => _contentController.errorMessage;

  // ========== 特写模式便捷访问器 ==========
  bool get _isCloseupMode => _interactionController.isCloseupMode;
  set _isCloseupMode(bool value) =>
      _interactionController.setCloseupMode(value);
  List<int> get _selectedParagraphIndices =>
      _interactionController.selectedParagraphIndices;

  // ========== 计算属性 ==========
  /// 段落列表（缓存分割结果，提升性能）
  List<String> get _paragraphs =>
      _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

  /// 当前章节索引（避免重复查找）
  int get _currentChapterIndex =>
      widget.chapters.indexWhere((c) => c.url == _currentChapter.url);

  late Chapter _currentChapter;
  double? _fontSize;

  // ========== 角色卡更新状态 ==========
  bool _isUpdatingRoleCards = false;

  // ========== AI伴读自动触发防抖标志 ==========
  bool _hasAutoTriggered = false;
  bool _isAutoCompanionRunning = false;

  // 模型尺寸（用于插图显示）
  int? _defaultModelWidth;
  int? _defaultModelHeight;

  // 预加载相关状态
  final PreloadService _preloadService = PreloadService();

  // 注意：自动滚动相关的字段和方法已提取到 AutoScrollMixin
  // 注意：插图处理相关的方法已提取到 IllustrationHandlerMixin

  // 保留滚动速度配置（供 AutoScrollMixin 使用）
  double? _scrollSpeed; // 滚动速度倍数，1.0为默认速度

  @override
  void initState() {
    super.initState();

    // 使用 Riverpod 获取依赖
    _apiService = ref.read(apiServiceWrapperProvider);
    _databaseService = ref.read(databaseServiceProvider);
    _difyService = ref.read(difyServiceProvider);
    _contextBuilder = ref.read(novelContextBuilderProvider);

    _currentChapter = widget.chapter;

    // ========== 加载持久化设置 ==========
    // 设置会在 ReaderSettingsStateNotifier 中自动加载
    // 我们通过 ref.watch 在 build 方法中获取

    // ========== 初始化 ReaderContentController ==========
    _contentController = ReaderContentController(
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
      apiService: _apiService,
      databaseService: _databaseService,
    );

    // ========== 初始化 ReaderInteractionController ==========
    _interactionController = ReaderInteractionController(
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    // 初始化自动滚动控制器
    initAutoScroll(scrollController: _scrollController);

    // 加载默认模型尺寸
    _loadDefaultModelSize();

    _initApiAndLoadContent();
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
      final t2iModels = models.text2img?.toList() ?? [];

      if (t2iModels.isNotEmpty) {
        // 找到默认模型
        final defaultModel = t2iModels.firstWhere(
          (m) => m.isDefault ?? false,
          orElse: () => t2iModels.first,
        );

        if (defaultModel.width != null &&
            defaultModel.height != null &&
            mounted) {
          setState(() {
            _defaultModelWidth = defaultModel.width;
            _defaultModelHeight = defaultModel.height;
          });
          debugPrint(
              '✅ 默认模型尺寸已加载: ${defaultModel.width} × ${defaultModel.height}');
        }
      }
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        '加载默认模型尺寸失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['model', 'illustration'],
      );
      debugPrint('⚠️ 加载默认模型尺寸失败: $e');
      // 使用默认值 704×1280
      if (mounted) {
        setState(() {
          _defaultModelWidth = 704;
          _defaultModelHeight = 1280;
        });
      }
    }
  }

  // ========== 以下方法已迁移到 ReaderContentController ==========

  @override
  void dispose() {
    disposeAutoScroll(); // 清理自动滚动资源（AutoScrollMixin）
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapterContent(
      {bool resetScrollPosition = true, bool forceRefresh = false}) async {
    // 如果是强制刷新，重置伴读标记
    if (forceRefresh) {
      await _databaseService.resetChapterAccompaniedFlag(
        widget.novel.url,
        _currentChapter.url,
      );
    }

    await _contentController.loadChapter(
      _currentChapter,
      widget.novel,
      forceRefresh: forceRefresh,
      resetScrollPosition: resetScrollPosition,
    );

    // 标记章节为已读
    await _databaseService.markChapterAsRead(
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

      debugPrint('=== 触发预加载 (PreloadService) ===');
      debugPrint('当前章节: ${_currentChapter.title}');
      debugPrint('总章节数: ${widget.chapters.length}');

      // 使用PreloadService进行预加载
      await _preloadService.enqueueTasks(
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
      debugPrint('❌ 预加载启动失败: $e');
    }
  }

  // 处理段落长按 - 显示操作菜单
  void _handleLongPress(int index) {
    if (!_interactionController.shouldHandleLongPress(_isCloseupMode)) return;

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
  Future<void> _navigateToChapter(Chapter targetChapter) async {
    // 记录当前自动滚动状态
    final wasAutoScrolling = shouldAutoScroll;

    // 更新当前章节 - 使用 addPostFrameCallback 避免在构建阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentChapter = targetChapter;
        });
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
          debugPrint('📖 _navigateToChapter: 翻页后恢复自动滚动');
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

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => FontSizeAdjusterDialog(
        initialFontSize: _fontSize ?? 18.0,
        onFontSizeChanged: (newSize) async {
          // 使用 Riverpod Provider 更新字体大小
          await ref
              .read(readerSettingsStateNotifierProvider.notifier)
              .setFontSize(newSize);
        },
      ),
    );
  }

  // 刷新当前章节 - 删除本地缓存并重新获取最新内容
  // 注意：自动滚动相关方法已提取到 AutoScrollMixin
  // 注意：使用 startAutoScroll(), pauseAutoScroll(), stopAutoScroll(), toggleAutoScroll()
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
  Future<void> _updateCharacterCards() async {
    // 防重复点击检查
    if (_isUpdatingRoleCards) {
      ToastUtils.showWarning('角色卡正在更新中,请稍候...', context: context);
      return;
    }

    if (_content.isEmpty) {
      ToastUtils.showWarning('章节内容为空，无法更新角色卡', context: context);
      return;
    }

    // 设置loading状态
    setState(() {
      _isUpdatingRoleCards = true;
    });

    // 开始后台处理（无loading阻塞，允许用户继续阅读）
    try {
      // 使用 CharacterCardService 预览更新
      final service = ref.read(characterCardServiceProvider);
      final updatedCharacters = await service.previewCharacterUpdates(
        novel: widget.novel,
        chapterContent: _content,
        onProgress: (message) {
          debugPrint(message); // 保留日志输出便于调试
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
      ErrorHelper.showErrorWithLog(
        context,
        '更新角色卡失败',
        stackTrace: stackTrace,
        category: LogCategory.character,
        tags: ['update', 'character-card'],
      );
    } finally {
      // 无论成功或失败都重置状态
      if (mounted) {
        setState(() {
          _isUpdatingRoleCards = false;
        });
      }
    }
  }

  /// 检查并自动触发AI伴读
  Future<void> _checkAndAutoTriggerAICompanion() async {
    // 防抖检查
    if (_hasAutoTriggered || _isAutoCompanionRunning) {
      debugPrint('AI伴读已触发或正在运行，跳过');
      return;
    }

    // 检查是否已伴读
    final hasAccompanied = await _databaseService.isChapterAccompanied(
      widget.novel.url,
      _currentChapter.url,
    );

    if (hasAccompanied) {
      debugPrint('章节已伴读，跳过自动触发');
      return;
    }

    // 获取AI伴读设置
    final settings = await _databaseService.getAiAccompanimentSettings(
      widget.novel.url,
    );

    if (!settings.autoEnabled) {
      debugPrint('自动伴读未启用');
      return;
    }

    // 检查章节内容
    if (_content.isEmpty) {
      debugPrint('章节内容为空，跳过AI伴读');
      return;
    }

    // 开始自动伴读
    _hasAutoTriggered = true;
    _isAutoCompanionRunning = true;

    debugPrint('=== 自动触发AI伴读 ===');

    try {
      await _handleAICompanionSilent(settings);
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        '自动AI伴读失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['auto-companion', 'chapter'],
      );
      debugPrint('❌ 自动AI伴读失败: $e');
    } finally {
      _isAutoCompanionRunning = false;
    }
  }

  // AI伴读功能
  Future<void> _handleAICompanion() async {
    if (_content.isEmpty) {
      ToastUtils.showWarning('章节内容为空，无法进行AI伴读', context: context);
      return;
    }

    // 显示loading提示
    ToastUtils.showInfo('AI正在分析章节...',
        context: context, duration: const Duration(minutes: 5));

    try {
      // 获取本书的所有角色
      final allCharacters =
          await _databaseService.getCharacters(widget.novel.url);

      // 筛选当前章节出现的角色
      final chapterCharacters = await _filterCharactersInChapter(
        allCharacters,
        _content,
      );

      // 获取这些角色的关系
      final chapterRelationships = await _getRelationshipsForCharacters(
        widget.novel.url,
        chapterCharacters,
      );

      debugPrint('=== AI伴读分析开始 ===');
      debugPrint('小说总角色数: ${allCharacters.length}');
      debugPrint('本章出现角色数: ${chapterCharacters.length}');
      debugPrint('相关关系数: ${chapterRelationships.length}');

      // 使用 NovelContextBuilder 获取背景设定
      final backgroundSetting = await _contextBuilder.getBackgroundSetting(
        widget.novel.url,
      );

      // 调用DifyService
      final response = await _difyService.generateAICompanion(
        chaptersContent: _content,
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

      // 关闭loading
      if (mounted) {
        ToastUtils.dismiss();
      }

      // 显示确认对话框
      if (mounted) {
        final confirmed = await showAICompanionConfirmDialog(
          context,
          response,
        );

        if (confirmed) {
          // 用户确认，执行数据更新
          await _performAICompanionUpdates(response);

          // 标记章节为已伴读
          await _databaseService.markChapterAsAccompanied(
            widget.novel.url,
            _currentChapter.url,
          );
        }
      }
    } catch (e, stackTrace) {
      ErrorHelper.showErrorWithLog(
        context,
        'AI伴读失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['companion', 'chapter-analysis'],
      );
      debugPrint('❌ AI伴读失败: $e');
      if (mounted) {
        ToastUtils.dismiss();
      }
    }
  }

  /// 静默模式AI伴读（不显示确认对话框）
  Future<void> _handleAICompanionSilent(
      AiAccompanimentSettings settings) async {
    try {
      // 获取本书的所有角色
      final allCharacters = await _databaseService.getCharacters(
        widget.novel.url,
      );

      // 筛选当前章节出现的角色
      final chapterCharacters = await _filterCharactersInChapter(
        allCharacters,
        _content,
      );

      // 获取这些角色的关系
      final chapterRelationships = await _getRelationshipsForCharacters(
        widget.novel.url,
        chapterCharacters,
      );

      debugPrint('=== AI伴读分析开始（静默模式）===');
      debugPrint('小说总角色数: ${allCharacters.length}');
      debugPrint('本章出现角色数: ${chapterCharacters.length}');
      debugPrint('相关关系数: ${chapterRelationships.length}');

      // 使用 NovelContextBuilder 获取背景设定
      final backgroundSetting = await _contextBuilder.getBackgroundSetting(
        widget.novel.url,
      );

      // 调用DifyService
      final response = await _difyService.generateAICompanion(
        chaptersContent: _content,
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
      await _databaseService.markChapterAsAccompanied(
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

        ToastUtils.showSuccess(message, context: context);
      }
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        '静默AI伴读失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['silent-companion', 'auto'],
      );
      debugPrint('❌ 静默AI伴读失败: $e');
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
        ToastUtils.showInfo('正在更新数据...',
            context: context, duration: const Duration(minutes: 5));
      }

      // 1. 追加背景设定
      if (response.background.isNotEmpty) {
        await _databaseService.appendBackgroundSetting(
          widget.novel.url,
          response.background,
        );
        debugPrint('✅ 背景设定追加成功');
      }

      // 2. 批量更新或插入角色
      int updatedRoles = 0;
      if (response.roles.isNotEmpty) {
        updatedRoles = await _databaseService.batchUpdateOrInsertCharacters(
          widget.novel.url,
          response.roles,
        );
        debugPrint('✅ 角色更新成功: $updatedRoles');
      }

      // 3. 批量更新或插入关系
      int updatedRelations = 0;
      if (response.relations.isNotEmpty) {
        updatedRelations =
            await _databaseService.batchUpdateOrInsertRelationships(
          widget.novel.url,
          response.relations,
        );
        debugPrint('✅ 关系更新成功: $updatedRelations');
      }

      // 关闭进度提示
      if (mounted) {
        if (!isSilent) {
          ToastUtils.dismiss();

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

          ToastUtils.showSuccess(successMessage,
              context: context, duration: const Duration(seconds: 3));
        }
      }
    } catch (e, stackTrace) {
      ErrorHelper.logError(
        'AI伴读数据更新失败',
        stackTrace: stackTrace,
        category: LogCategory.database,
        tags: ['companion', 'update'],
      );
      debugPrint('❌ AI伴读数据更新失败: $e');
      if (mounted && !isSilent) {
        ToastUtils.dismiss();
        ToastUtils.showError('数据更新失败: $e',
            duration: const Duration(seconds: 4), context: context);
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

    debugPrint('✅ 章节角色筛选完成: ${foundCharacters.length}/${allCharacters.length}');
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

    final allRelationships =
        await _databaseService.getAllRelationships(novelUrl);

    // 筛选出涉及这些角色的关系
    final filteredRelationships = allRelationships.where((rel) {
      return characterIds.contains(rel.sourceCharacterId) ||
          characterIds.contains(rel.targetCharacterId);
    }).toList();

    debugPrint(
        '✅ 关系筛选完成: ${filteredRelationships.length}/${allRelationships.length}');
    return filteredRelationships;
  }

  // 处理菜单动作
  void _handleMenuAction(String action) {
    switch (action) {
      case 'scroll_speed':
        _showScrollSpeedDialog();
        break;
      case 'font_size':
        _showFontSizeDialog();
        break;
      case 'summarize':
        _showChapterSummaryDialog(); // 使用新的 Dialog Widget
        break;
      case 'tts_read':
        _startTtsReading();
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
    }
  }

  // 调整滚动速度
  // 已弃用：直接通过滑块 onChanged 修改 _scrollSpeed

  // 显示滚动速度调整对话框
  void _showScrollSpeedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => ScrollSpeedAdjusterDialog(
        initialScrollSpeed: _scrollSpeed ?? 1.0,
        onScrollSpeedChanged: (newSpeed) async {
          // 使用 Riverpod Provider 更新滚动速度
          await ref
              .read(readerSettingsStateNotifierProvider.notifier)
              .setScrollSpeed(newSpeed);
          // 速度改变后重新启动自动滚动以应用新速度（Mixin方法）
          startAutoScroll();
        },
      ),
    );
  }

  // 已弃用：特写输入逻辑已迁移到改写弹窗流程

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
    if (_selectedParagraphIndices.isEmpty) {
      ToastUtils.showWarning('请先选择要改写的段落', context: context);
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => ParagraphRewriteDialog(
        novel: widget.novel,
        chapters: widget.chapters,
        currentChapter: _currentChapter,
        content: _content,
        selectedParagraphIndices: _selectedParagraphIndices,
        onReplace: (newContent) {
          setState(() {
            _content = newContent;
            _interactionController.clearSelection();
            _isCloseupMode = false;
          });
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
        content: _content,
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
        content: _content,
        onContentReplace: (newContent) async {
          setState(() {
            _content = newContent;
          });

          // 保存修改后的内容到数据库
          try {
            await _databaseService.updateChapterContent(
                _currentChapter.url, newContent);

            if (mounted) {
              ToastUtils.showSuccess('全文重写完成并已保存', context: context);
            }
          } catch (e, stackTrace) {
            ErrorHelper.showErrorWithLog(
              context,
              '保存章节内容失败',
              stackTrace: stackTrace,
              category: LogCategory.database,
              tags: ['save', 'chapter-content', 'full-rewrite'],
            );
            debugPrint('保存章节内容失败: $e');
          }
        },
      ),
    );
  }

  // 保存编辑后的章节内容
  Future<void> _saveEditedContent() async {
    try {
      await _databaseService.updateChapterContent(
          _currentChapter.url, _content);

      if (mounted) {
        ToastUtils.showSuccess('章节内容已保存', context: context);
      }
    } catch (e, stackTrace) {
      ErrorHelper.showErrorWithLog(
        context,
        '保存编辑内容失败',
        stackTrace: stackTrace,
        category: LogCategory.database,
        tags: ['save', 'chapter-content', 'edit'],
      );
      debugPrint('保存编辑内容失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 ref.watch 监听设置状态变化
    final settingsState = ref.watch(readerSettingsStateNotifierProvider);
    _fontSize = settingsState.value?.fontSize ?? 18.0;
    _scrollSpeed = settingsState.value?.scrollSpeed ?? 1.0;

    // 使用 ref.watch 监听编辑模式状态
    final isEditMode = ref.watch(readerEditModeProvider);

    final currentIndex = _currentChapterIndex;
    final hasPrevious = currentIndex > 0;
    final hasNext =
        currentIndex != -1 && currentIndex < widget.chapters.length - 1;

    final paragraphs = _paragraphs;

    // 直接返回 Scaffold，不使用 ChangeNotifierProvider 包装
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                _currentChapter.title,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            // 编辑模式状态指示器
            if (isEditMode)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14),
                    SizedBox(width: 4),
                    Text('编辑模式', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          // 编辑模式切换按钮
          if (!isEditMode)
            IconButton(
              onPressed: () => ref.read(readerEditModeProvider.notifier).toggle(),
              tooltip: '进入编辑模式',
              icon: const Icon(Icons.edit_outlined),
            ),
          // 编辑完成按钮
          if (isEditMode)
            IconButton(
              onPressed: () async {
                // 保存编辑内容并退出编辑模式
                await _saveEditedContent();
                ref.read(readerEditModeProvider.notifier).toggle();
              },
              tooltip: '完成编辑并保存',
              icon: const Icon(Icons.check),
            ),
          // 沉浸体验按钮
          if (!isEditMode)
            IconButton(
              onPressed: _showImmersiveSetup,
              tooltip: '沉浸体验',
              icon: const Icon(Icons.theater_comedy_outlined),
            ),
                // 更多功能菜单
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: '更多功能',
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 18),
                          SizedBox(width: 12),
                          Text('刷新章节'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'scroll_speed',
                      child: Row(
                        children: [
                          Icon(Icons.speed, size: 18),
                          SizedBox(width: 12),
                          Text('滚动速度'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'font_size',
                      child: Row(
                        children: [
                          Icon(Icons.text_fields, size: 18),
                          SizedBox(width: 12),
                          Text('字体大小'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'summarize',
                      child: Row(
                        children: [
                          Icon(Icons.summarize, size: 18),
                          SizedBox(width: 12),
                          Text('总结'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'tts_read',
                      child: Row(
                        children: [
                          Icon(Icons.headphones, size: 18),
                          SizedBox(width: 12),
                          Text('朗读'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'full_rewrite',
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories, size: 18),
                          SizedBox(width: 12),
                          Text('全文重写'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'update_character_cards',
                      enabled: !_isUpdatingRoleCards,
                      child: Row(
                        children: [
                          _isUpdatingRoleCards
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.tertiary),
                                  ),
                                )
                              : const Icon(Icons.person_search, size: 18),
                          const SizedBox(width: 12),
                          Text(_isUpdatingRoleCards ? '更新中...' : '更新角色卡'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'ai_companion',
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories, size: 18),
                          SizedBox(width: 12),
                          Text('AI伴读'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadChapterContent(
                                  resetScrollPosition: false),
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          // 主要内容区域
                          Listener(
                            behavior: HitTestBehavior.translucent, // 不阻止事件传递到下层
                            onPointerDown: (_) {
                              // 手指接触屏幕，暂停自动滚动
                              if (isAutoScrolling) {
                                handleTouch();
                              }
                            },
                            onPointerUp: (_) {
                              // handleTouch() 已经设置了恢复定时器，所以这里不需要额外处理
                            },
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                // 保留以兼容现有代码（不再处理用户滚动）
                                return handleScrollNotification(notification);
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16.0),
                                itemCount: paragraphs.length + 1, // +1 为了添加底部空白
                                itemBuilder: (context, index) {
                                  // 最后一个位置添加空白
                                  if (index == paragraphs.length) {
                                    return SizedBox(
                                      height: 160, // 底部留白高度，避免被按钮遮挡
                                      child: Container(), // 空容器只占位
                                    );
                                  }

                                  final paragraph = paragraphs[index];
                                  final isSelected =
                                      _selectedParagraphIndices.contains(index);

                                  return ParagraphWidget(
                                    paragraph: paragraph,
                                    index: index,
                                    fontSize: _fontSize ?? 18.0,
                                    isCloseupMode: _isCloseupMode,
                                    isEditMode: isEditMode, // From Riverpod Provider
                                    isSelected: isSelected,
                                    onTap: _handleParagraphTap,
                                    onLongPress: (idx) => _handleLongPress(
                                        idx), // _handleLongPress now accepts index
                                    onContentChanged: (newContent) {
                                      final updatedParagraphs =
                                          List<String>.from(paragraphs);
                                      updatedParagraphs[index] = newContent;
                                      // 使用 addPostFrameCallback 避免在构建阶段调用 setState
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() {
                                            _content =
                                                updatedParagraphs.join('\n');
                                          });
                                        }
                                      });
                                    },
                                    onImageTap:
                                        (taskId, imageUrl, imageIndex) =>
                                            handleImageTap(taskId, imageUrl,
                                                imageIndex), // Mixin方法
                                    onImageDelete: (taskId) =>
                                        deleteIllustrationByTaskId(
                                            taskId), // Mixin方法
                                    generateVideoFromIllustration:
                                        generateVideoFromIllustration, // Mixin方法
                                    modelWidth: _defaultModelWidth, // 传递模型宽度
                                    modelHeight: _defaultModelHeight, // 传递模型高度
                                  );
                                },
                              ),
                            ),
                          ), // GestureDetector 和 NotificationListener 闭合
                          // 固定在底部的章节切换按钮
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .shadowColor
                                        .withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: hasPrevious
                                            ? _goToPreviousChapter
                                            : null,
                                        icon: const Icon(Icons.arrow_back),
                                        label: const Text('上一章'),
                                      ),
                                      Text(
                                        '${currentIndex + 1}/${widget.chapters.length}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed:
                                            hasNext ? _goToNextChapter : null,
                                        icon: const Icon(Icons.arrow_forward),
                                        label: const Text('下一章'),
                                        style: ElevatedButton.styleFrom(
                                          iconAlignment: IconAlignment.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
            floatingActionButton: _content.isEmpty
                ? null
                : ReaderActionButtons(
                    isCloseupMode: _isCloseupMode,
                    hasSelectedParagraphs: _selectedParagraphIndices.isNotEmpty,
                    isAutoScrolling: isAutoScrolling, // Mixin getter
                    isAutoScrollPaused: isAutoScrollPaused, // Mixin getter
                    onRewritePressed: () {
                      _showParagraphRewriteDialog(); // 使用新的 Dialog Widget
                    },
                    onToggleCloseupMode: _toggleCloseupMode,
                    onToggleAutoScroll: toggleAutoScroll, // Mixin method
                  ),
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
  IChapterRepository get chapterRepository => ref.read(chapterRepositoryProvider);

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
          await _databaseService.getCharacters(widget.novel.url);

      if (!mounted) return;

      // 显示配置对话框
      final config = await ImmersiveSetupDialog.show(
        context,
        chapterContent: _content,
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
            chapterContent: _content,
            config: config,
          ),
        ),
      );
    } catch (e, stackTrace) {
      ErrorHelper.showErrorWithLog(
        context,
        '打开沉浸体验失败',
        stackTrace: stackTrace,
        category: LogCategory.ui,
        tags: ['immersive', 'setup'],
      );
      debugPrint('❌ 打开沉浸体验失败: $e');
    }
  }

  /// 获取当前可见区域的第一段索引（基于滚动位置估算）
  int _getFirstVisibleParagraphIndex() {
    if (!_scrollController.hasClients) return 0;

    final position = _scrollController.position;

    // 内容未超过一屏，返回0
    if (position.maxScrollExtent <= 0) {
      return 0;
    }

    // 空列表保护
    if (_paragraphs.isEmpty) return 0;

    // 计算滚动进度比例
    final scrollRatio = position.pixels / position.maxScrollExtent;
    final estimatedIndex = (scrollRatio * _paragraphs.length).floor();

    // 边界保护
    return estimatedIndex.clamp(0, _paragraphs.length - 1);
  }

  /// 启动TTS朗读
  Future<void> _startTtsReading() async {
    final startParagraphIndex = _getFirstVisibleParagraphIndex();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TtsPlayerScreen(
          novel: widget.novel,
          chapters: widget.chapters,
          startChapter: _currentChapter,
          startContent: _content,
          startParagraphIndex: startParagraphIndex,
        ),
      ),
    );

    // 返回后重新加载章节内容，因为可能被修改
    if (mounted) {
      _loadChapterContent(resetScrollPosition: false);
    }
  }
}
