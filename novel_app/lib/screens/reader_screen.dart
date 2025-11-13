import 'dart:async';
import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../services/api_service_wrapper.dart';
import '../services/database_service.dart';
import '../services/dify_service.dart';
import '../widgets/highlighted_text.dart';

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

class _ReaderScreenState extends State<ReaderScreen> with TickerProviderStateMixin {
  final ApiServiceWrapper _apiService = ApiServiceWrapper();
  final DatabaseService _databaseService = DatabaseService();
  final ScrollController _scrollController = ScrollController();

  // 光标动画控制器
  late AnimationController _cursorController;
  late Animation<double> _cursorAnimation;

  late Chapter _currentChapter;
  String _content = '';
  bool _isLoading = true;
  String _errorMessage = '';
  double _fontSize = 18.0;

  // 特写模式相关状态
  bool _isCloseupMode = false;
  List<int> _selectedParagraphIndices = [];
  final ValueNotifier<String> _rewriteResultNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingRewriteNotifier =
      ValueNotifier<bool>(false);

  // 全文重写相关状态
  final ValueNotifier<String> _fullRewriteResultNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingFullRewriteNotifier =
      ValueNotifier<bool>(false);

  // 全文重写要求的用户输入缓存
  String _lastFullRewriteInput = '';

  // 总结相关状态
  final ValueNotifier<String> _summarizeResultNotifier =
      ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingSummarizeNotifier =
      ValueNotifier<bool>(false);

  // 预加载相关状态
  final Set<String> _preloadedChapterUrls = {};
  bool _isPreloading = false;

  // 自动滚动相关状态
  bool _isAutoScrolling = false;
  Timer? _autoScrollTimer;
  double _scrollSpeed = 1.0; // 滚动速度倍数，1.0为默认速度
  static const double _baseScrollSpeed = 50.0; // 基础滚动速度（像素/秒）

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;

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

