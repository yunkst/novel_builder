import 'dart:io';
import 'package:flutter/material.dart';
import '../models/novel.dart';
import '../models/character.dart';
import '../services/database_service.dart';
import '../services/character_image_cache_service.dart';
import '../services/character_avatar_service.dart';
import '../services/dify_service.dart';
import '../widgets/character_input_dialog.dart';
import '../widgets/character_preview_dialog.dart';
import 'character_edit_screen.dart';

class CharacterManagementScreen extends StatefulWidget {
  final Novel novel;

  const CharacterManagementScreen({
    super.key,
    required this.novel,
  });

  @override
  State<CharacterManagementScreen> createState() => _CharacterManagementScreenState();
}

class _CharacterManagementScreenState extends State<CharacterManagementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final CharacterImageCacheService _imageCacheService = CharacterImageCacheService.instance;
  final CharacterAvatarService _avatarService = CharacterAvatarService();
  final DifyService _difyService = DifyService();
  List<Character> _characters = [];
  bool _isLoading = true;

  // 常量定义
  static const double _avatarBorderRadius = 8.0;
  static const double _nameBottomPadding = 8.0;
  static const double _nameHorizontalPadding = 8.0;

  // 缓存阴影样式
  final List<BoxShadow> _avatarShadow = [
    const BoxShadow(
      color: Color(0x4D000000), // Colors.black.withValues(alpha: 0.3)
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadCharacters();
  }

  /// 初始化服务
  Future<void> _initializeServices() async {
    try {
      await _imageCacheService.init();
    } catch (e) {
      debugPrint('初始化图片缓存服务失败: $e');
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

      setState(() {
        _characters = characters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载角色失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
    // 显示输入对话框
    final userInput = await CharacterInputDialog.show(context);
    if (userInput == null || userInput.trim().isEmpty) {
      return;
    }

    if (!mounted) return;

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在AI创建角色...'),
          ],
        ),
      ),
    );

    try {
      // 获取小说的背景设定
      final backgroundSetting = await _databaseService.getBackgroundSetting(widget.novel.url);

      // 调用Dify工作流创建角色
      final generatedCharacters = await _difyService.generateCharacters(
        userInput: userInput,
        novelUrl: widget.novel.url,
        backgroundSetting: backgroundSetting ?? '',
      );

      if (!mounted) return;

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 显示角色预览对话框，允许用户选择要保存的角色
      await CharacterPreviewDialog.show(
        context,
        characters: generatedCharacters,
        onConfirmed: (selectedCharacters) async {
          if (selectedCharacters.isNotEmpty) {
            await _saveSelectedCharacters(selectedCharacters);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      // 关闭加载对话框
      Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建角色失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 保存用户选择的特定角色
  Future<void> _saveSelectedCharacters(List<Character> selectedCharacters) async {
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
        String message;
        Color backgroundColor;

        if (failCount == 0) {
          message = '成功保存选中的 $successCount 个角色';
          backgroundColor = Colors.green;
        } else if (successCount == 0) {
          message = '保存失败，请检查配置或重试';
          backgroundColor = Colors.red;
        } else {
          message = '成功保存 $successCount 个角色，$failCount 个失败';
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
            action: failCount > 0 ? SnackBarAction(
              label: '查看详情',
              textColor: Colors.white,
              onPressed: () => _showFailDetails(failedCharacters),
            ) : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存角色时发生错误: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
              children: failedCharacters.map((failure) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('• $failure', style: const TextStyle(fontSize: 14)),
              )).toList(),
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

  
  /// 显示删除确认对话框
  Future<bool> _showDeleteConfirmationDialog(Character character) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色'),
        content: Text('确定要删除角色 "${character.name}" 吗？\n此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteCharacter(Character character) async {
    final confirmed = await _showDeleteConfirmationDialog(character);
    if (!confirmed || character.id == null) return;

    try {
      await _databaseService.deleteCharacter(character.id!);
      // 删除缓存的图片
      await _imageCacheService.deleteCharacterCachedImages(character.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('人物删除成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadCharacters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        title: Text('人物管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _aiCreateCharacter,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI创建角色',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characters.isEmpty
              ? _buildEmptyState()
              : _buildCharacterList(),
      floatingActionButton: FloatingActionButton(
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
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            '还没有创建人物',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右下角的 + 按钮创建第一个人物',
            style: TextStyle(
              color: Colors.grey[500],
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
    return Card(
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
                // 头像区域 - 可点击编辑
                Expanded(
                  flex: 3, // 调整flex比例适应新布局
                  child: GestureDetector(
                    onTap: () => _navigateToEdit(character: character),
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
                          left: _nameHorizontalPadding * 2, // 增加边距
                          right: _nameHorizontalPadding * 2,
                          child: Text(
                            character.name,
                            style: const TextStyle(
                              fontSize: 14, // 缩小人名字号
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 3, // 增强阴影效果
                                  offset: Offset(1, 1),
                                ),
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6, // 添加第二层阴影增强可读性
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 信息区域
                Expanded(
                  flex: 2, // 减少flex比例，让下半部分更紧凑
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 减少padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 职业标签
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 减少padding
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12), // 稍微减小圆角
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              character.occupation ?? '未知职业',
                              style: const TextStyle(
                                fontSize: 10, // 缩小职业字号
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2, // 支持换行
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8), // 减少间距

                        // 删除按钮
                        GestureDetector(
                          onTap: () => _deleteCharacter(character),
                          child: Container(
                            width: 36, // 缩小尺寸
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10), // 稍微减小圆角
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18, // 缩小图标尺寸
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
    );
  }

  /// 构建角色头像
  Widget _buildCharacterAvatar(Character character) {
    // 使用cachedImageUrl的变化来触发FutureBuilder重建
    final avatarKey = ValueKey('avatar_${character.id}_${character.cachedImageUrl}');
    return FutureBuilder<String?>(
      key: avatarKey,
      future: character.id != null ? _avatarService.getCharacterAvatarPath(character.id!) : Future.value(null),
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(_avatarBorderRadius),
        boxShadow: _avatarShadow,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
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
        color: Colors.white.withValues(alpha: 0.9),
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