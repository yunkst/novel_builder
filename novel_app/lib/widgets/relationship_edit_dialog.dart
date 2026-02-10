import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../core/interfaces/repositories/i_character_relation_repository.dart';
import '../utils/toast_utils.dart';

/// 关系编辑对话框
///
/// 用于创建或编辑角色关系
class RelationshipEditDialog extends StatefulWidget {
  final Character currentCharacter; // 当前角色
  final List<Character> availableCharacters; // 可选的目标角色列表
  final CharacterRelationship? relationship; // 要编辑的关系（null表示新建）
  final ICharacterRelationRepository relationRepository; // 角色关系仓库

  const RelationshipEditDialog({
    super.key,
    required this.currentCharacter,
    required this.availableCharacters,
    this.relationship,
    required this.relationRepository,
  });

  /// 显示对话框并返回编辑结果
  ///
  /// 返回值：
  /// - null: 用户取消
  /// - CharacterRelationship: 用户保存（新建或更新）
  static Future<CharacterRelationship?> show({
    required BuildContext context,
    required Character currentCharacter,
    required List<Character> availableCharacters,
    CharacterRelationship? relationship,
    required ICharacterRelationRepository relationRepository,
  }) {
    return showDialog<CharacterRelationship>(
      context: context,
      builder: (context) => RelationshipEditDialog(
        currentCharacter: currentCharacter,
        availableCharacters: availableCharacters,
        relationship: relationship,
        relationRepository: relationRepository,
      ),
    );
  }

  @override
  State<RelationshipEditDialog> createState() => _RelationshipEditDialogState();
}

class _RelationshipEditDialogState extends State<RelationshipEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _relationshipTypeController = TextEditingController();
  final _descriptionController = TextEditingController();

  Character? _selectedTargetCharacter;
  bool _isSaving = false;

  // 历史关系类型（用于自动补全）
  final List<String> _relationshipTypeHistory = [
    '师父',
    '徒弟',
    '父亲',
    '母亲',
    '儿子',
    '女儿',
    '丈夫',
    '妻子',
    '兄弟',
    '姐妹',
    '朋友',
    '敌人',
    '恋人',
    '搭档',
    '同门',
    '师兄',
    '师弟',
    '师姐',
    '师妹',
  ];

  @override
  void initState() {
    super.initState();

    // 如果是编辑模式，初始化数据
    if (widget.relationship != null) {
      _relationshipTypeController.text = widget.relationship!.relationshipType;
      _descriptionController.text = widget.relationship!.description ?? '';

      // 查找目标角色（注意方向）
      final targetId = widget.relationship!.targetCharacterId;
      _selectedTargetCharacter =
          widget.availableCharacters.where((c) => c.id == targetId).firstOrNull;
    }
  }

  @override
  void dispose() {
    _relationshipTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 保存关系
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTargetCharacter == null) {
      ToastUtils.showError('请选择目标角色');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 构建关系对象
      final relationship = CharacterRelationship(
        id: widget.relationship?.id,
        sourceCharacterId: widget.currentCharacter.id!,
        targetCharacterId: _selectedTargetCharacter!.id!,
        relationshipType: _relationshipTypeController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: widget.relationship?.createdAt,
        updatedAt: DateTime.now(),
      );

      // 检查关系是否已存在（仅新建时检查）
      if (widget.relationship == null) {
        final exists = await widget.relationRepository.relationshipExists(
          widget.currentCharacter.id!,
          _selectedTargetCharacter!.id!,
          relationship.relationshipType,
        );

        if (exists) {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
            ToastUtils.showWarning('该关系已存在，请使用其他关系类型');
          }
          return;
        }

        // 新建关系
        await widget.relationRepository.createRelationship(relationship);
      } else {
        // 更新关系
        await widget.relationRepository.updateRelationship(relationship);
      }

      if (mounted) {
        Navigator.of(context).pop(relationship);
      }
    } catch (e) {
      debugPrint('❌ 保存关系失败: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ToastUtils.showError('保存失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.relationship != null;

    return AlertDialog(
      title: Text(isEditMode ? '编辑关系' : '添加关系'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前角色提示
              Text(
                '${widget.currentCharacter.name} 的关系：',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 目标角色选择
              DropdownButtonFormField<Character>(
                initialValue: _selectedTargetCharacter,
                decoration: const InputDecoration(
                  labelText: '目标角色',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: widget.availableCharacters
                    .where((c) => c.id != widget.currentCharacter.id) // 排除自己
                    .map((character) {
                  return DropdownMenuItem<Character>(
                    value: character,
                    child: Text(character.name),
                  );
                }).toList(),
                onChanged: (character) {
                  setState(() {
                    _selectedTargetCharacter = character;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return '请选择目标角色';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 关系类型输入
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _relationshipTypeHistory.where((option) {
                    return option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _relationshipTypeController.text = selection;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  _relationshipTypeController.text = controller.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: '关系类型',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                      hintText: '例如：师父、徒弟、朋友',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入关系类型';
                      }
                      return null;
                    },
                    onFieldSubmitted: (value) {
                      onFieldSubmitted();
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // 描述输入
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  hintText: '详细描述这个关系...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : Text(isEditMode ? '保存' : '添加'),
        ),
      ],
    );
  }
}
