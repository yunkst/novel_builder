import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/novel_crawler_service.dart';
import '../services/database_service.dart';
import '../services/dify_service.dart';

class ReaderScreen extends StatefulWidget {
  final Novel novel;
  final Chapter chapter;
  final List<Chapter> chapters;

  const ReaderScreen({
    super.key,
    required this.novel,
    required this.chapter,
    required this.chapters,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final NovelCrawlerService _crawlerService = NovelCrawlerService();
  final DatabaseService _databaseService = DatabaseService();
  final ScrollController _scrollController = ScrollController();

  late Chapter _currentChapter;
  String _content = '';
  bool _isLoading = true;
  String _errorMessage = '';
  double _fontSize = 18.0;

  // 特写模式相关状态
  bool _isCloseupMode = false;
  List<int> _selectedParagraphIndices = [];
  final ValueNotifier<String> _rewriteResultNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isGeneratingRewriteNotifier = ValueNotifier<bool>(false);

  // 预加载相关状态
  final Set<String> _preloadedChapterUrls = {};
  bool _isPreloading = false;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _loadChapterContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _crawlerService.dispose();
    _rewriteResultNotifier.dispose();
    _isGeneratingRewriteNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadChapterContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _content = '';
    });

    try {
      final cachedContent = await _databaseService.getCachedChapter(_currentChapter.url);
      String content;
      if (cachedContent != null) {
        content = cachedContent;
      } else {
        content = await _crawlerService.getChapterContent(_currentChapter.url);
        if (content.isNotEmpty) {
          await _databaseService.cacheChapter(widget.novel.url, _currentChapter, content);
        }
      }

      if (content.isNotEmpty) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
        _updateReadingProgress();
        // 开始预加载其他章节
        _startPreloadingChapters();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '未能获取章节内容';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }

  Future<void> _updateReadingProgress() async {
    final chapterIndex = _currentChapter.chapterIndex ?? widget.chapters.indexOf(_currentChapter);
    await _databaseService.updateLastReadChapter(widget.novel.url, chapterIndex);
  }

  /// 开始预加载章节
  /// 优先加载后续章节，然后是前面的章节
  Future<void> _startPreloadingChapters() async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      final currentIndex = widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
      if (currentIndex == -1) return;

      // 构建预加载列表：优先后续章节
      final List<Chapter> chaptersToPreload = [];

      // 添加后续章节（优先）
      for (int i = currentIndex + 1; i < widget.chapters.length && chaptersToPreload.length < 10; i++) {
        chaptersToPreload.add(widget.chapters[i]);
      }

