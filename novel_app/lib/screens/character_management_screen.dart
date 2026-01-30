import 'dart:io';
import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/character.dart';
import '../models/character_update.dart';
import '../models/outline.dart';
import '../services/database_service.dart';
import '../services/character_image_cache_service.dart';
import '../services/character_avatar_service.dart';
import '../services/character_extraction_service.dart';
import '../services/dify_service.dart';
import '../services/logger_service.dart';
import '../utils/toast_utils.dart';
import '../widgets/character_input_dialog.dart';
import '../widgets/character_preview_dialog.dart';
import '../widgets/common/common_widgets.dart';
import 'character_edit_screen.dart';
import 'enhanced_relationship_graph_screen.dart';

class CharacterManagementScreen extends StatefulWidget {
  final Novel novel;

  const CharacterManagementScreen({
    super.key,
    required this.novel,
  });

  @override
  State<CharacterManagementScreen> createState() =>
      _CharacterManagementScreenState();
}

class _CharacterManagementScreenState extends State<CharacterManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final CharacterImageCacheService _imageCacheService =
      CharacterImageCacheService.instance;
  final CharacterAvatarService _avatarService = CharacterAvatarService();
  final DifyService _difyService = DifyService();
  List<Character> _characters = [];
  bool _isLoading = true;

  // 关系数量缓存
  final Map<int, int> _relationshipCountCache = {};

  // 大纲状态
  Outline? _outline;
  bool _hasOutline = false;

  // 多选模式状态
  bool _isMultiSelectMode = false;
  final Set<int> _selectedCharacterIds = {};

  // 常量定义
  static const double _avatarBorderRadius = 8.0;
  static const double _nameBottomPadding = 8.0;
  static const double _nameHorizontalPadding = 8.0;

  // 缓存阴影样式（延迟初始化）
  List<BoxShadow> get _avatarShadow => [
    BoxShadow(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadCharacters();
    _loadOutline();
  }

  /// 初始化服务
  Future<void> _initializeServices() async {
    try {
      await _imageCacheService.init();
    } catch (e) {
      debugPrint('初始化图片缓存服务失败: $e');
    }
  }

  /// 加载大纲状态
  Future<void> _loadOutline() async {
    try {
      final outline =
          await _databaseService.getOutlineByNovelUrl(widget.novel.url);
      setState(() {
        _outline = outline;
        _hasOutline = outline != null;
      });
      debugPrint('大纲加载状态: $_hasOutline');
    } catch (e) {
      debugPrint('加载大纲失败: $e');
      setState(() {
        _hasOutline = false;
      });
    }
  }

  Future<void> _loadCharacters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final characters = await _databaseService.getCharacters(widget.novel.url);

      // 检查并清理无效的头像缓存
      await _checkAndCleanAvatarCache(characters);

      // 加载每个角色的关系数量
      await _loadRelationshipCounts(characters);

      setState(() {
        _characters = characters;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 加载角色失败: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ToastUtils.showError('加载角色失败: $e');
      }
    }
  }

  /// 加载角色关系数量
  Future<void> _loadRelationshipCounts(List<Character> characters) async {
    for (final character in characters) {
      if (character.id == null) continue;

      try {
        final count = await _databaseService.getRelationshipCount(character.id!);
        _relationshipCountCache[character.id!] = count;
      } catch (e) {
        debugPrint('❌ 加载关系数量失败 - ${character.name}: $e');
        _relationshipCountCache[character.id!] = 0;
      }
    }
  }

  /// 检查并清理无效的头像缓存
  Future<void> _checkAndCleanAvatarCache(List<Character> characters) async {
    for (final character in characters) {
      if (character.id == null) continue;

      try {
        // 清理无效的头像缓存
        await _avatarService.cleanupInvalidAvatarCache(character.id!);
      } catch (e) {
        debugPrint('❌ 清理头像缓存失败 - ${character.name}: $e');
      }
    }
  }

  Future<void> _aiCreateCharacter() async {
    // 显示输入对话框，传入大纲状态和小说URL
    final result = await CharacterInputDialog.show(
      context,
      hasOutline: _hasOutline,
      novelUrl: widget.novel.url,
    );

    if (result == null) {
      return;
    }

    final mode = result['mode'] as String;

    if (!mounted) return;

    if (mode == 'extract') {
      await _extractCharacter(result);
    } else {
      await _generateCharacter(result);
    }
  }

  /// AI生成角色（描述模式或大纲模式）
  Future<void> _generateCharacter(Map<String, dynamic> result) async {
    final userInput = result['userInput'] as String;
    final useOutline = result['useOutline'] as bool;

    if (userInput.trim().isEmpty) {
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
            Text(useOutline ? '正在从大纲生成角色...' : '正在AI创建角色...'),
          ],
        ),
      ),
    );

    try {
      final generatedCharacters = useOutline
          ? await _difyService.generateCharactersFromOutline(
              outline: _outline!.content,
              userInput: userInput,
              novelUrl: widget.novel.url,
            )
          : await _difyService.generateCharacters(
              userInput: userInput,
              novelUrl: widget.novel.url,
              backgroundSetting: (await _databaseService
                      .getBackgroundSetting(widget.novel.url)) ??
                  '',
            );

      if (!mounted) return;

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 转换为CharacterUpdate列表
      final characterUpdates = generatedCharacters
          .map((c) => CharacterUpdate(newCharacter: c))
          .toList();

      // 显示角色预览对话框
      await CharacterPreviewDialog.show(
        context,
        characterUpdates: characterUpdates,
        onConfirmed: (selectedCharacters) async {
          if (selectedCharacters.isNotEmpty) {
            await _saveSelectedCharacters(selectedCharacters);
          }
        },
      );
    } catch (e) {
      LoggerService.instance.e('创建角色失败: ${e.toString()}');
      debugPrint('❌ 创建角色失败: $e');
      if (!mounted) return;

      // 关闭加载对话框
      Navigator.of(context).pop();

      if (mounted) {
        ToastUtils.showError('创建角色失败: $e');
      }
    }
  }

  /// 提取角色
  Future<void> _extractCharacter(Map<String, dynamic> result) async {
    final name = result['name'] as String;
    final aliases = result['aliases'] as List<String>;
    final contextLength = result['contextLength'] as int;
    final extractFullChapter = result['extractFullChapter'] as bool;
    final selectedChapters = result['selectedChapters'] as List;

    if (selectedChapters.isEmpty) {
      if (mounted) {
        ToastUtils.showError('请至少选择一个章节');
      }
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
            Text('正在提取角色信息...'),
          ],
        ),
      ),
    );

    try {
      // 构建角色名字符串
      final rolesList = <String>[name, ...aliases];
      final rolesString = rolesList.join('、');

      // 提取并合并上下文
      final extractionService = CharacterExtractionService();
      final allContexts = <String>[];

      for (final item in selectedChapters) {
        final chapterMatch = item;
        final chapter = chapterMatch.chapter;
        final content = chapter.content ?? '';

        if (extractFullChapter) {
          allContexts.add(content);
        } else {
          final matchPositions = chapterMatch.matchPositions;
          final contexts = extractionService.extractContextAroundMatches(
            content: content,
            matchPositions: matchPositions.toList().cast<int>(),
            contextLength: contextLength,
            useFullChapter: false,
          );
          allContexts.addAll(contexts);
        }
      }

      // 合并去重
      final mergedContent = extractionService.mergeAndDeduplicateContexts(allContexts);

      // 调用 Dify 提取角色
      final extractedCharacters = await _difyService.extractCharacter(
        chapterContent: mergedContent,
        roles: rolesString,
        novelUrl: widget.novel.url,
      );

      if (!mounted) return;

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 转换为CharacterUpdate列表
      final characterUpdates = extractedCharacters
          .map((c) => CharacterUpdate(newCharacter: c))
          .toList();

      // 显示角色预览对话框
      await CharacterPreviewDialog.show(
        context,
        characterUpdates: characterUpdates,
        onConfirmed: (selectedCharacters) async {
          if (selectedCharacters.isNotEmpty) {
            await _saveSelectedCharacters(selectedCharacters);
          }
        },
      );
    } catch (e) {
      LoggerService.instance.e('提取角色失败: ${e.toString()}');
      debugPrint('❌ 提取角色失败: $e');
      if (!mounted) return;

      // 关闭加载对话框
      Navigator.of(context).pop();

      if (mounted) {
        ToastUtils.showError('提取角色失败: $e');
      }
    }
  }

  /// 保存用户选择的特定角色
  Future<void> _saveSelectedCharacters(
      List<Character> selectedCharacters) async {
    int successCount = 0;
    int failCount = 0;
    List<String> failedCharacters = [];

    try {
      for (final character in selectedCharacters) {
        try {
          await _databaseService.createCharacter(character);
          successCount++;
        } catch (e) {
          failCount++;
          failedCharacters.add('${character.name}: $e');
          debugPrint('保存角色失败 - ${character.name}: $e');
        }
      }

      // 重新加载角色列表
      _loadCharacters();

      // 显示结果
      if (mounted) {
        if (failCount == 0) {
          ToastUtils.showSuccess('成功保存选中的 $successCount 个角色');
        } else if (successCount == 0) {
          ToastUtils.showError('保存失败，请检查配置或重试');
        } else {
          ToastUtils.showWarningWithAction('成功保存 $successCount 个角色，$failCount 个失败', '查看详情', () => _showFailDetails(failedCharacters));
        }
      }
    } catch (e) {
      LoggerService.instance.e('保存角色时发生错误: ${e.toString()}');
      debugPrint('❌ 保存角色时发生错误: $e');
      if (mounted) {
        ToastUtils.showError('保存角色时发生错误: $e');
      }
    }
  }

  /// 显示失败详情
  void _showFailDetails(List<String> failedCharacters) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('角色创建失败详情'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: failedCharacters
                  .map((failure) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text('• $failure',
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
            ),
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

  /// 切换多选模式（长按触发）
  void _toggleMultiSelectMode(Character character) {
    setState(() {
      _isMultiSelectMode = true;
      if (character.id != null) {
        _selectedCharacterIds.add(character.id!);
      }
    });
  }

  /// 切换角色选择状态（点击触发）
  void _toggleCharacterSelection(int characterId) {
    setState(() {
      if (_selectedCharacterIds.contains(characterId)) {
        _selectedCharacterIds.remove(characterId);
      } else {
        _selectedCharacterIds.add(characterId);
      }
    });
  }

  /// 退出多选模式
  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedCharacterIds.clear();
    });
  }

  /// 处理卡片点击（编辑或选择）
  void _handleCardTap(Character character) {
    if (_isMultiSelectMode && character.id != null) {
      _toggleCharacterSelection(character.id!);
    } else {
      // 直接进入编辑页面
      _navigateToEdit(character: character);
    }
  }

  /// 显示批量删除确认对话框
  Future<bool> _showBatchDeleteConfirmationDialog() async {
    final result = await ConfirmDialog.show(
      context,
      title: '批量删除角色',
      message: '确定要删除选中的 ${_selectedCharacterIds.length} 个角色吗？\n此操作无法撤销。',
      confirmText: '删除',
      icon: Icons.delete,
      confirmColor: Colors.red,
    );
    return result ?? false;
  }

  /// 批量删除选中的角色
  Future<void> _deleteSelectedCharacters() async {
    if (_selectedCharacterIds.isEmpty) return;

    final confirmed = await _showBatchDeleteConfirmationDialog();
    if (!confirmed) return;

    try {
      // 批量删除
      for (final characterId in _selectedCharacterIds) {
        await _databaseService.deleteCharacter(characterId);
        await _imageCacheService.deleteCharacterCachedImages(characterId);
      }

      if (mounted) {
        ToastUtils.showSuccess('成功删除 ${_selectedCharacterIds.length} 个角色');
      }

      // 退出多选模式并重新加载
      _exitMultiSelectMode();
      _loadCharacters();
    } catch (e) {
      debugPrint('❌ 批量删除角色失败: $e');
      if (mounted) {
        ToastUtils.showError('批量删除失败: $e');
      }
    }
  }

  Future<void> _navigateToEdit({Character? character}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterEditScreen(
          novel: widget.novel,
          character: character,
        ),
      ),
    );

    if (result == true) {
      _loadCharacters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMultiSelectMode
            ? '已选 (${_selectedCharacterIds.length})'
            : '人物管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (_isMultiSelectMode)
            TextButton(
              onPressed: _exitMultiSelectMode,
              child: const Text('取消'),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.account_tree),
                  tooltip: '全人物关系图',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnhancedRelationshipGraphScreen(
                          novelUrl: widget.novel.url,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: _aiCreateCharacter,
                  icon: Icon(_hasOutline ? Icons.menu_book : Icons.auto_awesome),
                  tooltip: _hasOutline ? 'AI创建角色（支持大纲）' : 'AI创建角色',
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characters.isEmpty
              ? _buildEmptyState()
              : _buildCharacterList(),
      floatingActionButton: _isMultiSelectMode &&
              _selectedCharacterIds.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'batch_delete_fab',
              onPressed: _deleteSelectedCharacters,
              icon: const Icon(Icons.delete),
              label: Text('删除 (${_selectedCharacterIds.length})'),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            )
          : FloatingActionButton(
              heroTag: 'character_management_fab',
              onPressed: () => _navigateToEdit(),
              tooltip: '添加人物',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          SizedBox(height: 16),
          Text(
            '还没有创建人物',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右下角的 + 按钮创建第一个人物',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式网格配置
        int crossAxisCount;
        double childAspectRatio;
        double crossAxisSpacing;
        double mainAxisSpacing;
        double horizontalPadding;

        if (constraints.maxWidth > 800) {
          // 大屏幕 - 3列布局
          crossAxisCount = 3;
          childAspectRatio = 0.75; // 调整为适应方形头像
          crossAxisSpacing = 20;
          mainAxisSpacing = 20;
          horizontalPadding = 24;
        } else if (constraints.maxWidth > 600) {
          // 中等屏幕 - 2列布局，更紧凑
          crossAxisCount = 2;
          childAspectRatio = 0.8; // 调整为适应方形头像
          crossAxisSpacing = 18;
          mainAxisSpacing = 18;
          horizontalPadding = 20;
        } else {
          // 小屏幕 - 2列标准布局
          crossAxisCount = 2;
          childAspectRatio = 0.85; // 调整为适应方形头像
          crossAxisSpacing = 16;
          mainAxisSpacing = 16;
          horizontalPadding = 16;
        }

        return GridView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          ),
          itemCount: _characters.length,
          itemBuilder: (context, index) {
            final character = _characters[index];
            return _buildCharacterCard(character);
          },
        );
      },
    );
  }

  Widget _buildCharacterCard(Character character) {
    final isSelected = _isMultiSelectMode &&
        character.id != null &&
        _selectedCharacterIds.contains(character.id!);

    return GestureDetector(
      onLongPress: () => _toggleMultiSelectMode(character),
      onTap: () => _handleCardTap(character),
      child: Card(
        elevation: isSelected ? 12 : 6,
        shadowColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : BorderSide.none,
        ),
        child: Builder(
          builder: (context) {
            // 根据屏幕尺寸动态调整卡片高度
            final screenHeight = MediaQuery.of(context).size.height;
            final cardHeight = screenHeight < 700 ? 280.0 : 300.0;

            return SizedBox(
              height: cardHeight,
              child: Column(
                children: [
                // 头像区域
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      // 方形头像背景
                      _buildSquareAvatarBackground(character),

                      // 头像图片
                      Positioned.fill(
                        child: Hero(
                          tag: 'character_${character.id ?? character.name}',
                          child: _buildCharacterAvatar(character),
                        ),
                      ),

                      // 底部浮动名字
                      Positioned(
                        bottom: _nameBottomPadding,
                        left: _nameHorizontalPadding * 2,
                        right: _nameHorizontalPadding * 2,
                        child: Text(
                          character.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.surface,
                            shadows: [
                              Shadow(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                                blurRadius: 3,
                                offset: Offset(1, 1),
                              ),
                              Shadow(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // 关系数量徽章
                      if (character.id != null &&
                          _relationshipCountCache[character.id] != null &&
                          _relationshipCountCache[character.id]! > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            elevation: 4,
                            shape: const CircleBorder(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_relationshipCountCache[character.id]}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.surface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 信息区域
                Expanded(
                  flex: 2, // 减少flex比例，让下半部分更紧凑
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8), // 减少padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 职业标签
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4), // 减少padding
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12), // 稍微减小圆角
                              border: Border.all(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              character.occupation ?? '未知职业',
                              style: TextStyle(
                                fontSize: 10, // 缩小职业字号
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.surface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2, // 支持换行
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  /// 构建角色头像
  Widget _buildCharacterAvatar(Character character) {
    // 使用cachedImageUrl的变化来触发FutureBuilder重建
    final avatarKey =
        ValueKey('avatar_${character.id}_${character.cachedImageUrl}');
    return FutureBuilder<String?>(
      key: avatarKey,
      future: character.id != null
          ? _avatarService.getCharacterAvatarPath(character.id!)
          : Future.value(null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingAvatar();
        }

        final avatarPath = snapshot.data;
        if (avatarPath != null && File(avatarPath).existsSync()) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              boxShadow: _avatarShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_avatarBorderRadius),
              child: Image.file(
                File(avatarPath),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ 头像加载失败: $error');
                  return _buildFallbackAvatar(character);
                },
              ),
            ),
          );
        }

        return _buildFallbackAvatar(character);
      },
    );
  }

  /// 构建加载中头像
  Widget _buildLoadingAvatar() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_avatarBorderRadius),
        boxShadow: _avatarShadow,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  /// 构建备用头像（首字母）
  Widget _buildFallbackAvatar(Character character) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(_avatarBorderRadius),
        boxShadow: _avatarShadow,
      ),
      child: Center(
        child: Text(
          character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 48, // 固定字体大小，因为容器会自适应
            fontWeight: FontWeight.bold,
            color: _getGenderColor(character.gender),
          ),
        ),
      ),
    );
  }

  /// 构建方形头像背景
  Widget _buildSquareAvatarBackground(Character character) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getGenderColor(character.gender),
            _getGenderColor(character.gender).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
    );
  }

  Color _getGenderColor(String? gender) {
    switch (gender?.toLowerCase()) {
      case '男':
        return Colors.blue;
      case '女':
        return Colors.pink;
      default:
        return Colors.purple;
    }
  }
}
