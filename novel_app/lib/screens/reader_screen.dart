import 'dart:async';
import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';
import '../services/preload_service.dart';
import '../services/character_card_service.dart';
import '../core/di/api_service_provider.dart';
import '../mixins/dify_streaming_mixin.dart';
import '../mixins/reader/auto_scroll_mixin.dart';
import '../mixins/reader/illustration_handler_mixin.dart';
import '../widgets/highlighted_text.dart';
import '../widgets/character_preview_dialog.dart';
import '../widgets/scene_illustration_dialog.dart';
import '../widgets/font_size_adjuster_dialog.dart'; // 新增导入
import '../widgets/scroll_speed_adjuster_dialog.dart'; // 新增导入
import '../widgets/reader_action_buttons.dart'; // 新增导入
import '../widgets/paragraph_widget.dart'; // 新增导入

import '../utils/media_markup_parser.dart';
import '../providers/reader_edit_mode_provider.dart';
import '../controllers/paragraph_rewrite_controller.dart';
import '../controllers/summarize_controller.dart';
import '../controllers/reader_content_controller.dart';
import '../controllers/reader_interaction_controller.dart';
import '../widgets/reader/paragraph_rewrite_dialog.dart';
import '../widgets/reader/chapter_summary_dialog.dart';
import '../widgets/reader/full_rewrite_dialog.dart';
import 'package:provider/provider.dart';

class ReaderScreen extends StatefulWidget {
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
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with TickerProviderStateMixin, DifyStreamingMixin, AutoScrollMixin, IllustrationHandlerMixin {
  final ApiServiceWrapper _apiService = ApiServiceProvider.instance;
  final DatabaseService _databaseService = DatabaseService();
  final ScrollController _scrollController = ScrollController();

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
  set _isCloseupMode(bool value) => _interactionController.setCloseupMode(value);
  List<int> get _selectedParagraphIndices => _interactionController.selectedParagraphIndices;

  // ========== 计算属性 ==========
  /// 段落列表（缓存分割结果，提升性能）
  List<String> get _paragraphs =>
      _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

  /// 当前章节索引（避免重复查找）
  int get _currentChapterIndex =>
      widget.chapters.indexWhere((c) => c.url == _currentChapter.url);

  late Chapter _currentChapter;
  double _fontSize = 18.0;

  // 预加载相关状态
  final PreloadService _preloadService = PreloadService();

  // 注意：自动滚动相关的字段和方法已提取到 AutoScrollMixin
  // 注意：插图处理相关的方法已提取到 IllustrationHandlerMixin

  // 保留滚动速度配置（供 AutoScrollMixin 使用）
  double _scrollSpeed = 1.0; // 滚动速度倍数，1.0为默认速度

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;

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

    _initApiAndLoadContent();
  }

