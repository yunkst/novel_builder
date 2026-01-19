import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../services/character_avatar_service.dart';
import '../../services/character_image_cache_service.dart';

/// 沉浸体验角色选择器
///
/// 用法：
/// ```dart
/// final selected = await ImmersiveRoleSelector.show(
///   context,
///   allCharacters: characters,
///   initialSelection: {1, 2, 3}, // 角色ID集合
/// );
/// ```
class ImmersiveRoleSelector extends StatefulWidget {
  /// 所有可选角色列表
  final List<Character> allCharacters;

  /// 初始选中的角色ID集合
  final Set<int> initialSelection;

  const ImmersiveRoleSelector({
    super.key,
    required this.allCharacters,
    required this.initialSelection,
  });

  @override
  State<ImmersiveRoleSelector> createState() => _ImmersiveRoleSelectorState();

  /// 显示角色选择器并返回选中的角色列表
  static Future<List<Character>?> show(
    BuildContext context, {
    required List<Character> allCharacters,
    required Set<int> initialSelection,
  }) async {
    return await Navigator.push<List<Character>>(
      context,
      MaterialPageRoute(
        builder: (context) => ImmersiveRoleSelector(
          allCharacters: allCharacters,
          initialSelection: initialSelection,
        ),
      ),
    );
  }
}

class _ImmersiveRoleSelectorState extends State<ImmersiveRoleSelector> {
  late Set<int> _selectedRoleIds;
  late CharacterImageCacheService _imageCacheService;
  late CharacterAvatarService _avatarService;

  // 缓存阴影样式
  final List<BoxShadow> _avatarShadow = [
    const BoxShadow(
      color: Color(0x4D000000), // Colors.black.withValues(alpha: 0.3)
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  bool get _isSelectAll =>
      _selectedRoleIds.length == widget.allCharacters.length;

  bool get _isAllSelected => _selectedRoleIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedRoleIds = widget.initialSelection;
    _imageCacheService = CharacterImageCacheService.instance;
    _avatarService = CharacterAvatarService();
    _initializeServices();
  }

  /// 初始化服务
  Future<void> _initializeServices() async {
    try {
      await _imageCacheService.init();
    } catch (e) {
      debugPrint('❌ 初始化图片缓存服务失败: $e');
    }
  }

  /// 切换单个角色的选中状态
  void _toggleRole(Character character) {
    setState(() {
      if (character.id == null) return;

      if (_selectedRoleIds.contains(character.id!)) {
        _selectedRoleIds.remove(character.id!);
      } else {
        _selectedRoleIds.add(character.id!);
      }
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (_isSelectAll) {
        // 取消全选
        _selectedRoleIds.clear();
      } else {
        // 全选
        _selectedRoleIds =
            widget.allCharacters.map((c) => c.id).whereType<int>().toSet();
      }
    });
  }

  /// 获取选中的角色列表
  List<Character> _getSelectedRoles() {
    return widget.allCharacters
        .where((c) => c.id != null && _selectedRoleIds.contains(c.id!))
        .toList();
  }

  /// 确认选择
  void _confirmSelection() {
    if (_selectedRoleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一个角色'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selected = _getSelectedRoles();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择参与角色'),
        actions: [
          // 全选/取消全选按钮
          if (_isAllSelected)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(_isSelectAll ? '取消全选' : '全选'),
            ),
          // 确认按钮
          IconButton(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check),
            tooltip: '确认',
          ),
        ],
      ),
      body: Column(
        children: [
          // 选中状态栏
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已选择 ${_selectedRoleIds.length} / ${widget.allCharacters.length} 个角色',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                if (_selectedRoleIds.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedRoleIds.clear()),
                    child: const Text('清空'),
                  ),
              ],
            ),
          ),
          // 角色网格
          Expanded(
            child: widget.allCharacters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          '暂无角色',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请先在角色管理中创建角色',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildCharacterGrid(),
          ),
        ],
      ),
      floatingActionButton: _selectedRoleIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check),
              label: Text('确认 (${_selectedRoleIds.length})'),
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  /// 构建角色网格
  Widget _buildCharacterGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式网格布局
        int crossAxisCount;
        double childAspectRatio;
        double crossAxisSpacing;
        double mainAxisSpacing;
        double horizontalPadding;

        if (constraints.maxWidth > 900) {
          // 大屏幕 - 4列布局
          crossAxisCount = 4;
          childAspectRatio = 0.75;
          crossAxisSpacing = 20;
          mainAxisSpacing = 20;
          horizontalPadding = 24;
        } else if (constraints.maxWidth > 600) {
          // 中等屏幕 - 3列布局
          crossAxisCount = 3;
          childAspectRatio = 0.8;
          crossAxisSpacing = 18;
          mainAxisSpacing = 18;
          horizontalPadding = 20;
        } else {
          // 小屏幕 - 2列布局
          crossAxisCount = 2;
          childAspectRatio = 0.85;
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
          itemCount: widget.allCharacters.length,
          itemBuilder: (context, index) {
            final character = widget.allCharacters[index];
            return _buildCharacterCard(character);
          },
        );
      },
    );
  }

  /// 构建角色卡片
  Widget _buildCharacterCard(Character character) {
    final isSelected =
        character.id != null && _selectedRoleIds.contains(character.id!);

    return GestureDetector(
      onTap: () => _toggleRole(character),
      child: Card(
        elevation: isSelected ? 12 : 6,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: Colors.purple, width: 2)
              : BorderSide.none,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 角色头像
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: _buildAvatar(character),
                  ),
                ),
                // 角色信息
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          character.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (character.occupation != null)
                          Text(
                            character.occupation!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (character.personality != null)
                          Text(
                            character.personality!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 选中标记
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                    boxShadow: _avatarShadow,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建角色头像
  Widget _buildAvatar(Character character) {
    if (character.cachedImageUrl != null &&
        character.cachedImageUrl!.isNotEmpty) {
      // 显示缓存图片
      return FutureBuilder<String?>(
        future: _avatarService.getCharacterAvatarPath(character.id!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final avatarFile = File(snapshot.data!);
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.file(
                avatarFile,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderAvatar(character);
                },
              ),
            );
          } else {
            // 显示占位符
            return _buildPlaceholderAvatar(character);
          }
        },
      );
    } else {
      // 显示占位符
      return _buildPlaceholderAvatar(character);
    }
  }

  /// 构建占位符头像
  Widget _buildPlaceholderAvatar(Character character) {
    return Container(
      color: Colors.purple.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.person,
          size: 48,
          color: Colors.purple.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
