import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/outline.dart';
import '../widgets/character_selector.dart';
import '../widgets/streaming_status_indicator.dart';
import '../services/chapter_service.dart';
import '../core/providers/database_providers.dart';
import '../mixins/dify_streaming_mixin.dart';
import '../utils/toast_utils.dart';

/// 插入模式枚举
enum _InsertMode { manual, outline }

/// 插入章节全屏页面
/// 支持手动输入和按大纲生成两种模式
class InsertChapterScreen extends ConsumerStatefulWidget {
  final Novel novel;
  final int afterIndex;
  final List<Chapter> chapters;
  final String? prefillTitle;
  final String? prefillContent;

  const InsertChapterScreen({
    required this.novel,
    required this.afterIndex,
    required this.chapters,
    this.prefillTitle,
    this.prefillContent,
    super.key,
  });

  @override
  ConsumerState<InsertChapterScreen> createState() =>
      _InsertChapterScreenState();
}

class _InsertChapterScreenState extends ConsumerState<InsertChapterScreen>
    with DifyStreamingMixin {
  // 控制器和初始化
  late final TextEditingController _titleController;
  late final TextEditingController _userInputController;
  late final TextEditingController _draftEditingController;

  // 状态管理
  _InsertMode _currentMode = _InsertMode.manual;
  int _currentStep = 0;
  List<int> _selectedCharacterIds = [];
  Outline? _outline;
  bool _isLoadingOutline = true;

  // 前文内容缓存（避免重复获取）
  List<String>? _cachedPreviousChapters;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.prefillTitle ?? '');
    _userInputController =
        TextEditingController(text: widget.prefillContent ?? '');
    _draftEditingController = TextEditingController();
    _loadOutline();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _userInputController.dispose();
    _draftEditingController.dispose();
    super.dispose();
  }

  /// 加载大纲
  Future<void> _loadOutline() async {
    setState(() {
      _isLoadingOutline = true;
    });

    try {
      final repository = ref.read(outlineRepositoryProvider);
      final outline = await repository.getOutlineByNovelUrl(widget.novel.url);
      setState(() {
        _outline = outline;
        _isLoadingOutline = false;
        // 如果没有大纲，默认使用手动模式
        if (outline == null) {
          _currentMode = _InsertMode.manual;
        }
      });
    } catch (e) {
      // 加载大纲失败，默认使用手动模式
      setState(() {
        _outline = null;
        _isLoadingOutline = false;
        _currentMode = _InsertMode.manual;
      });
      debugPrint('加载大纲失败: $e');
    }
  }

  /// 处理确认按钮点击
  void _handleConfirm() {
    // 大纲模式：生成细纲后进入下一步
    if (_currentMode == _InsertMode.outline && _currentStep == 0) {
      // 用户输入现在是可选的，不再进行必填验证
      _generateOutlineDraft();
      return;
    }

    // 最终确认：生成章节
    if (_currentStep == 1) {
      if (_titleController.text.trim().isEmpty) {
        ToastUtils.showWarning('请输入章节标题');
        return;
      }

      final content = _currentMode == _InsertMode.outline
          ? _draftEditingController.text.trim()
          : _userInputController.text.trim();

      if (content.isEmpty) {
        ToastUtils.showWarning('请输入章节内容要求');
        return;
      }

      Navigator.pop(context, {
        'title': _titleController.text.trim(),
        'content': content,
        'characterIds': _selectedCharacterIds,
      });
    }

    // 手动模式：直接确认
    if (_currentMode == _InsertMode.manual) {
      if (_titleController.text.trim().isEmpty ||
          _userInputController.text.trim().isEmpty) {
        ToastUtils.showWarning('请填写完整的章节信息');
        return;
      }

      Navigator.pop(context, {
        'title': _titleController.text.trim(),
        'content': _userInputController.text.trim(),
        'characterIds': _selectedCharacterIds,
      });
    }
  }

  /// 生成大纲细纲
  Future<void> _generateOutlineDraft() async {
    if (_outline == null) {
      ToastUtils.showError('未找到大纲，请先创建大纲');
      return;
    }

    // 并发调用防护：如果正在生成，直接返回
    if (isStreaming) {
      ToastUtils.showWarning('正在生成中，请稍候...');
      return;
    }

    try {
      // 获取前文内容（首次获取时缓存）
      _cachedPreviousChapters ??= await _getPreviousChapters();

      // 清空准备接收流式内容
      _draftEditingController.clear();

      // 立即跳转到步骤1
      setState(() {
        _currentStep = 1;
      });

      // 构建Dify输入参数
      final inputs = _buildDifyInputs(
        userInput: _userInputController.text,
      );

      // 使用 DifyStreamingMixin 进行流式生成
      await callDifyStreaming(
        inputs: inputs,
        onChunk: _updateDraftTextField,
        startMessage: 'AI正在生成章节细纲...',
        completeMessage: '细纲生成完成',
        errorMessagePrefix: '细纲生成失败',
      );
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('生成细纲失败: $e');
      }
    }
  }

  /// 获取前文内容（封装为独立方法，便于缓存）
  Future<List<String>> _getPreviousChapters() async {
    final chapterService = ChapterService();

    return await chapterService.getPreviousChaptersContent(
      chapters: widget.chapters,
      afterIndex: widget.afterIndex,
    );
  }

  /// 构建 Dify 输入参数
  Map<String, dynamic> _buildDifyInputs({
    required String userInput,
    String? existingDraft,
  }) {
    final historyContent = (_cachedPreviousChapters ?? []).join('\n\n');

    return {
      'cmd': '生成细纲',
      'outline': _outline!.content,
      'history_chapters_content': historyContent,
      'outline_item': existingDraft ?? '',
      'user_input': userInput.trim(),
    };
  }

  /// 更新细纲 TextField（自动追加内容并移动光标到末尾）
  void _updateDraftTextField(String chunk) {
    _draftEditingController.text += chunk;
    _draftEditingController.selection = TextSelection.fromPosition(
      TextPosition(offset: _draftEditingController.text.length),
    );
  }

  /// 重新生成细纲
  Future<void> _regenerateDraft() async {
    String? feedback;

    try {
      final feedbackController = TextEditingController();

      feedback = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重新生成细纲'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feedbackController,
                decoration: const InputDecoration(
                  labelText: '修改意见',
                  hintText: '请描述您希望如何调整细纲...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
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
                Navigator.pop(context, feedbackController.text.trim());
              },
              child: const Text('确认'),
            ),
          ],
        ),
      );

      feedbackController.dispose();
    } catch (e) {
      debugPrint('❌ 显示修改意见对话框失败: $e');
      return;
    }

    if (feedback == null || feedback.isEmpty) return;

    try {
      // 清空准备接收新内容（保存当前内容作为 existingDraft）
      final currentDraft = _draftEditingController.text;
      _draftEditingController.clear();

      // 构建Dify输入参数
      final inputs = _buildDifyInputs(
        userInput: feedback,
        existingDraft: currentDraft,
      );

      // 使用 DifyStreamingMixin 进行流式重新生成
      await callDifyStreaming(
        inputs: inputs,
        onChunk: _updateDraftTextField,
        startMessage: 'AI正在重新生成细纲...',
        completeMessage: '细纲重新生成完成',
        errorMessagePrefix: '细纲重新生成失败',
      );
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('重新生成失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.chapters.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.add_circle, color: Colors.blue),
            const SizedBox(width: 8),
            Text(isEmpty ? '创建新章节' : '插入新章节'),
          ],
        ),
      ),
      body: _isLoadingOutline
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载大纲...'),
                ],
              ),
            )
          : _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// 构建模式选择卡片
  Widget _buildModeSelector() {
    // 如果没有大纲,不显示选择器(直接使用手动模式)
    if (_outline == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SegmentedButton<_InsertMode>(
          segments: const [
            ButtonSegment(
              value: _InsertMode.manual,
              label: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('手动输入'),
                ],
              ),
            ),
            ButtonSegment(
              value: _InsertMode.outline,
              label: Row(
                children: [
                  Icon(Icons.menu_book, size: 18),
                  SizedBox(width: 8),
                  Text('按大纲生成'),
                ],
              ),
            ),
          ],
          selected: {_currentMode},
          onSelectionChanged: (Set<_InsertMode> selection) {
            setState(() {
              _currentMode = selection.first;
              _currentStep = 0; // 切换模式时重置步骤
            });
          },
        ),
      ),
    );
  }

  /// 构建步骤指示器(仅大纲模式显示)
  Widget _buildStepIndicator() {
    // 仅在大纲模式显示
    if (_currentMode != _InsertMode.outline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepItem(0, '输入要求'),
          const SizedBox(width: 32),
          Icon(Icons.chevron_right,
              size: 20, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 32),
          _buildStepItem(1, '编辑细纲'),
        ],
      ),
    );
  }

  /// 构建单个步骤指示项
  Widget _buildStepItem(int step, String label) {
    final isActive = _currentStep == step;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.blue
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.surface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isActive
                ? Colors.blue
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// 构建页面主体
  Widget _buildBody() {
    return ListView(
      children: [
        // 1. 模式选择卡片
        _buildModeSelector(),

        // 2. 步骤指示器(仅大纲模式)
        _buildStepIndicator(),

        // 3. 内容区域
        ..._buildContentArea(),
      ],
    );
  }

  /// 构建内容区域(辅助方法,用于处理条件渲染)
  List<Widget> _buildContentArea() {
    if (_currentMode == _InsertMode.outline) {
      // 大纲模式
      if (_currentStep == 0) return [_buildStep0Content()];
      if (_currentStep == 1) return [_buildStep1Content()];
      return [];
    } else {
      // 手动模式
      return [_buildManualModeContent()];
    }
  }

  /// 构建手动模式内容
  Widget _buildManualModeContent() {
    final isEmpty = widget.chapters.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 提示信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEmpty
                          ? '将为小说"${widget.novel.title}"创建第一章'
                          : '将在第${widget.afterIndex + 1}章"${widget.chapters[widget.afterIndex].title}"后插入新章节',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 章节标题输入
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '章节标题',
                  hintText: isEmpty ? '例如：第一章 故事的开始' : '例如：第十五章 意外的相遇',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 章节内容要求输入
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _userInputController,
                decoration: const InputDecoration(
                  labelText: '章节内容要求',
                  hintText: '描述你想要的故事情节、人物对话、场景描述等...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 出场人物选择
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '出场人物（可选）',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CharacterSelector(
                    novelUrl: widget.novel.url,
                    initialSelectedIds: _selectedCharacterIds,
                    onSelectionChanged: (selectedIds) {
                      setState(() {
                        _selectedCharacterIds = selectedIds;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI将根据选中的角色特征来生成章节内容',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建步骤0内容：输入要求
  Widget _buildStep0Content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 大纲预览
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book,
                          size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '大纲: ${_outline!.title}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _outline!.content.length > 300
                        ? '${_outline!.content.substring(0, 300)}...'
                        : _outline!.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 用户输入
          TextField(
            controller: _userInputController,
            decoration: const InputDecoration(
              labelText: '章节要求（可选）',
              hintText: '描述您希望这一章包含的内容、情节、冲突等，留空则完全根据大纲生成...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            autofocus: true,
            enabled: !isStreaming, // 生成时禁用输入
          ),

          const SizedBox(height: 12),

          Text(
            'AI将根据大纲生成章节细纲，您可以提供额外要求来引导生成方向',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建步骤1内容：编辑细纲
  Widget _buildStep1Content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 章节标题输入
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '章节标题',
                  hintText: '例如：第十六章 转折点',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 细纲内容显示/编辑
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '章节细纲',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isStreaming)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: '重新生成',
                          onPressed: _regenerateDraft,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 使用StreamingContentDisplay组件，提供统一的滚动体验
                  SizedBox(
                    height: 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 状态指示器
                        if (_draftEditingController.text.isNotEmpty ||
                            isStreaming)
                          StreamingStatusIndicator(
                            isStreaming: isStreaming,
                            characterCount: _draftEditingController.text.length,
                            streamingText: '实时生成中...',
                            completedText: '生成完成',
                          ),
                        if (_draftEditingController.text.isNotEmpty ||
                            isStreaming)
                          const SizedBox(height: 12),
                        // 内容显示区域
                        if (_draftEditingController.text.isEmpty &&
                            !isStreaming)
                          Expanded(
                            child: Center(
                              child: Text(
                                '等待生成细纲内容...',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: _buildDraftContentDisplay(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 角色选择
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '出场人物（可选）',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CharacterSelector(
                    novelUrl: widget.novel.url,
                    initialSelectedIds: _selectedCharacterIds,
                    onSelectionChanged: (selectedIds) {
                      setState(() {
                        _selectedCharacterIds = selectedIds;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildBottomBar() {
    // 手动模式
    if (_currentMode == _InsertMode.manual) {
      return _buildButtonBar(
        leftChild: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        rightChild: ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text('生成'),
        ),
      );
    }

    // 大纲模式步骤0
    if (_currentStep == 0) {
      return _buildButtonBar(
        leftChild: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        rightChild: ElevatedButton.icon(
          onPressed: isStreaming ? null : _handleConfirm,
          icon: isStreaming
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(isStreaming ? '生成中...' : '生成细纲'),
        ),
      );
    }

    // 大纲模式步骤1
    return _buildButtonBar(
      leftChild: TextButton.icon(
        onPressed: () {
          setState(() {
            _currentStep = 0;
          });
        },
        icon: const Icon(Icons.arrow_back),
        label: const Text('上一步'),
      ),
      rightChild: ElevatedButton(
        onPressed: _handleConfirm,
        child: const Text('确认生成'),
      ),
    );
  }

  /// 构建细纲内容显示
  Widget _buildDraftContentDisplay() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _draftEditingController,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          maxLines: null,
          enabled: !isStreaming,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
      ),
    );
  }

  /// 通用按钮栏构建器
  Widget _buildButtonBar(
      {required Widget leftChild, required Widget rightChild}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          leftChild,
          const Spacer(),
          rightChild,
        ],
      ),
    );
  }
}