  /// 初始化API并加载内容
  Future<void> _initApiAndLoadContent() async {
    try {
      await _contentController.initialize();
      // 初始加载时不重置滚动位置，以保持搜索匹配跳转行为
      _loadChapterContent(resetScrollPosition: false);
      // 新系统不需要 _loadIllustrations()
    } catch (e) {
      if (mounted) {
        setState(() {
          // _contentController 会处理错误状态
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

  Future<void> _loadChapterContent({bool resetScrollPosition = true, bool forceRefresh = false}) async {
    await _contentController.loadChapter(
      _currentChapter,
      widget.novel,
      forceRefresh: forceRefresh,
      resetScrollPosition: resetScrollPosition,
    );

    // 处理滚动位置（保留在 reader_screen 中，因为这涉及到 ScrollController）
    _handleScrollPosition(resetScrollPosition);

    // 启动预加载（保留在 reader_screen 中，因为这需要完整的章节列表）
    await _startPreloadingChapters();
  }

  /// 启动预加载章节（使用新的PreloadService）
  Future<void> _startPreloadingChapters() async {
    try {
      final currentIndex = widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
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
    } catch (e) {
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    paragraph.length > 100 ? '${paragraph.substring(0, 100)}...' : paragraph,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 操作选项
                ListTile(
                  leading: Icon(Icons.add_photo_alternate, color: Colors.blue),
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
                    leading: Icon(Icons.info_outline, color: Colors.green),
                    title: Text('插图信息'),
                    subtitle: Text('查看插图详情'),
                    onTap: () {
                      Navigator.pop(context);
                      final markup = MediaMarkupParser.parseMediaMarkup(paragraph).first;
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('已跳转到匹配位置 (${widget.searchResult!.matchCount} 处匹配)'),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: '查看全部',
                onPressed: () {
                  _showSearchMatchDialog();
                },
              ),
            ),
          );
        }
      }
    });
  }

  /// 显示搜索匹配详情对话框
  void _showSearchMatchDialog() {
    if (widget.searchResult == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: const Text('搜索匹配详情'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('章节: ${widget.searchResult!.chapterTitle}'),
              const SizedBox(height: 8),
              Text('匹配数量: ${widget.searchResult!.matchCount} 处'),
              const SizedBox(height: 16),
              const Text('搜索关键词:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                children: widget.searchResult!.searchKeywords.map((keyword) {
                  return Chip(
                    label: Text(keyword),
                    backgroundColor: Theme.of(context).colorScheme.primary
                      ..withValues(alpha: 0.1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('匹配预览:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SearchResultHighlight(
                  originalText: widget.searchResult!.content,
                  keywords: widget.searchResult!.searchKeywords,
                  maxLines: 5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _goToPreviousChapter() {
    final currentIndex =
        widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    if (currentIndex > 0) {
      setState(() {
        _currentChapter = widget.chapters[currentIndex - 1];
      });
      _loadChapterContent(resetScrollPosition: true);
      // 新系统不需要 _loadIllustrations()
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是第一章了')),
      );
    }
  }

  void _goToNextChapter() {
    final currentIndex =
        widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    if (currentIndex != -1 && currentIndex < widget.chapters.length - 1) {
      setState(() {
        _currentChapter = widget.chapters[currentIndex + 1];
      });
      _loadChapterContent(resetScrollPosition: true);
      // 新系统不需要 _loadIllustrations()
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是最后一章了')),
      );
    }
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => FontSizeAdjusterDialog(
        initialFontSize: _fontSize,
        onFontSizeChanged: (newSize) {
          setState(() {
            _fontSize = newSize;
          });
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
            Icon(Icons.refresh, color: Colors.blue),
            SizedBox(width: 8),
            Text('刷新章节'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将从服务器重新获取最新内容并覆盖本地缓存。'),
            SizedBox(height: 8),
            Text('这可能会花费一些时间，请确认是否继续？',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('章节已刷新到最新内容'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 更新角色卡功能（使用 CharacterCardService）
  Future<void> _updateCharacterCards() async {
    if (_content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('章节内容为空，无法更新角色卡'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: ValueListenableBuilder(
              valueListenable: ValueNotifier(''),
              builder: (context, message, child) {
                return Text(message.isNotEmpty ? message : '正在更新角色卡...');
              },
            )),
          ],
        ),
      ),
    );

    try {
      // 使用 CharacterCardService 预览更新
      final service = CharacterCardService();
      final updatedCharacters = await service.previewCharacterUpdates(
        novel: widget.novel,
        chapterContent: _content,
        onProgress: (message) {
          debugPrint(message);
        },
      );

      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
      }

      // 显示角色预览对话框
      if (mounted) {
        await CharacterPreviewDialog.show(
          context,
          characters: updatedCharacters,
          onConfirmed: (selectedCharacters) async {
            // 保存用户确认的角色
            final savedCharacters = await service.saveCharacters(selectedCharacters);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('成功更新 ${savedCharacters.length} 个角色卡'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        );
      }

    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新角色卡失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
      case 'full_rewrite':
        _showFullRewriteDialog(); // 使用新的 Dialog Widget
        break;
      case 'update_character_cards':
        _updateCharacterCards();
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
        initialScrollSpeed: _scrollSpeed,
        onScrollSpeedChanged: (newSpeed) {
          setState(() {
            _scrollSpeed = newSpeed;
          });
          startAutoScroll(); // 速度改变后重新启动自动滚动以应用新速度（Mixin方法）
        },
      ),
    );
  }

  // 已弃用：特写输入逻辑已迁移到改写弹窗流程

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择要改写的段落'),
          backgroundColor: Colors.orange,
        ),
      );
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('全文重写完成并已保存'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('保存章节内容失败: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('保存失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('章节内容已保存'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('保存编辑内容失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentChapterIndex;
    final hasPrevious = currentIndex > 0;
    final hasNext =
        currentIndex != -1 && currentIndex < widget.chapters.length - 1;

    final paragraphs = _paragraphs;

    // 使用 ChangeNotifierProvider 包装整个页面
    return ChangeNotifierProvider(
      create: (_) => ReaderEditModeProvider(),
      child: Consumer<ReaderEditModeProvider>(
        builder: (context, editModeProvider, child) {

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
            if (editModeProvider.isEditMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('编辑模式', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          // 编辑模式切换按钮
          if (!editModeProvider.isEditMode)
            IconButton(
              onPressed: editModeProvider.toggleEditMode,
              tooltip: '进入编辑模式',
              icon: const Icon(Icons.edit_outlined),
            ),
          // 编辑完成按钮
          if (editModeProvider.isEditMode)
            IconButton(
              onPressed: () async {
                // 保存编辑内容并退出编辑模式
                await _saveEditedContent();
                editModeProvider.toggleEditMode();
              },
              tooltip: '完成编辑并保存',
              icon: const Icon(Icons.check, color: Colors.green),
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
                    Icon(Icons.refresh, size: 18, color: Colors.blue),
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
                    Icon(Icons.summarize, size: 18, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('总结'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'full_rewrite',
                child: Row(
                  children: [
                    Icon(Icons.auto_stories, size: 18, color: Colors.green),
                    SizedBox(width: 12),
                    Text('全文重写'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'update_character_cards',
                child: Row(
                  children: [
                    Icon(Icons.person_search, size: 18, color: Colors.purple),
                    SizedBox(width: 12),
                    Text('更新角色卡'),
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
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadChapterContent(resetScrollPosition: false),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // 主要内容区域
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // 使用 AutoScrollMixin 的滚动通知处理方法
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
                          final isSelected = _selectedParagraphIndices.contains(index);

                          return ParagraphWidget(
                            paragraph: paragraph,
                            index: index,
                            fontSize: _fontSize,
                            isCloseupMode: _isCloseupMode,
                            isEditMode: editModeProvider.isEditMode, // From Consumer
                            isSelected: isSelected,
                            onTap: _handleParagraphTap,
                            onLongPress: (idx) => _handleLongPress(idx), // _handleLongPress now accepts index
                            onContentChanged: (newContent) {
                              final updatedParagraphs = List<String>.from(paragraphs);
                              updatedParagraphs[index] = newContent;
                              setState(() {
                                _content = updatedParagraphs.join('\n');
                              });
                            },
                            onImageTap: (taskId, imageUrl, imageIndex) => handleImageTap(taskId, imageUrl, imageIndex), // Mixin方法
                            onImageDelete: () => deleteIllustrationByTaskId, // Mixin方法
                            generateVideoFromIllustration: generateVideoFromIllustration, // Mixin方法
                          );
                        },
                      ),
                    ), // NotificationListener 闭合
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
                              color: Colors.black.withValues(alpha: 0.1),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      hasPrevious ? _goToPreviousChapter : null,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('上一章'),
                                ),
                                Text(
                                  '${currentIndex + 1}/${widget.chapters.length}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                ElevatedButton.icon(
                                  onPressed: hasNext ? _goToNextChapter : null,
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
              onRewritePressed: () {
                _showParagraphRewriteDialog(); // 使用新的 Dialog Widget
              },
              onToggleCloseupMode: _toggleCloseupMode,
              onToggleAutoScroll: toggleAutoScroll, // Mixin method
            ),
    );
        },
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
  double get scrollSpeed => _scrollSpeed;

  // ========== IllustrationHandlerMixin 抽象字段实现 ==========

  @override
  Novel get novel => widget.novel;

  @override
  Chapter get currentChapter => _currentChapter;

  @override
  DatabaseService get databaseService => _databaseService;

  @override
  ApiServiceWrapper get apiService => _apiService;
}
