import 'package:flutter/material.dart';
import '../../models/character.dart';
import 'immersive_role_selector.dart';

/// 沉浸体验配置数据类
class ImmersiveConfig {
  final String userRequirement;
  final List<String> roleNames;        // 保留,用于UI展示
  final List<Character> characters;     // 新增,用于AI格式化
  final String userRole;

  ImmersiveConfig({
    required this.userRequirement,
    required this.roleNames,
    required this.characters,
    required this.userRole,
  });

  Map<String, dynamic> toMap() {
    return {
      'userRequirement': userRequirement,
      'roleNames': roleNames,
      'characters': characters,
      'userRole': userRole,
    };
  }
}

/// 沉浸体验配置对话框
///
/// 用法：
/// ```dart
/// final config = await ImmersiveSetupDialog.show(
///   context,
///   chapterContent: chapterContent,
///   allCharacters: characters,
/// );
/// ```
class ImmersiveSetupDialog extends StatefulWidget {
  /// 章节内容（用于智能匹配角色）
  final String chapterContent;

  /// 所有可选角色列表
  final List<Character> allCharacters;

  const ImmersiveSetupDialog({
    super.key,
    required this.chapterContent,
    required this.allCharacters,
  });

  @override
  State<ImmersiveSetupDialog> createState() => _ImmersiveSetupDialogState();

  /// 显示对话框并返回配置
  static Future<ImmersiveConfig?> show(
    BuildContext context, {
    required String chapterContent,
    required List<Character> allCharacters,
  }) async {
    return await showDialog<ImmersiveConfig>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => ImmersiveSetupDialog(
        chapterContent: chapterContent,
        allCharacters: allCharacters,
      ),
    );
  }
}

class _ImmersiveSetupDialogState extends State<ImmersiveSetupDialog> {
  final _requirementController = TextEditingController();
  List<Character> _selectedRoles = [];
  String? _userRole;

  // 自动选中计数
  int get _autoSelectedCount => _selectedRoles.length;

  @override
  void initState() {
    super.initState();
    // 智能默认选择：自动勾选在章节中出现的角色
    _initializeDefaultRoles();
  }

  @override
  void dispose() {
    _requirementController.dispose();
    super.dispose();
  }

  /// 智能默认选择：根据角色名称在章节内容中的匹配情况自动勾选
  void _initializeDefaultRoles() {
    final selected = widget.allCharacters.where((role) {
      return _isRoleInChapter(role, widget.chapterContent);
    }).toList();

    setState(() {
      _selectedRoles = selected;
    });

    if (selected.isNotEmpty) {
      debugPrint('✅ 自动选择了 ${selected.length} 个在本章出现的角色');
      for (final role in selected) {
        debugPrint('   - ${role.name}');
      }
    }
  }

  /// 检查角色是否在章节内容中出现
  bool _isRoleInChapter(Character role, String chapterContent) {
    // 使用contains进行简单匹配
    return chapterContent.contains(role.name);
  }

  /// 显示角色选择器
  Future<void> _showRoleSelector() async {
    final initialSelection =
        _selectedRoles.map((r) => r.id).whereType<int>().toSet();

    final selected = await ImmersiveRoleSelector.show(
      context,
      allCharacters: widget.allCharacters,
      initialSelection: initialSelection,
    );

    if (selected != null) {
      setState(() {
        _selectedRoles = selected;
        // 如果用户角色不在新选择中，清空用户角色
        if (_userRole != null &&
            !_selectedRoles.any((r) => r.name == _userRole)) {
          _userRole = null;
        }
      });
    }
  }

  /// 移除角色
  void _removeRole(Character role) {
    setState(() {
      _selectedRoles.remove(role);
      // 如果移除的是用户角色，清空用户角色
      if (_userRole == role.name) {
        _userRole = null;
      }
    });
  }

  /// 验证并返回配置
  ImmersiveConfig? _validateAndReturn() {
    final requirement = _requirementController.text.trim();

    // 验证：用户要求不能为空
    if (requirement.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入沉浸体验要求'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    // 验证：至少选择一个角色
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一个参与角色'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    // 验证：必须选择用户角色
    if (_userRole == null || _userRole!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择您要扮演的角色'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    // 验证：用户角色必须在已选角色中
    if (!_selectedRoles.any((r) => r.name == _userRole)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('您扮演的角色必须在参与角色中'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return ImmersiveConfig(
      userRequirement: requirement,
      roleNames: _selectedRoles.map((r) => r.name).toList(),
      characters: _selectedRoles,        // 新增: 传递完整角色对象
      userRole: _userRole!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.theater_comedy, color: Colors.purple, size: 28),
          const SizedBox(width: 8),
          const Text('沉浸体验配置'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 用户要求输入
              Text(
                '体验要求',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _requirementController,
                decoration: InputDecoration(
                  labelText: '请描述您的沉浸体验要求',
                  hintText: '例如：我想体验一个充满悬疑和戏剧张力的场景...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                minLines: 2,
              ),
              const SizedBox(height: 16),

              // 角色选择
              Text(
                '参与角色',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _showRoleSelector,
                icon: const Icon(Icons.group_add),
                label: Text('选择角色 (已选${_selectedRoles.length}个)'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.purple,
                ),
              ),
              const SizedBox(height: 8),

              // 已选角色标签
              if (_selectedRoles.isNotEmpty) ...[
                if (_autoSelectedCount > 0 &&
                    _autoSelectedCount == _selectedRoles.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb,
                            size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '已自动选择在本章中出现的角色',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedRoles.map((role) {
                    return Chip(
                      label: Text(role.name),
                      onDeleted: () => _removeRole(role),
                      avatar: _userRole == role.name
                          ? const Icon(Icons.person, size: 16)
                          : null,
                      backgroundColor: _userRole == role.name
                          ? Colors.purple.withValues(alpha: 0.1)
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ] else
                const Text('未选择角色', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),

              // 用户角色选择
              Text(
                '您扮演的角色',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: '选择您要扮演的角色',
                  hintText: '从已选角色中选择',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                items: _selectedRoles.map((role) {
                  return DropdownMenuItem(
                    value: role.name,
                    child: Text(role.name),
                  );
                }).toList(),
                initialValue: _userRole,
                onChanged: (value) {
                  setState(() {
                    _userRole = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final config = _validateAndReturn();
            if (config != null) {
              Navigator.of(context).pop(config);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          child: const Text('开始生成'),
        ),
      ],
    );
  }
}
