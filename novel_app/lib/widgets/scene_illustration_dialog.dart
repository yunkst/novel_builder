import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character.dart';
import '../widgets/character_selector.dart';
import '../widgets/model_selector.dart';
import '../services/database_service.dart';
import '../services/unified_stream_manager.dart';
import '../services/scene_illustration_service.dart';
import '../models/stream_config.dart';

class SceneIllustrationDialog extends StatefulWidget {
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
  State<SceneIllustrationDialog> createState() => _SceneIllustrationDialogState();
}

class _SceneIllustrationDialogState extends State<SceneIllustrationDialog> {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  final DatabaseService _databaseService = DatabaseService();
  final SceneIllustrationService _sceneIllustrationService = SceneIllustrationService();
  List<int> _selectedCharacterIds = [];
  List<Character> _characters = [];
  int _imageCount = 1;
  String? _selectedModel;
  bool _isGenerating = false;
  bool _isSceneGenerating = false;
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
    try {
      final characters = await _databaseService.getCharacters(widget.novelUrl);
      if (mounted) {
        setState(() {
          _characters = characters;
        });
      }
      // 角色加载完成后，执行预选逻辑
      _preselectAppearingCharacters();
    } catch (e) {
      debugPrint('加载角色列表失败: $e');
    }
  }

  /// 获取可匹配的章节内容（当前段落及之前的内容）
  String _getMatchableContent(String chapterContent, int paragraphIndex) {
    if (chapterContent.isEmpty) return '';

    // 分割章节内容为段落
    final paragraphs = chapterContent
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) return '';

    // 确保段落索引在有效范围内
    final validIndex = paragraphIndex.clamp(0, paragraphs.length - 1);

    // 获取从开头到当前段落的全部内容
    final matchableParagraphs = paragraphs.take(validIndex + 1).toList();
    return matchableParagraphs.join('\n');
  }

  /// 在章节内容中查找出现的角色
  List<int> _findAppearingCharacters(String content, List<Character> characters) {
    if (content.isEmpty || characters.isEmpty) {
      return [];
    }

    final appearingIds = <int>{};
    final lowerContent = content.toLowerCase();

    for (final character in characters) {
      if (character.name.isEmpty) continue;

      final lowerName = character.name.toLowerCase();
      if (lowerContent.contains(lowerName) && character.id != null) {
        appearingIds.add(character.id!);
      }
    }

    return appearingIds.toList();
  }

  /// 预选章节中出现的角色
  Future<void> _preselectAppearingCharacters() async {
    try {
      // 获取当前章节内容
      final chapterContent = await _databaseService.getCachedChapter(widget.chapterId);
      if (chapterContent == null || chapterContent.isEmpty) {
        debugPrint('章节内容为空，跳过角色预选');
        return;
      }

      // 获取可匹配的内容范围
      final matchableContent = _getMatchableContent(chapterContent, widget.paragraphIndex);

      // 查找出现的角色
      final appearingIds = _findAppearingCharacters(matchableContent, _characters);

      if (appearingIds.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedCharacterIds = appearingIds;
          });
        }
        debugPrint('预选了 ${appearingIds.length} 个角色: ${appearingIds.join(', ')}');
      }
    } catch (e) {
      debugPrint('预选角色失败: $e');
      // 预选失败不影响对话框正常显示
    }
  }

  /// 开始场景描写流式生成
  Future<void> _startSceneDescriptionGeneration() async {
    // 防止重复调用
    if (_isSceneGenerating) {
      debugPrint('AI生成正在进行中，忽略重复调用');
      return;
    }

    debugPrint('🚀 === 开始场景描写生成 ===');

    // 重置状态并清空现有内容
    setState(() {
      _contentController.text = '';
      _isSceneGenerating = true;
      _sceneGenerationError = null;
    });

    // 检查Dify配置
    final prefs = await SharedPreferences.getInstance();
    final difyUrl = prefs.getString('dify_url');
    if (difyUrl == null || difyUrl.isEmpty) {
      debugPrint('Dify未配置，跳过场景描写生成');
      setState(() {
        _isSceneGenerating = false;
        _sceneGenerationError = 'Dify服务未配置，请在设置中配置Dify URL';
      });
      return;
    }

    // 获取章节内容
    final chapterContent = await _databaseService.getCachedChapter(widget.chapterId);
    if (chapterContent == null || chapterContent.isEmpty) {
      debugPrint('章节内容为空，跳过场景描写生成');
      setState(() {
        _isSceneGenerating = false;
        _sceneGenerationError = '章节内容为空，无法生成场景描写';
      });
      return;
    }

    // 获取当前段落及之前的内容作为AI上下文
    final fullContext = _getMatchableContent(chapterContent, widget.paragraphIndex);

    // 重新筛选在fullContext中出现的角色
    final allCharacters = await _databaseService.getCharacters(widget.novelUrl);
    final appearingCharacters = _findAppearingCharacters(fullContext, allCharacters);
    final selectedCharacters = allCharacters.where((c) => appearingCharacters.contains(c.id)).toList();

    // 状态已在函数开始时设置，这里无需重复设置

    try {
      // 使用统一流式管理器
      final streamManager = UnifiedStreamManager();

      // 创建场景描写配置
      final config = StreamConfig.sceneDescription(
        inputs: {
          'current_chapter_content': fullContext,
          'roles': Character.formatForAI(selectedCharacters),
          'cmd': '场景描写',
        },
        generatingHint: 'AI正在生成场景描写，请稍候...',
      );

      await streamManager.executeStream(
        config: config,
        onChunk: (textChunk) {
          debugPrint('🔥 收到场景描写文本块: "$textChunk"');

          // 检查是否是完整内容的特殊标记
          final bool isCompleteContent = textChunk.startsWith('<<COMPLETE_CONTENT>>');

          if (isCompleteContent) {
            debugPrint('🎯 检测到完整内容标记，直接替换');
            // 提取实际内容（移除特殊标记）
            final completeContent = textChunk.substring('<<COMPLETE_CONTENT>>'.length);

            if (mounted) {
              setState(() {
                _contentController.text = completeContent;
                _isSceneGenerating = false;
              });
              debugPrint('✅ 完整内容替换完成，长度: ${completeContent.length}');
            }
          } else {
            // 流式模式：追加内容
            if (mounted) {
              setState(() {
                _contentController.text += textChunk; // 实时追加文本块
              });
              // 自动滚动到文本末尾
              _scrollToBottom();
            }
          }
        },
        onComplete: (fullContent) {
          debugPrint('✅ 场景描写生成完成: "$fullContent"');
          // onComplete通常由特殊标记触发，这里可以不做处理
        },
        onError: (error) {
          debugPrint('❌ 场景描写生成错误: $error');
          if (mounted) {
            setState(() {
              _isSceneGenerating = false;
              _sceneGenerationError = error;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('❌ 场景描写生成异常: $e');
      if (mounted) {
        setState(() {
          _isSceneGenerating = false;
          _sceneGenerationError = e.toString();
        });
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入场景描写内容'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // 获取选中的角色
      final selectedCharacters = _characters.where((c) => _selectedCharacterIds.contains(c.id)).toList();

      // 创建角色信息列表（使用新的RoleInfo格式）
      final rolesList = Character.toRoleInfoList(selectedCharacters);

      debugPrint('开始创建插图，段落索引: ${widget.paragraphIndex}');

      // 使用SceneIllustrationService创建插图（自动插入标记）
      final illustrationId = await _sceneIllustrationService.createSceneIllustrationWithMarkup(
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('插图任务已创建，正在生成中...'),
            backgroundColor: Colors.green,
          ),
        );

        // 通知父组件刷新
        widget.onRefresh?.call(illustrationId.toString());

        // 关闭对话框
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('创建插图失败: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建插图失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.image, color: Colors.blue),
          SizedBox(width: 8),
          Text('创建插图'),
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
                      onPressed: _isGenerating ? null : () {
                        setState(() {
                          _imageCount = count;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _imageCount == count ? Colors.blue : Colors.grey[300],
                        foregroundColor: _imageCount == count ? Colors.white : Colors.black,
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
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _contentController,
                focusNode: _focusNode,
                scrollController: _scrollController,
                maxLines: 4,
                enabled: !_isSceneGenerating, // 生成时禁用编辑
                style: const TextStyle(color: Colors.white), // 始终白色文字
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  filled: true,
                  fillColor: Colors.black, // 始终黑色背景
                  hintText: '请输入场景描述，或点击下方"AI生成画面"按钮自动生成',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
              ),
            ),

            // AI生成画面按钮 - 替换原来的重新生成按钮
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isSceneGenerating ? null : _startSceneDescriptionGeneration,
              icon: _isSceneGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isSceneGenerating ? 'AI生成中...' : 'AI生成画面'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            // 显示生成错误信息
            if (_sceneGenerationError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _sceneGenerationError!,
                        style: TextStyle(color: Colors.red.shade600, fontSize: 14),
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
          onPressed: _isGenerating ? null : () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isGenerating ? null : generateIllustration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('生成插图'),
        ),
      ],
    );
  }
}