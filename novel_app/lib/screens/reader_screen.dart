import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/character.dart';
import '../models/search_result.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';
import '../services/dify_service.dart';
import '../services/preload_service.dart';
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

import '../utils/character_matcher.dart';
import '../utils/media_markup_parser.dart';
import '../providers/reader_edit_mode_provider.dart';
import '../controllers/paragraph_rewrite_controller.dart';
import '../controllers/summarize_controller.dart';
import '../controllers/reader_content_controller.dart';
import '../widgets/reader/paragraph_rewrite_dialog.dart';
import '../widgets/reader/chapter_summary_dialog.dart';
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
  final ParagraphRewriteController _paragraphRewriteController = ParagraphRewriteController();
  final SummarizeController _summarizeController = SummarizeController();

  // ========== 新增：ReaderContentController ==========
  late ReaderContentController _contentController;

  // ========== 便捷访问器（向后兼容） ==========
  String get _content => _contentController.content;
  set _content(String value) => _contentController.content = value;
  bool get _isLoading => _contentController.isLoading;
  String get _errorMessage => _contentController.errorMessage;

  // 光标动画控制器
  late AnimationController _cursorController;
  late Animation<double> _cursorAnimation;

  late Chapter _currentChapter;
  double _fontSize = 18.0;

  // 特写模式相关状态
  bool _isCloseupMode = false;
  List<int> _selectedParagraphIndices = [];

  // 全文重写相关状态
  final ValueNotifier<String> _fullRewriteResultNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingFullRewriteNotifier =
      ValueNotifier<bool>(false);

  // 全文重写要求的用户输入缓存
  String _lastFullRewriteInput = '';

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

    // 初始化自动滚动控制器
    initAutoScroll(scrollController: _scrollController);

    // 初始化光标动画
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 530),
      vsync: this,
    );
    _cursorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cursorController,
      curve: Curves.easeInOut,
    ));

    _cursorController.repeat(reverse: true);

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
  // 旧代码已注释，将在测试通过后删除

  /*
  Future<void> _initApi() async {
    try {
      await _apiService.init();
      // 初始加载时不重置滚动位置，以保持搜索匹配跳转行为
      _loadChapterContent(resetScrollPosition: false);
      // 新系统不需要 _loadIllustrations()
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化API失败: $e';
      });
    }
  }
  */

  @override
  void dispose() {
    disposeAutoScroll(); // 清理自动滚动资源（AutoScrollMixin）
    _cursorController.dispose();
    _scrollController.dispose();
    _fullRewriteResultNotifier.dispose();
    _isGeneratingFullRewriteNotifier.dispose();
    _paragraphRewriteController.dispose();
    _summarizeController.dispose();
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
    if (_isCloseupMode) return; // 特写模式下不处理长按

    final paragraphs = _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

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
  // _handleTouchStart 和 _handleTouchEnd 已删除 - 不再需要触摸暂停功能
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

  // 更新角色卡功能
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
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('正在分析章节内容并更新角色信息...')),
          ],
        ),
      ),
    );

    try {
      debugPrint('=== 开始更新角色卡 ===');
      debugPrint('小说: ${widget.novel.title}');
      debugPrint('章节: ${_currentChapter.title}');

      // 准备Dify参数
      final updateData = await CharacterMatcher.prepareUpdateData(
        widget.novel.url,
        _content,
      );

      debugPrint('章节内容长度: ${updateData['chapters_content']!.length}');
      debugPrint('角色信息: ${updateData['roles']}');

      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
      }

      // 调用Dify服务更新角色信息
      final difyService = DifyService();
      final updatedCharacters = await difyService.updateCharacterCards(
        chaptersContent: updateData['chapters_content']!,
        roles: updateData['roles']!,
        novelUrl: widget.novel.url,
        backgroundSetting: widget.novel.backgroundSetting ?? '',
      );

      debugPrint('=== Dify返回角色数量: ${updatedCharacters.length} ===');

      // 显示角色预览对话框
      if (mounted) {
        await CharacterPreviewDialog.show(
          context,
          characters: updatedCharacters,
          onConfirmed: (selectedCharacters) async {
            debugPrint('=== 用户确认保存角色: ${selectedCharacters.map((c) => c.name).toList()} ===');
            await _saveUpdatedCharacters(selectedCharacters);
          },
        );
      }

    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
      }

      debugPrint('=== 更新角色卡失败: $e ===');

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

  // 保存更新后的角色
  Future<void> _saveUpdatedCharacters(List<Character> selectedCharacters) async {
    try {
      debugPrint('=== 开始保存角色到数据库 ===');

      // 显示保存进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('正在保存角色信息...')),
            ],
          ),
        ),
      );

      // 使用批量更新方法保存角色
      final databaseService = DatabaseService();
      final savedCharacters = await databaseService.batchUpdateCharacters(selectedCharacters);

      // 关闭保存进度对话框
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功更新 ${savedCharacters.length} 个角色卡'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      debugPrint('=== 角色保存完成: ${savedCharacters.length} 个 ===');

    } catch (e) {
      // 关闭保存进度对话框
      if (mounted) {
        Navigator.pop(context);
      }

      debugPrint('=== 保存角色失败: $e ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存角色失败: $e'),
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
        _showFullRewriteRequirementDialog();
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
    setState(() {
      _isCloseupMode = !_isCloseupMode;
      if (!_isCloseupMode) {
        _selectedParagraphIndices.clear();
      }
    });
  }

  // 处理段落点击
  void _handleParagraphTap(int index) {
    if (!_isCloseupMode) return;

    // 检查段落是否为媒体标记（插图、视频等），如果是则不允许选择
    final paragraphs = _content.split('\n').where((p) => p.trim().isNotEmpty).toList();
    if (index < paragraphs.length && MediaMarkupParser.isMediaMarkup(paragraphs[index])) {
      // 媒体标记段落不允许在特写模式下选择
      return;
    }

    setState(() {
      if (_selectedParagraphIndices.contains(index)) {
        _selectedParagraphIndices.remove(index);
      } else {
        _selectedParagraphIndices.add(index);
      }

      // 排序
      _selectedParagraphIndices.sort();

      // 检查是否连续
      if (!_isConsecutive(_selectedParagraphIndices)) {
        // 如果不连续，只保留当前点击的段落
        _selectedParagraphIndices = [index];
      }
    });
  }

  // 检查数组是否连续
  bool _isConsecutive(List<int> indices) {
    if (indices.length <= 1) return true;
    for (int i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) {
        return false;
      }
    }
    return true;
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
            _selectedParagraphIndices.clear();
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

  // ========== 以下为旧方法（已弃用，保留用于向后兼容）==========

  // 获取选中的文本（支持插图段落）
  String _getSelectedText(List<String> paragraphs) {
    if (_selectedParagraphIndices.isEmpty) return '';

    final selectedTexts = <String>[];

    for (final index in _selectedParagraphIndices) {
      if (index < 0 || index >= paragraphs.length) continue;

      final paragraph = paragraphs[index];

      // 如果是插图标记，转换为描述性文本
      if (MediaMarkupParser.isMediaMarkup(paragraph)) {
        final markup = MediaMarkupParser.parseMediaMarkup(paragraph).first;
        if (markup.isIllustration) {
          selectedTexts.add('[插图：此处应显示图片内容，taskId: ${markup.id}]');
        } else {
          selectedTexts.add('[${markup.type}：${markup.id}]');
        }
      } else {
        selectedTexts.add(paragraph.trim());
      }
    }

    return selectedTexts.join('\n\n'); // 用双空行分隔，保持结构清晰
  }

  // 改写要求的用户输入缓存
  String _lastRewriteInput = '';

  // 打开改写要求输入弹窗
  Future<void> _showRewriteRequirementDialog(List<String> paragraphs) async {
    final selectedText = _getSelectedText(paragraphs);
    if (selectedText.isEmpty) return;

    final userInputController = TextEditingController(text: _lastRewriteInput);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: const Text('输入改写要求'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已选择 ${_selectedParagraphIndices.length} 个段落',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userInputController,
                decoration: const InputDecoration(
                  hintText: '例如：增加细节描述、改变语气、加强情感表达等...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, userInputController.text);
            },
            child: const Text('确认改写'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _lastRewriteInput = result; // 保存用户输入
      _generateRewrite(selectedText, result);
    }
  }

  // 生成改写内容（流式）
  Future<void> _generateRewrite(String selectedText, String userInput) async {
    // 显示流式结果弹窗
    _showRewriteResultDialog();

    try {
      final List<String> historyChaptersContent = [];
      final currentIndex =
          widget.chapters.indexWhere((c) => c.url == _currentChapter.url);

      if (currentIndex > 1) {
        final prevChapter2 = widget.chapters[currentIndex - 2];
        final content =
            await _databaseService.getCachedChapter(prevChapter2.url) ??
                await _apiService.getChapterContent(prevChapter2.url);
        historyChaptersContent.add('历史章节: ${prevChapter2.title}\n\n$content');
      }
      if (currentIndex > 0) {
        final prevChapter1 = widget.chapters[currentIndex - 1];
        final content =
            await _databaseService.getCachedChapter(prevChapter1.url) ??
                await _apiService.getChapterContent(prevChapter1.url);
        historyChaptersContent.add('历史章节: ${prevChapter1.title}\n\n$content');
      }

      // 特写功能不使用角色选择
      const String rolesInfo = '无特定角色出场';

      // 获取AI作家设定
      final prefs = await SharedPreferences.getInstance();
      final aiWriterSetting = prefs.getString('ai_writer_prompt') ?? '';

      // 构建输入参数
      final inputs = {
        'user_input': userInput,
        'cmd': '特写',
        'ai_writer_setting': aiWriterSetting,
        'history_chapters_content': historyChaptersContent.join('\n\n'),
        'current_chapter_content': _content,
        'choice_content': selectedText,
        'background_setting': widget.novel.backgroundSetting ?? '',
        'roles': rolesInfo,
      };

      // 调用控制器执行生成
      await _paragraphRewriteController.generateRewrite(inputs: inputs);

    } catch (e) {
      debugPrint('❌ 准备改写内容时发生异常: $e');
      // 可以选择通过controller报告错误
      // _paragraphRewriteController.setError('准备改写时失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 构建闪烁光标组件
  Widget _buildCursor() {
    return AnimatedBuilder(
      animation: _cursorAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _cursorAnimation.value,
          child: Container(
            width: 2,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  // 显示改写结果弹窗
  void _showRewriteResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: _paragraphRewriteController,
          builder: (context, child) {
            final isGenerating = _paragraphRewriteController.isLoading;
            final resultValue = _paragraphRewriteController.streamedContent;
            final error = _paragraphRewriteController.error;

            String displayText;
            if (isGenerating && resultValue.isEmpty) {
              displayText = '正在生成中...';
            } else if (error != null) {
              displayText = '生成失败: $error';
            } else if (resultValue.isEmpty) {
              displayText = '等待生成...';
            } else {
              displayText = resultValue;
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('改写结果'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        border: Border.all(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isGenerating
                                      ? [Colors.orange.shade600, Colors.orange.shade800]
                                      : (error != null
                                          ? [Colors.red.shade600, Colors.red.shade800]
                                          : [Colors.green.shade600, Colors.green.shade800]),
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isGenerating
                                            ? Icons.stream
                                            : (error != null ? Icons.error_outline : Icons.check_circle),
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isGenerating
                                            ? '实时生成中...'
                                            : (error != null ? '生成失败' : '生成完成'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isGenerating)
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '已接收 ${resultValue.length} 字符',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              constraints: const BoxConstraints(
                                maxHeight: 250,
                                minHeight: 100,
                              ),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade700.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: (resultValue.isEmpty && error == null)
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isGenerating) ...[
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        Text(
                                          isGenerating ? '等待AI生成内容...' : '暂无内容',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: SelectableText.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: displayText,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.6,
                                                color: error != null ? Colors.red.shade300 : Colors.white,
                                              ),
                                            ),
                                            if (isGenerating)
                                              WidgetSpan(
                                                child: _buildCursor(),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '你可以选择替换原文、重新改写或关闭',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext); // 关闭当前弹窗后再打开新弹窗
                          final paragraphs = _content
                              .split('\n')
                              .where((p) => p.trim().isNotEmpty)
                              .toList();
                          _showRewriteRequirementDialog(paragraphs);
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中...' : '重写'),
                ),
                ElevatedButton.icon(
                  onPressed: (isGenerating || resultValue.isEmpty || error != null)
                      ? null
                      : () {
                          _replaceSelectedParagraphs();
                          Navigator.pop(dialogContext);
                        },
                  icon: const Icon(Icons.check),
                  label: const Text('替换'),
                ),
                TextButton(
                  onPressed: () {
                    _paragraphRewriteController.cancel(); // 确保取消流
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 替换选中的段落（支持插图段落处理）
  Future<void> _replaceSelectedParagraphs() async {
    if (_selectedParagraphIndices.isEmpty ||
        _paragraphRewriteController.streamedContent.isEmpty) {
      return;
    }

    final paragraphs =
        _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

    // 分析选中的段落，检查是否包含插图
    final selectedIllustrations = <MediaMarkup>[];
    for (final index in _selectedParagraphIndices) {
      if (index < 0 || index >= paragraphs.length) continue;

      final paragraph = paragraphs[index];
      if (MediaMarkupParser.isMediaMarkup(paragraph)) {
        final markup = MediaMarkupParser.parseMediaMarkup(paragraph).first;
        if (markup.isIllustration) {
          selectedIllustrations.add(markup);
        }
      }
    }

    // 如果有插图，询问用户如何处理
    if (selectedIllustrations.isNotEmpty) {
      final action = await _showIllustrationHandlingDialog(selectedIllustrations);
      if (action == null) {
        // 用户取消操作
        return;
      }

      // 根据用户选择处理插图
      if (action == 'keep_illustrations') {
        // 保留插图：不删除插图段落，只替换文本段落
        await _replaceTextParagraphsOnly(paragraphs);
        return;
      }
    }

    // 直接替换所有选中的段落
    await _performReplacement(paragraphs);
  }

  /// 显示插图处理选择对话框
  Future<String?> _showIllustrationHandlingDialog(List<MediaMarkup> illustrations) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('插图处理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('改写区域包含 ${illustrations.length} 个插图，您希望如何处理？'),
            const SizedBox(height: 12),
            ...illustrations.map((markup) => Text(
              '• 插图 (ID: ${markup.id})',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace_all'),
            child: const Text('全部替换'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'keep_illustrations'),
            child: const Text('保留插图'),
          ),
        ],
      ),
    );
  }

  /// 只替换文本段落，保留插图段落
  Future<void> _replaceTextParagraphsOnly(List<String> paragraphs) async {
    final textIndices = <int>[];

    // 找出要替换的文本段落索引
    for (final index in _selectedParagraphIndices) {
      if (index < 0 || index >= paragraphs.length) continue;

      final paragraph = paragraphs[index];
      if (!MediaMarkupParser.isMediaMarkup(paragraph)) {
        textIndices.add(index);
      }
    }

    // 如果没有文本段落需要替换，直接返回
    if (textIndices.isEmpty) {
      setState(() {
        _selectedParagraphIndices.clear();
        _isCloseupMode = false;
      });
      return;
    }

    // 替换文本段落
    final updatedParagraphs = List<String>.from(paragraphs);
    for (int i = textIndices.length - 1; i >= 0; i--) {
      updatedParagraphs.removeAt(textIndices[i]);
    }
    updatedParagraphs.insert(textIndices.first, _paragraphRewriteController.streamedContent);

    final newContent = updatedParagraphs.join('\n');

    setState(() {
      _content = newContent;
      _selectedParagraphIndices.clear();
      _isCloseupMode = false;
    });

    // 保存修改后的内容到数据库
    try {
      await _databaseService.updateChapterContent(_currentChapter.url, newContent);
    } catch (e) {
      debugPrint('保存章节内容失败: $e');
    }
  }

  /// 执行段落替换
  Future<void> _performReplacement(List<String> paragraphs) async {
    // 从后往前删除，避免索引错乱
    for (int i = _selectedParagraphIndices.length - 1; i >= 0; i--) {
      final index = _selectedParagraphIndices[i];
      if (index >= 0 && index < paragraphs.length) {
        paragraphs.removeAt(index);
      }
    }

    // 插入生成的内容
    paragraphs.insert(_selectedParagraphIndices.first, _paragraphRewriteController.streamedContent);

    final newContent = paragraphs.join('\n');

    setState(() {
      _content = newContent;
      _selectedParagraphIndices.clear();
      _isCloseupMode = false;
    });

    // 保存修改后的内容到数据库
    try {
      await _databaseService.updateChapterContent(_currentChapter.url, newContent);
    } catch (e) {
      debugPrint('保存章节内容失败: $e');
    }
  }

  // 显示总结功能弹窗
  Future<void> _showSummarizeDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.summarize, color: Colors.orange),
            SizedBox(width: 8),
            Text('章节总结'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将对当前章节内容进行总结',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '提示：AI将提取章节的核心内容和关键情节',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateSummarize();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('开始总结'),
          ),
        ],
      ),
    );
  }

  // 生成章节总结（流式）
  Future<void> _generateSummarize() async {
    // 显示流式结果弹窗
    _showSummarizeResultDialog();

    try {
      final List<String> historyChaptersContent = [];
      final currentIndex =
          widget.chapters.indexWhere((c) => c.url == _currentChapter.url);

      // 获取历史章节内容（最多前2章）
      if (currentIndex > 1) {
        final prevChapter2 = widget.chapters[currentIndex - 2];
        final content =
            await _databaseService.getCachedChapter(prevChapter2.url) ??
                await _apiService.getChapterContent(prevChapter2.url);
        historyChaptersContent.add('历史章节: ${prevChapter2.title}\n\n$content');
      }
      if (currentIndex > 0) {
        final prevChapter1 = widget.chapters[currentIndex - 1];
        final content =
            await _databaseService.getCachedChapter(prevChapter1.url) ??
                await _apiService.getChapterContent(prevChapter1.url);
        historyChaptersContent.add('历史章节: ${prevChapter1.title}\n\n$content');
      }

      // 构建总结的参数
      final inputs = {
        'user_input': '总结',
        'cmd': '总结',
        'history_chapters_content': historyChaptersContent.join('\n\n'),
        'current_chapter_content': _content,
        'choice_content': '',
        'ai_writer_setting': '',
        'background_setting':
            widget.novel.backgroundSetting ?? widget.novel.description ?? '',
        'next_chapter_overview': '',
        'characters_info': '',
      };

      // 调用控制器执行
      await _summarizeController.generateSummary(inputs: inputs);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('准备总结时出错: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 显示总结结果弹窗
  void _showSummarizeResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: _summarizeController,
          builder: (context, child) {
            final isGenerating = _summarizeController.isLoading;
            final resultValue = _summarizeController.streamedContent;
            final error = _summarizeController.error;

            String displayText;
            if (isGenerating && resultValue.isEmpty) {
              displayText = '正在生成中...';
            } else if (error != null) {
              displayText = '生成失败: $error';
            } else if (resultValue.isEmpty) {
              displayText = '等待生成...';
            } else {
              displayText = resultValue;
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.summarize, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('章节总结'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        border: Border.all(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          displayText,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: error != null ? Colors.red.shade300 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            '您可以查看总结内容或关闭',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext); // 关闭当前弹窗后再打开新弹窗
                          _showSummarizeDialog();
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中...' : '重新总结'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示全文重写要求输入弹窗
  Future<void> _showFullRewriteRequirementDialog() async {
    final userInputController =
        TextEditingController(text: _lastFullRewriteInput);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_stories, color: Colors.green),
            SizedBox(width: 8),
            Text('全文重写'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将对整章内容进行重写',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: userInputController,
              decoration: const InputDecoration(
                labelText: '重写要求',
                hintText: '例如：改变写作风格、增加细节描写、调整情节节奏等...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            Text(
              '提示：AI将根据你的要求重新创作整章内容',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, userInputController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('开始重写'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _lastFullRewriteInput = result; // 保存用户输入
      _generateFullRewrite(result);
    }
  }

  // 生成全文重写内容（流式）- 使用 DifyStreamingMixin
  Future<void> _generateFullRewrite(String userInput) async {
    // 初始化状态
    _fullRewriteResultNotifier.value = '';
    _isGeneratingFullRewriteNotifier.value = true;

    // 显示流式结果弹窗
    _showFullRewriteResultDialog();

    try {
      final List<String> historyChaptersContent = [];
      final currentIndex =
          widget.chapters.indexWhere((c) => c.url == _currentChapter.url);

      // 获取历史章节内容（最多前2章）
      if (currentIndex > 1) {
        final prevChapter2 = widget.chapters[currentIndex - 2];
        final content =
            await _databaseService.getCachedChapter(prevChapter2.url) ??
                await _apiService.getChapterContent(prevChapter2.url);
        historyChaptersContent.add('历史章节: ${prevChapter2.title}\n\n$content');
      }
      if (currentIndex > 0) {
        final prevChapter1 = widget.chapters[currentIndex - 1];
        final content =
            await _databaseService.getCachedChapter(prevChapter1.url) ??
                await _apiService.getChapterContent(prevChapter1.url);
        historyChaptersContent.add('历史章节: ${prevChapter1.title}\n\n$content');
      }

      // 构建全文重写的参数
      final inputs = {
        'user_input': userInput,
        'cmd': '', // 空的cmd参数
        'history_chapters_content': historyChaptersContent.join('\n\n'),
        'current_chapter_content': _content,
        'choice_content': '', // 空的choice_content参数
        'ai_writer_setting': '',
        'background_setting':
            widget.novel.backgroundSetting ?? widget.novel.description ?? '',
        'next_chapter_overview': '',
        'characters_info': '',
      };

      // 使用统一的流式方法 - 只需要25行（原来是91行）！
      await callDifyStreaming(
        inputs: inputs,
        onChunk: (chunk) {
          debugPrint('全文重写收到数据: $chunk');
          debugPrint('全文重写当前result长度: ${_fullRewriteResultNotifier.value.length}');
          _fullRewriteResultNotifier.value += chunk;
          debugPrint('全文重写更新后result长度: ${_fullRewriteResultNotifier.value.length}');
        },
        onComplete: (fullContent) {
          debugPrint('全文重写完成');
          _isGeneratingFullRewriteNotifier.value = false;
        },
        onError: (error) {
          debugPrint('全文重写错误: $error');
          _isGeneratingFullRewriteNotifier.value = false;
        },
        showErrorSnackBar: true,
        errorMessagePrefix: '全文重写失败',
      );
    } catch (e) {
      _isGeneratingFullRewriteNotifier.value = false;
      _fullRewriteResultNotifier.value = '生成失败: $e';
    }
  }

  // 显示全文重写结果弹窗
  void _showFullRewriteResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_stories, color: Colors.green),
              SizedBox(width: 8),
              Text('全文重写结果'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    border: Border.all(color: Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _fullRewriteResultNotifier,
                      builder: (context, resultValue, child) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _isGeneratingFullRewriteNotifier,
                          builder: (context, isGenerating, child) {
                            String displayText;
                            if (isGenerating && resultValue.isEmpty) {
                              displayText = '正在生成中...';
                            } else if (resultValue.isEmpty) {
                              displayText = '等待生成...';
                            } else {
                              displayText = resultValue;
                            }

                            debugPrint('全文重写弹窗显示: isGenerating=$isGenerating, resultValue长度=${resultValue.length}');

                            return SelectableText(
                              displayText,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.white,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '你可以选择替换全文、重新生成或关闭',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingFullRewriteNotifier,
              builder: (context, isGenerating, child) {
                return TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _showFullRewriteRequirementDialog();
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中...' : '重新生成'),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingFullRewriteNotifier,
              builder: (context, isGenerating, child) {
                return ValueListenableBuilder<String>(
                  valueListenable: _fullRewriteResultNotifier,
                  builder: (context, value, child) {
                    return ElevatedButton.icon(
                      onPressed: (isGenerating || value.isEmpty)
                          ? null
                          : () {
                              _replaceFullContent();
                              Navigator.pop(dialogContext);
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('替换全文'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    );
                  },
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  // 替换全文内容
  void _replaceFullContent() async {
    if (_fullRewriteResultNotifier.value.isEmpty) return;

    final newContent = _fullRewriteResultNotifier.value;

    setState(() {
      _content = newContent;
      _fullRewriteResultNotifier.value = '';
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
    final currentIndex =
        widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    final hasPrevious = currentIndex > 0;
    final hasNext =
        currentIndex != -1 && currentIndex < widget.chapters.length - 1;

    final paragraphs =
        _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

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