    _initApi();
  }

  Future<void> _initApi() async {
    try {
      await _apiService.init();
      // 初始加载时不重置滚动位置，以保持搜索匹配跳转行为
      _loadChapterContent(resetScrollPosition: false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化API失败: $e';
      });
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _cursorController.dispose();
    _scrollController.dispose();
    _apiService.dispose();
    _rewriteResultNotifier.dispose();
    _isGeneratingRewriteNotifier.dispose();
    _fullRewriteResultNotifier.dispose();
    _isGeneratingFullRewriteNotifier.dispose();
    _summarizeResultNotifier.dispose();
    _isGeneratingSummarizeNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadChapterContent({bool resetScrollPosition = true}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _content = '';
    });

    try {
      final cachedContent =
          await _databaseService.getCachedChapter(_currentChapter.url);
      String content;

      if (cachedContent != null) {
        content = cachedContent;
        setState(() {
          _content = content;
          _isLoading = false;
        });
        _updateReadingProgress();

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

        // 开始预加载其他章节
        _startPreloadingChapters();
      } else {
        // 从网络获取内容
        try {
          content = await _apiService.getChapterContent(_currentChapter.url);

          // 验证内容有效性
          if (content.isNotEmpty && content.length > 50) {
            // 缓存有效内容
            await _databaseService.cacheChapter(
                widget.novel.url, _currentChapter, content);

            setState(() {
              _content = content;
              _isLoading = false;
            });
            _updateReadingProgress();

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

            // 开始预加载其他章节
            _startPreloadingChapters();
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = '章节内容为空或过短，请稍后重试';
            });
          }
        } catch (e) {
          // 网络获取失败，显示错误信息而不是将错误作为内容
          setState(() {
            _isLoading = false;
            _errorMessage = _getErrorMessage(e);
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载章节时发生错误: ${e.toString()}';
      });
    }
  }

  /// 根据异常类型返回用户友好的错误信息
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('请求过于频繁')) {
      return '请求过于频繁，请稍后重试';
    } else if (errorStr.contains('超时') || errorStr.contains('timeout')) {
      return '网络连接超时，请检查网络后重试';
    } else if (errorStr.contains('网络错误') ||
        errorStr.contains('SocketException')) {
      return '网络连接失败，请检查网络设置';
    } else if (errorStr.contains('状态码')) {
      return '服务器响应异常，请稍后重试';
    } else if (errorStr.contains('未能提取到有效的章节内容')) {
      return '无法解析章节内容，可能是网站结构变化';
    } else {
      return '获取章节内容失败，请稍后重试';
    }
  }

  Future<void> _updateReadingProgress() async {
    final chapterIndex = _currentChapter.chapterIndex ??
        widget.chapters.indexOf(_currentChapter);
    await _databaseService.updateLastReadChapter(
        widget.novel.url, chapterIndex);
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

  /// 开始预加载章节
  /// 优先加载后续章节，然后是前面的章节
  Future<void> _startPreloadingChapters() async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      final currentIndex =
          widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
      if (currentIndex == -1) return;

      // 构建预加载列表：优先后续章节
      final List<Chapter> chaptersToPreload = [];

      // 添加后续章节（优先）
      for (int i = currentIndex + 1;
          i < widget.chapters.length && chaptersToPreload.length < 10;
          i++) {
        chaptersToPreload.add(widget.chapters[i]);
      }

      // 添加前面的章节
      for (int i = currentIndex - 1;
          i >= 0 && chaptersToPreload.length < 15;
          i--) {
        chaptersToPreload.add(widget.chapters[i]);
      }

      // 后台预加载
      _preloadChaptersInBackground(chaptersToPreload);
    } finally {
      _isPreloading = false;
    }
  }

  /// 后台预加载章节
  Future<void> _preloadChaptersInBackground(List<Chapter> chapters) async {
    for (final chapter in chapters) {
      // 检查是否已预加载或已缓存
      if (_preloadedChapterUrls.contains(chapter.url)) continue;

      try {
        // 检查是否已缓存
        final cachedContent =
            await _databaseService.getCachedChapter(chapter.url);
        if (cachedContent != null) {
          _preloadedChapterUrls.add(chapter.url);
          continue;
        }

        // 延迟加载，避免请求过于频繁 (3-5秒随机延迟)
        final delaySeconds = 3 + (chapter.url.hashCode % 3);
        await Future.delayed(Duration(seconds: delaySeconds));

        // 从后端获取并缓存
        final content = await _apiService.getChapterContent(chapter.url);
        if (content.isNotEmpty) {
          await _databaseService.cacheChapter(
              widget.novel.url, chapter, content);
          _preloadedChapterUrls.add(chapter.url);
          debugPrint('预加载成功: ${chapter.title}');
        }
      } catch (e) {
        // 静默处理预加载错误，不影响用户阅读
        debugPrint('预加载章节失败: ${chapter.title}, 错误: $e');
      }
    }
  }

  void _goToPreviousChapter() {
    final currentIndex =
        widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    if (currentIndex > 0) {
      setState(() {
        _currentChapter = widget.chapters[currentIndex - 1];
      });
      _loadChapterContent(resetScrollPosition: true);
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是最后一章了')),
      );
    }
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('调整字体大小'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '示例文字',
                  style: TextStyle(fontSize: _fontSize),
                ),
                Slider(
                  value: _fontSize,
                  min: 12,
                  max: 32,
                  divisions: 20,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                    this.setState(() {});
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 开始自动滚动
  void _startAutoScroll() {
    if (_isAutoScrolling) return;

    setState(() {
      _isAutoScrolling = true;
    });

    const duration = Duration(milliseconds: 50); // 每50毫秒滚动一次
    final scrollStep =
        (_baseScrollSpeed * _scrollSpeed * 50) / 1000; // 每次滚动的像素数

    _autoScrollTimer = Timer.periodic(duration, (timer) {
      if (!_isAutoScrolling) {
        timer.cancel();
        return;
      }

      final currentPosition = _scrollController.offset;
      final maxPosition = _scrollController.position.maxScrollExtent;

      if (currentPosition >= maxPosition) {
        // 已滚动到底部，停止自动滚动
        _stopAutoScroll();
        return;
      }

      final newPosition = currentPosition + scrollStep;
      _scrollController.animateTo(
        newPosition.clamp(0.0, maxPosition),
        duration: duration,
        curve: Curves.linear,
      );
    });
  }

  // 停止自动滚动
  void _stopAutoScroll() {
    setState(() {
      _isAutoScrolling = false;
    });
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  // 切换自动滚动状态
  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
    } else {
      _startAutoScroll();
    }
  }

  // 刷新当前章节 - 删除本地缓存并重新获取最新内容
  Future<void> _refreshChapter() async {
    // 先显示确认对话框
    final shouldRefresh = await showDialog<bool>(
      context: context,
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
            Text('将删除本地缓存并从服务器重新获取最新内容'),
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

    try {
      // 显示加载状态
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // 删除当前章节的本地缓存
      await _databaseService.deleteChapterCache(_currentChapter.url);
      debugPrint('已删除章节缓存: ${_currentChapter.title}');

      // 重置滚动位置到顶部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });

      // 重新加载章节内容（强制从网络获取）
      await _loadChapterContentFromNetwork();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '刷新失败: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 强制从网络获取章节内容
  Future<void> _loadChapterContentFromNetwork() async {
    try {
      setState(() {
        _content = '';
        _errorMessage = '';
      });

      // 强制从网络获取内容（使用forceRefresh参数绕过后端缓存）
      final content = await _apiService.getChapterContent(_currentChapter.url, forceRefresh: true);

      // 验证内容有效性
      if (content.isNotEmpty && content.length > 50) {
        // 缓存新内容
        await _databaseService.cacheChapter(
            widget.novel.url, _currentChapter, content);

        setState(() {
          _content = content;
          _isLoading = false;
        });

        _updateReadingProgress();

        // 重新开始预加载其他章节
        _startPreloadingChapters();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('章节已刷新到最新内容'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取到的章节内容为空或过短，请稍后重试';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e);
      });
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
        _showSummarizeDialog();
        break;
      case 'full_rewrite':
        _showFullRewriteRequirementDialog();
        break;
      case 'closeup_mode':
        _toggleCloseupMode();
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
      builder: (context) => AlertDialog(
        title: const Text('调整滚动速度'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '当前速度: ${_scrollSpeed.toStringAsFixed(1)}x',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Slider(
                  value: _scrollSpeed,
                  min: 0.1,
                  max: 5.0,
                  divisions: 49,
                  label: '${_scrollSpeed.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    setState(() {
                      _scrollSpeed = value;
                    });
                    this.setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('慢 (0.1x)',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                    Text('快 (5.0x)',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
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

  // 获取选中的文本
  String _getSelectedText(List<String> paragraphs) {
    if (_selectedParagraphIndices.isEmpty) return '';
    return _selectedParagraphIndices
        .map((index) => paragraphs[index])
        .join('\n');
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
      builder: (context) => AlertDialog(
        title: const Text('输入改写要求'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: userInputController,
              decoration: const InputDecoration(
                hintText: '例如：增加细节描述、改变语气、加强情感表达等...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Text(
              '已选择 ${_selectedParagraphIndices.length} 个段落',
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
    _isGeneratingRewriteNotifier.value = true;
    _rewriteResultNotifier.value = '';

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

      final difyService = DifyService();

      // 使用流式 API
      await difyService.generateCloseUpStreaming(
        selectedParagraph: selectedText,
        userInput: userInput,
        currentChapterContent: _content,
        historyChaptersContent: historyChaptersContent,
        backgroundSetting: widget.novel.backgroundSetting ?? '',
        onChunk: (chunk) {
          debugPrint('🔥 onChunk 回调收到: "$chunk"');
          debugPrint('📝 当前result长度: ${_rewriteResultNotifier.value.length}');

          // 检查是否是完整内容的特殊标记
          final bool isCompleteContent = chunk.startsWith('<<COMPLETE_CONTENT>>');

          if (isCompleteContent) {
            debugPrint('🎯 检测到完整内容标记，直接替换');
            // 提取实际内容（移除特殊标记）
            final completeContent = chunk.substring('<<COMPLETE_CONTENT>>'.length);

            if (mounted) {
              _rewriteResultNotifier.value = completeContent;
              debugPrint('✅ 完整内容替换完成，长度: ${completeContent.length}');
            }
          } else {
            // 流式模式：追加内容
            final currentContent = _rewriteResultNotifier.value;
            final newContent = currentContent + chunk;

            debugPrint('📝 流式追加内容，新长度: ${newContent.length}');

            // 在主线程上立即更新ValueNotifier
            if (mounted) {
              _rewriteResultNotifier.value = newContent;
              debugPrint('✅ 更新后result长度: ${_rewriteResultNotifier.value.length}');
            }
          }

          // 使用scheduleMicrotask确保在下一帧前更新UI
          scheduleMicrotask(() {
            if (mounted) {
              setState(() {});
              debugPrint('🔄 microtask UI更新完成');
            }
          });
        },
        onComplete: () {
          debugPrint('✅ onComplete 回调被调用');
          debugPrint('📊 完成时result长度: ${_rewriteResultNotifier.value.length}');

          // 确保显示所有已接收的数据
          if (_rewriteResultNotifier.value.isNotEmpty) {
            debugPrint('📄 最终内容: "${_rewriteResultNotifier.value.substring(0, _rewriteResultNotifier.value.length > 100 ? 100 : _rewriteResultNotifier.value.length)}..."');
          }

          _isGeneratingRewriteNotifier.value = false;

          // 强制更新UI以确保最终内容正确显示
          if (mounted) {
            setState(() {});
          }
        },
      );
    } catch (e) {
      _isGeneratingRewriteNotifier.value = false;
      _rewriteResultNotifier.value = '生成失败: $e';

      // 同时显示 SnackBar 提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('改写生成失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // 确保在方法结束时状态正确（安全网）
    if (_isGeneratingRewriteNotifier.value) {
      debugPrint('安全网：强制结束生成状态');
      _isGeneratingRewriteNotifier.value = false;
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
                    child: ValueListenableBuilder<String>(
                      valueListenable: _rewriteResultNotifier,
                      builder: (context, resultValue, child) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _isGeneratingRewriteNotifier,
                          builder: (context, isGenerating, child) {
                            String displayText;
                            if (isGenerating && resultValue.isEmpty) {
                              displayText = '正在生成中...';
                            } else if (resultValue.isEmpty) {
                              displayText = '等待生成...';
                            } else {
                              displayText = resultValue;
                            }

                            debugPrint('🖼️ 弹窗显示: isGenerating=$isGenerating, resultValue长度=${resultValue.length}');
                            debugPrint('🔍 _rewriteResultNotifier.value长度: ${_rewriteResultNotifier.value.length}');

                            if (resultValue.isNotEmpty) {
                              debugPrint('📄 弹窗内容开头: "${resultValue.substring(0, resultValue.length > 50 ? 50 : resultValue.length)}..."');
                            } else {
                              debugPrint('⚠️ resultValue为空，显示: "$displayText"');
                            }

                            // 优化的流式显示界面
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 实时状态指示器
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isGenerating
                                        ? [Colors.orange.shade600, Colors.orange.shade800]
                                        : [Colors.green.shade600, Colors.green.shade800],
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
                                            isGenerating ? Icons.stream : Icons.check_circle,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isGenerating ? '实时生成中...' : '生成完成',
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
                                      Row(
                                        children: [
                                          Text(
                                            '已接收 ${resultValue.length} 字符',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                          if (resultValue.isNotEmpty) ...[
                                            const SizedBox(width: 16),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '流式展示',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 流式文本内容区域
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
                                  child: resultValue.isEmpty
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
                                                // 显示生成的文本，保持格式
                                                TextSpan(
                                                  text: resultValue,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    height: 1.6,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                // 如果正在生成，添加闪烁光标效果
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
                                const SizedBox(height: 8),
                                // 底部提示信息
                                if (!isGenerating && resultValue.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade800.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome, size: 12, color: Colors.green.shade300),
                                        const SizedBox(width: 4),
                                        Text(
                                          'AI内容已完整生成',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green.shade300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
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
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingRewriteNotifier,
              builder: (context, isGenerating, child) {
                return TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          final paragraphs = _content
                              .split('\n')
                              .where((p) => p.trim().isNotEmpty)
                              .toList();
                          _showRewriteRequirementDialog(paragraphs);
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中...' : '重写'),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isGeneratingRewriteNotifier,
              builder: (context, isGenerating, child) {
                return ValueListenableBuilder<String>(
                  valueListenable: _rewriteResultNotifier,
                  builder: (context, value, child) {
                    return ElevatedButton.icon(
                      onPressed: (isGenerating || value.isEmpty)
                          ? null
                          : () {
                              _replaceSelectedParagraphs();
                              Navigator.pop(dialogContext);
                            },
                      icon: const Icon(Icons.check),
                      label: const Text('替换'),
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

  // 替换选中的段落
  void _replaceSelectedParagraphs() async {
    if (_selectedParagraphIndices.isEmpty ||
        _rewriteResultNotifier.value.isEmpty) {
      return;
    }

    final paragraphs =
        _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

    // 替换选中的段落
    for (int i = _selectedParagraphIndices.length - 1; i >= 0; i--) {
      paragraphs.removeAt(_selectedParagraphIndices[i]);
    }
    paragraphs.insert(
        _selectedParagraphIndices.first, _rewriteResultNotifier.value);

    final newContent = paragraphs.join('\n');

    setState(() {
      _content = newContent;
      _selectedParagraphIndices.clear();
      _rewriteResultNotifier.value = '';
      _isCloseupMode = false;
    });

    // 保存修改后的内容到数据库
    try {
      await _databaseService.updateChapterContent(
          _currentChapter.url, newContent);
    } catch (e) {
      debugPrint('保存章节内容失败: $e');
    }
  }

  // 显示总结功能弹窗
  Future<void> _showSummarizeDialog() async {
    showDialog(
      context: context,
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
    _isGeneratingSummarizeNotifier.value = true;
    _summarizeResultNotifier.value = '';

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

      final difyService = DifyService();

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

      // 使用通用的流式 API
      await difyService.runWorkflowStreaming(
        inputs: inputs,
        onData: (data) {
          debugPrint('总结收到数据: $data');
          debugPrint('总结当前result长度: ${_summarizeResultNotifier.value.length}');
          _summarizeResultNotifier.value += data;
          debugPrint('总结更新后result长度: ${_summarizeResultNotifier.value.length}');
        },
        onError: (error) {
          debugPrint('总结错误: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('章节总结失败: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onDone: () {
          debugPrint('总结完成');
          _isGeneratingSummarizeNotifier.value = false;
        },
      );
    } catch (e) {
      _isGeneratingSummarizeNotifier.value = false;
      _summarizeResultNotifier.value = '生成失败: $e';

      // 同时显示 SnackBar 提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('章节总结失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // 确保在方法结束时状态正确（安全网）
    if (_isGeneratingSummarizeNotifier.value) {
      debugPrint('安全网：强制结束总结生成状态');
      _isGeneratingSummarizeNotifier.value = false;
    }
  }

  // 显示总结结果弹窗
  void _showSummarizeResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
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
                    child: ValueListenableBuilder<String>(
                      valueListenable: _summarizeResultNotifier,
                      builder: (context, resultValue, child) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: _isGeneratingSummarizeNotifier,
                          builder: (context, isGenerating, child) {
                            String displayText;
                            if (isGenerating && resultValue.isEmpty) {
                              displayText = '正在生成中...';
                            } else if (resultValue.isEmpty) {
                              displayText = '等待生成...';
                            } else {
                              displayText = resultValue;
                            }

                            debugPrint('总结弹窗显示: isGenerating=$isGenerating, resultValue长度=${resultValue.length}');

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
                        '您可以查看总结内容或关闭',
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
              valueListenable: _isGeneratingSummarizeNotifier,
              builder: (context, isGenerating, child) {
                return TextButton.icon(
                  onPressed: isGenerating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _showSummarizeDialog();
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(isGenerating ? '生成中...' : '重新总结'),
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

  // 显示全文重写要求输入弹窗
  Future<void> _showFullRewriteRequirementDialog() async {
    final userInputController =
        TextEditingController(text: _lastFullRewriteInput);
    final result = await showDialog<String>(
      context: context,
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

  // 生成全文重写内容（流式）
  Future<void> _generateFullRewrite(String userInput) async {
    _isGeneratingFullRewriteNotifier.value = true;
    _fullRewriteResultNotifier.value = '';

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

      final difyService = DifyService();

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

      // 使用通用的流式 API
      await difyService.runWorkflowStreaming(
        inputs: inputs,
        onData: (data) {
          debugPrint('全文重写收到数据: $data');
          debugPrint('全文重写当前result长度: ${_fullRewriteResultNotifier.value.length}');
          _fullRewriteResultNotifier.value += data;
          debugPrint('全文重写更新后result长度: ${_fullRewriteResultNotifier.value.length}');
        },
        onError: (error) {
          debugPrint('全文重写错误: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('全文重写失败: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onDone: () {
          debugPrint('全文重写完成');
          _isGeneratingFullRewriteNotifier.value = false;
        },
      );
    } catch (e) {
      _isGeneratingFullRewriteNotifier.value = false;
      _fullRewriteResultNotifier.value = '生成失败: $e';

      // 同时显示 SnackBar 提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('全文重写失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    // 确保在方法结束时状态正确（安全网）
    if (_isGeneratingFullRewriteNotifier.value) {
      debugPrint('安全网：强制结束全文重写生成状态');
      _isGeneratingFullRewriteNotifier.value = false;
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

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    final hasPrevious = currentIndex > 0;
    final hasNext =
        currentIndex != -1 && currentIndex < widget.chapters.length - 1;

    final paragraphs =
        _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentChapter.title,
          style: const TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        actions: [
          // 主要功能：自动滚动
          IconButton(
            icon: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleAutoScroll,
            tooltip: _isAutoScrolling ? '暂停自动滚动' : '开始自动滚动',
            color: _isAutoScrolling ? Colors.red : null,
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
                value: 'closeup_mode',
                child: Row(
                  children: [
                    Icon(
                      _isCloseupMode ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                      color: _isCloseupMode ? Colors.blue : null,
                    ),
                    const SizedBox(width: 12),
                    Text(_isCloseupMode ? '关闭特写模式' : '开启特写模式'),
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
                    ListView.builder(
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

                        return InkWell(
                          onTap: _isCloseupMode
                              ? () => _handleParagraphTap(index)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6.0, horizontal: 8.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.withValues(alpha: 0.2)
                                  : null,
                              border: isSelected
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : _isCloseupMode
                                      ? Border.all(
                                          color: Colors.blue
                                              .withValues(alpha: 0.3),
                                          width: 1)
                                      : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              paragraph.trim(),
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.8,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
      // 悬浮工具栏
      floatingActionButton: _buildFloatingActions(),
    );
  }

  // 构建悬浮动作组件
  Widget? _buildFloatingActions() {
    if (_content.isEmpty) return null;

    // 如果在特写模式下且有选中段落，显示改写按钮
    if (_isCloseupMode && _selectedParagraphIndices.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: () {
          final paragraphs =
              _content.split('\n').where((p) => p.trim().isNotEmpty).toList();
          _showRewriteRequirementDialog(paragraphs);
        },
        icon: const Icon(Icons.edit),
        label: const Text('改写'),
        backgroundColor: Colors.green,
        heroTag: 'rewrite',
      );
    }

    // 正常阅读模式下，只显示特写模式切换按钮
    return Padding(
      padding: const EdgeInsets.only(bottom: 120.0), // 避免与底部章节切换按钮重叠
      child: FloatingActionButton(
        onPressed: _toggleCloseupMode,
        tooltip: _isCloseupMode ? '关闭特写模式' : '开启特写模式',
        heroTag: 'closeup_mode',
        backgroundColor: _isCloseupMode ? Colors.blue : null,
        child: Icon(_isCloseupMode ? Icons.visibility : Icons.visibility_off),
      ),
    );
  }
}