      // 添加前面的章节
      for (int i = currentIndex - 1; i >= 0 && chaptersToPreload.length < 15; i--) {
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
        final cachedContent = await _databaseService.getCachedChapter(chapter.url);
        if (cachedContent != null) {
          _preloadedChapterUrls.add(chapter.url);
          continue;
        }

        // 延迟加载，避免过快
        await Future.delayed(const Duration(milliseconds: 800));

        // 爬取并缓存
        final content = await _crawlerService.getChapterContent(chapter.url);
        if (content.isNotEmpty) {
          await _databaseService.cacheChapter(widget.novel.url, chapter, content);
          _preloadedChapterUrls.add(chapter.url);
        }
      } catch (e) {
        // 静默处理预加载错误，不影响用户阅读
        print('预加载章节失败: ${chapter.title}, 错误: $e');
      }
    }
  }

  void _goToPreviousChapter() {
    final currentIndex = widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    if (currentIndex > 0) {
      setState(() {
        _currentChapter = widget.chapters[currentIndex - 1];
      });
      _loadChapterContent();
      _scrollController.jumpTo(0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是第一章了')),
      );
    }
  }

  void _goToNextChapter() {
    final currentIndex = widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    if (currentIndex != -1 && currentIndex < widget.chapters.length - 1) {
      setState(() {
        _currentChapter = widget.chapters[currentIndex + 1];
      });
      _loadChapterContent();
      _scrollController.jumpTo(0);
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

  Future<void> _showCloseUpDialog(String selectedText) async {
    final userInputController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('特写输入'),
        content: TextField(
          controller: userInputController,
          decoration: const InputDecoration(
            hintText: '请输入你的要求...',
          ),
          autofocus: true,
          maxLines: 3,
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
            child: const Text('生成'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _generateCloseUp(selectedText, result);
    }
  }

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

  // 打开改写要求输入弹窗
  Future<void> _showRewriteRequirementDialog(List<String> paragraphs) async {
    final selectedText = _getSelectedText(paragraphs);
    if (selectedText.isEmpty) return;

    final userInputController = TextEditingController();
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
      final currentIndex = widget.chapters.indexWhere((c) => c.url == _currentChapter.url);

      if (currentIndex > 1) {
        final prevChapter2 = widget.chapters[currentIndex - 2];
        final content = await _databaseService.getCachedChapter(prevChapter2.url) ?? await _crawlerService.getChapterContent(prevChapter2.url);
        historyChaptersContent.add('历史章节: ${prevChapter2.title}\n\n$content');
      }
      if (currentIndex > 0) {
        final prevChapter1 = widget.chapters[currentIndex - 1];
        final content = await _databaseService.getCachedChapter(prevChapter1.url) ?? await _crawlerService.getChapterContent(prevChapter1.url);
        historyChaptersContent.add('历史章节: ${prevChapter1.title}\n\n$content');
      }

      final difyService = DifyService();

      // 使用流式 API
      await difyService.generateCloseUpStreaming(
        selectedParagraph: selectedText,
        userInput: userInput,
        currentChapterContent: _content,
        historyChaptersContent: historyChaptersContent,
        onChunk: (chunk) {
          print('onChunk 回调收到: $chunk');
          _rewriteResultNotifier.value += chunk;
        },
        onComplete: () {
          print('onComplete 回调被调用');
          _isGeneratingRewriteNotifier.value = false;
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
                      builder: (context, value, child) {
                        return Text(
                          value.isEmpty ? '正在生成中...' : value,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.white,
                          ),
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
                          final paragraphs = _content.split('\n').where((p) => p.trim().isNotEmpty).toList();
                          final selectedText = _getSelectedText(paragraphs);
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
  void _replaceSelectedParagraphs() {
    if (_selectedParagraphIndices.isEmpty || _rewriteResultNotifier.value.isEmpty) return;

    final paragraphs = _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

    // 替换选中的段落
    for (int i = _selectedParagraphIndices.length - 1; i >= 0; i--) {
      paragraphs.removeAt(_selectedParagraphIndices[i]);
    }
    paragraphs.insert(_selectedParagraphIndices.first, _rewriteResultNotifier.value);

    setState(() {
      _content = paragraphs.join('\n');
      _selectedParagraphIndices.clear();
      _rewriteResultNotifier.value = '';
      _isCloseupMode = false;
    });
  }

  Future<void> _generateCloseUp(String selectedText, String userInput) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在生成中...'),
          ],
        ),
      ),
    );

    try {
      final List<String> historyChaptersContent = [];
      final currentIndex = widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
      
      if (currentIndex > 1) {
        final prevChapter2 = widget.chapters[currentIndex - 2];
        final content = await _databaseService.getCachedChapter(prevChapter2.url) ?? await _crawlerService.getChapterContent(prevChapter2.url);
        historyChaptersContent.add('历史章节: ${prevChapter2.title}\n\n$content');
      }
      if (currentIndex > 0) {
        final prevChapter1 = widget.chapters[currentIndex - 1];
        final content = await _databaseService.getCachedChapter(prevChapter1.url) ?? await _crawlerService.getChapterContent(prevChapter1.url);
        historyChaptersContent.add('历史章节: ${prevChapter1.title}\n\n$content');
      }

      final difyService = DifyService();
      final generatedText = await difyService.generateCloseUp(
        selectedParagraph: selectedText,
        userInput: userInput,
        currentChapterContent: _content,
        historyChaptersContent: historyChaptersContent,
      );

      if (mounted) Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('生成结果'),
          content: SingleChildScrollView(child: SelectableText(generatedText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e', style: const TextStyle(color: Colors.red))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.chapters.indexWhere((c) => c.url == _currentChapter.url);
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex != -1 && currentIndex < widget.chapters.length - 1;

    final paragraphs = _content.split('\n').where((p) => p.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentChapter.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showFontSizeDialog,
            tooltip: '调整字体',
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
                        onPressed: _loadChapterContent,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: paragraphs.length,
                        itemBuilder: (context, index) {
                          final paragraph = paragraphs[index];
                          final isSelected = _selectedParagraphIndices.contains(index);

                          return InkWell(
                            onTap: _isCloseupMode
                                ? () => _handleParagraphTap(index)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withOpacity(0.2) : null,
                                border: isSelected
                                    ? Border.all(color: Colors.blue, width: 2)
                                    : _isCloseupMode
                                        ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1)
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
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                                onPressed: hasPrevious ? _goToPreviousChapter : null,
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
                  ],
                ),
      // 浮动按钮
      floatingActionButton: _content.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 改写按钮（选中段落时显示）
                if (_isCloseupMode && _selectedParagraphIndices.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        final paragraphs = _content.split('\n').where((p) => p.trim().isNotEmpty).toList();
                        _showRewriteRequirementDialog(paragraphs);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('改写'),
                      backgroundColor: Colors.green,
                      heroTag: 'rewrite',
                    ),
                  ),
                // 特写模式开关按钮
                FloatingActionButton(
                  onPressed: _toggleCloseupMode,
                  backgroundColor: _isCloseupMode ? Colors.blue : Colors.grey[400],
                  heroTag: 'closeup_toggle',
                  child: Icon(
                    _isCloseupMode ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
