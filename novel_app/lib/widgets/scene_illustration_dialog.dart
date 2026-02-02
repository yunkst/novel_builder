import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character.dart';
import '../widgets/character_selector.dart';
import '../widgets/model_selector.dart';
import '../services/scene_illustration_service.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import '../utils/character_matcher.dart';
import '../mixins/dify_streaming_mixin.dart';
import '../utils/toast_utils.dart';
import '../core/providers/database_providers.dart';

class SceneIllustrationDialog extends ConsumerStatefulWidget {
  final String paragraphText;
  final String novelUrl;
  final String chapterId;
  final int paragraphIndex;
  final Function(String)? onRefresh; // 刷新回调，传递taskId

  const SceneIllustrationDialog({
    super.key,
    required this.paragraphText,
    required this.novelUrl,
    required this.chapterId,
    required this.paragraphIndex,
    this.onRefresh,
  });

  @override
  ConsumerState<SceneIllustrationDialog> createState() =>
      _SceneIllustrationDialogState();
}

class _SceneIllustrationDialogState
    extends ConsumerState<SceneIllustrationDialog> with DifyStreamingMixin {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  final SceneIllustrationService _sceneIllustrationService =
      SceneIllustrationService();
  List<int> _selectedCharacterIds = [];
  List<Character> _characters = [];
  int _imageCount = 1;
  String? _selectedModel;
  bool _isGenerating = false;
  String? _sceneGenerationError;

  /// 滚动到文本末尾
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // 删除默认文本，让用户从空白开始
    _contentController.text = '';
    _loadCharacters();

    // 移除自动AI生成逻辑，改为用户手动触发
    // Future.delayed(const Duration(milliseconds: 500), () {
    //   if (mounted) {
    //     _startSceneDescriptionGeneration();
    //   }
    // });
  }

  Future<void> _loadCharacters() async {
    final databaseService = ref.read(databaseServiceProvider);
    try {
      final characters = await databaseService.getCharacters(widget.novelUrl);
      if (mounted) {
        setState(() {
          _characters = characters;
        });
      }
      // 角色加载完成后，执行预选逻辑
      _preselectAppearingCharacters();
    } catch (e, stackTrace) {
      LoggerService.instance.w(
        '加载角色列表失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['illustration', 'characters', 'load', 'failed'],
      );
    }
  }

  /// 获取可匹配的章节内容（当前段落及之前的内容）
  String _getMatchableContent(String chapterContent, int paragraphIndex) {
    if (chapterContent.isEmpty) return '';

    // 分割章节内容为段落
    final paragraphs =
        chapterContent.split('\n').where((p) => p.trim().isNotEmpty).toList();

    if (paragraphs.isEmpty) return '';

    // 确保段落索引在有效范围内
    final validIndex = paragraphIndex.clamp(0, paragraphs.length - 1);

    // 获取从开头到当前段落的全部内容
    final matchableParagraphs = paragraphs.take(validIndex + 1).toList();
    return matchableParagraphs.join('\n');
  }

  /// 预选章节中出现的角色
  Future<void> _preselectAppearingCharacters() async {
    final databaseService = ref.read(databaseServiceProvider);
    try {
      // 获取当前章节内容
      final chapterContent =
          await databaseService.getCachedChapter(widget.chapterId);
      if (chapterContent == null || chapterContent.isEmpty) {
        debugPrint('章节内容为空，跳过角色预选');
        return;
      }

      // 获取可匹配的内容范围
      final matchableContent =
          _getMatchableContent(chapterContent, widget.paragraphIndex);

      // 使用工具类查找出现的角色ID
      final appearingIds = CharacterMatcher.findAppearingCharacterIds(
        matchableContent,
        _characters,
      );

      if (appearingIds.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedCharacterIds = appearingIds;
          });
        }
        debugPrint(
            '预选了 ${appearingIds.length} 个角色: ${appearingIds.join(', ')}');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.w(
        '预选角色失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['illustration', 'characters', 'preselect', 'failed'],
      );
      // 预选失败不影响对话框正常显示
    }
  }

  /// 开始场景描写流式生成
  Future<void> _startSceneDescriptionGeneration() async {
    // 防止重复调用
    if (isStreaming) {
      debugPrint('AI生成正在进行中，忽略重复调用');
      return;
    }

    debugPrint('🚀 === 开始场景描写生成 ===');

    // 清空现有内容
    _contentController.clear();
    _sceneGenerationError = null;

    // 检查Dify配置
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    if (difyUrl == null || difyUrl.isEmpty) {
      debugPrint('Dify未配置，跳过场景描写生成');
      setState(() {
        _sceneGenerationError = 'Dify服务未配置，请在设置中配置Dify URL';
      });
      return;
    }

    // 获取章节内容
    final databaseService = ref.read(databaseServiceProvider);
    final chapterContent =
        await databaseService.getCachedChapter(widget.chapterId);
    if (chapterContent == null || chapterContent.isEmpty) {
      debugPrint('章节内容为空，跳过场景描写生成');
      setState(() {
        _sceneGenerationError = '章节内容为空，无法生成场景描写';
      });
      return;
    }

    // 获取当前段落及之前的内容作为AI上下文
    final fullContext =
        _getMatchableContent(chapterContent, widget.paragraphIndex);

    // 重新筛选在fullContext中出现的角色（使用工具类）
    final allCharacters = await databaseService.getCharacters(widget.novelUrl);
    final appearingIds =
        CharacterMatcher.findAppearingCharacterIds(fullContext, allCharacters);
    final selectedCharacters =
        allCharacters.where((c) => appearingIds.contains(c.id)).toList();

    // 构建输入参数
    final inputs = {
      'current_chapter_content': fullContext,
      'roles': Character.formatForAI(selectedCharacters),
      'cmd': '场景描写',
    };

    // 调用统一的流式方法 - 只需要10行代码！
    await callDifyStreaming(
      inputs: inputs,
      onChunk: (chunk) {
        debugPrint('🔥 收到场景描写文本块: "$chunk"');
        // 流式追加内容
        _contentController.text += chunk;
        // 自动滚动到文本末尾
        _scrollToBottom();
      },
      onComplete: (fullContent) {
        debugPrint('✅ 场景描写生成完成: "$fullContent"');
        // 完成回调（fullContent 由 mixin 提供）
      },
      startMessage: 'AI正在生成场景描写...',
      completeMessage: '场景描写生成完成',
      errorMessagePrefix: '场景描写生成失败',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> generateIllustration() async {
    if (_contentController.text.trim().isEmpty) {
      ToastUtils.showWarning('请先输入场景描写内容');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // 获取选中的角色
      final selectedCharacters = _characters
          .where((c) => _selectedCharacterIds.contains(c.id))
          .toList();

      // 创建角色信息列表（使用新的RoleInfo格式）
      final rolesList = Character.toRoleInfoList(selectedCharacters);

      debugPrint('开始创建插图，段落索引: ${widget.paragraphIndex}');

      // 使用SceneIllustrationService创建插图（自动插入标记）
      final illustrationId =
          await _sceneIllustrationService.createSceneIllustrationWithMarkup(
        novelUrl: widget.novelUrl,
        chapterId: widget.chapterId,
        paragraphText: _contentController.text.trim(),
        roles: rolesList,
        imageCount: _imageCount,
        modelName: _selectedModel,
        insertionPosition: 'after', // 在段落后插入插图
        paragraphIndex: widget.paragraphIndex,
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
        });

        ToastUtils.showSuccess('插图任务已创建，正在生成中...');

        // 通知父组件刷新
        widget.onRefresh?.call(illustrationId.toString());

        // 关闭对话框
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      ErrorHelper.showErrorWithLog(
        context,
        '创建插图失败',
        stackTrace: stackTrace,
        category: LogCategory.ai,
        tags: ['illustration', 'create', 'failed'],
      );
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.image, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('创建插图'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 角色选择器
            if (_characters.isNotEmpty) ...[
              Text(
                '选择出场角色',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              CharacterSelector(
                novelUrl: widget.novelUrl,
                initialSelectedIds: _selectedCharacterIds,
                onSelectionChanged: (selectedIds) {
                  setState(() {
                    _selectedCharacterIds = selectedIds;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // 图片数量选择
            Text(
              '生成图片数量',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [1, 2, 3, 4].map((count) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: count < 4 ? 8.0 : 0),
                    child: ElevatedButton(
                      onPressed: _isGenerating
                          ? null
                          : () {
                              setState(() {
                                _imageCount = count;
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _imageCount == count
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.12),
                        foregroundColor: _imageCount == count
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      child: Text('$count'),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 模型选择器
            ModelSelector(
              selectedModel: _selectedModel,
              onModelChanged: (value) {
                setState(() {
                  _selectedModel = value;
                });
              },
              apiType: 't2i',
              hintText: '选择生图模型',
            ),
            const SizedBox(height: 16),

            // 场景描述输入框
            Text(
              '场景描述',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _contentController,
                focusNode: _focusNode,
                scrollController: _scrollController,
                maxLines: 4,
                enabled: !isStreaming, // 生成时禁用编辑（使用 mixin 状态）
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface), // 始终白色文字
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface, // 始终黑色背景
                  hintText: '请输入场景描述，或点击下方"AI生成画面"按钮自动生成',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.40)),
                ),
              ),
            ),

            // AI生成画面按钮 - 替换原来的重新生成按钮
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isStreaming ? null : _startSceneDescriptionGeneration,
              icon: isStreaming
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(isStreaming ? 'AI生成中...' : 'AI生成画面'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            // 显示生成错误信息
            if (_sceneGenerationError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _sceneGenerationError!,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.8),
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isGenerating ? null : generateIllustration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isGenerating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary),
                )
              : const Text('生成插图'),
        ),
      ],
    );
  }
}
