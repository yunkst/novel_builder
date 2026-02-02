import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/novel.dart' as local_novel;
import '../models/character.dart';
import '../utils/character_matcher.dart';
import '../utils/toast_utils.dart';
import '../screens/gallery_view_screen.dart';
import '../screens/character_chat_screen.dart';
import '../screens/character_relationship_screen.dart';
import '../widgets/model_selector.dart';
import '../widgets/chat_scene_input_dialog.dart';
import '../widgets/common/common_widgets.dart';
import '../core/providers/character_screen_providers.dart';
import '../core/providers/service_providers.dart';
import '../core/providers/database_providers.dart';

/// 使用方法：RoleGalleryCacheService用于检查角色图集是否为空，在头像点击时进行验证
/// 调用方式：在_openGallery方法中调用_checkGalleryEmpty方法检查图集状态

class CharacterEditScreen extends ConsumerStatefulWidget {
  final local_novel.Novel novel;
  final Character? character;

  const CharacterEditScreen({
    super.key,
    required this.novel,
    this.character,
  });

  @override
  ConsumerState<CharacterEditScreen> createState() =>
      _CharacterEditScreenState();
}

class _CharacterEditScreenState extends ConsumerState<CharacterEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // 表单控制器
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _occupationController = TextEditingController();
  final _personalityController = TextEditingController();
  final _bodyTypeController = TextEditingController();
  final _clothingStyleController = TextEditingController();
  final _appearanceController = TextEditingController();
  final _backgroundController = TextEditingController();
  final _facePromptsController = TextEditingController();
  final _bodyPromptsController = TextEditingController();

  String? _selectedGender;
  String? _selectedModel;
  bool _isLoading = false;
  bool _isGeneratingPrompts = false;
  bool _isGeneratingRoleCard = false;
  List<String> _aliases = []; // 别名列表
  final TextEditingController _aliasController = TextEditingController();

  final List<String> _genderOptions = ['男', '女', '其他'];
  final List<String> _commonBodyTypes = [
    '瘦弱',
    '标准',
    '健壮',
    '肥胖',
    '苗条',
    '高大',
    '矮小'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.character != null) {
      final character = widget.character!;
      _nameController.text = character.name;
      _ageController.text = character.age?.toString() ?? '';
      _selectedGender = character.gender;
      _occupationController.text = character.occupation ?? '';
      _personalityController.text = character.personality ?? '';
      _bodyTypeController.text = character.bodyType ?? '';
      _clothingStyleController.text = character.clothingStyle ?? '';
      _appearanceController.text = character.appearanceFeatures ?? '';
      _backgroundController.text = character.backgroundStory ?? '';
      _facePromptsController.text = character.facePrompts ?? '';
      _bodyPromptsController.text = character.bodyPrompts ?? '';
      _aliases = List.from(character.aliases ?? []);
    }

    // 监听姓名变化
    _nameController.addListener(() {
      setState(() {}); // 触发界面更新
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    _personalityController.dispose();
    _bodyTypeController.dispose();
    _clothingStyleController.dispose();
    _appearanceController.dispose();
    _backgroundController.dispose();
    _facePromptsController.dispose();
    _bodyPromptsController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  /// 重新加载角色数据
  Future<void> _refreshCharacterData() async {
    if (widget.character?.id == null) return;

    try {
      // 使用 Provider 的 refresh 方法
      await ref
          .read(characterEditControllerProvider(
            novel: widget.novel,
            character: widget.character,
          ).notifier)
          .refresh();

      // 获取更新后的数据
      final updatedCharacter = ref.read(characterEditControllerProvider(
        novel: widget.novel,
        character: widget.character,
      ));

      if (updatedCharacter.value != null) {
        // 更新控制器数据
        _nameController.text = updatedCharacter.value!.name;
        _ageController.text = updatedCharacter.value!.age?.toString() ?? '';
        _selectedGender = updatedCharacter.value!.gender;
        _occupationController.text = updatedCharacter.value!.occupation ?? '';
        _personalityController.text = updatedCharacter.value!.personality ?? '';
        _bodyTypeController.text = updatedCharacter.value!.bodyType ?? '';
        _clothingStyleController.text =
            updatedCharacter.value!.clothingStyle ?? '';
        _appearanceController.text =
            updatedCharacter.value!.appearanceFeatures ?? '';
        _backgroundController.text =
            updatedCharacter.value!.backgroundStory ?? '';
        _facePromptsController.text = updatedCharacter.value!.facePrompts ?? '';
        _bodyPromptsController.text = updatedCharacter.value!.bodyPrompts ?? '';
        _aliases = List.from(updatedCharacter.value!.aliases ?? []);

        // 触发UI更新
        setState(() {});
      }

      if (mounted) {
        ToastUtils.showInfo('数据已刷新');
      }
    } catch (e) {
      debugPrint('❌ 刷新角色数据失败: $e');
    }
  }

  Future<void> _saveCharacter() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final controller = ref.read(characterEditControllerProvider(
        novel: widget.novel,
        character: widget.character,
      ).notifier);

      final success = await controller.saveCharacter(
        name: _nameController.text.trim(),
        age: _ageController.text.isNotEmpty
            ? int.tryParse(_ageController.text)
            : null,
        gender: _selectedGender,
        occupation: _occupationController.text.trim().isNotEmpty
            ? _occupationController.text.trim()
            : null,
        personality: _personalityController.text.trim().isNotEmpty
            ? _personalityController.text.trim()
            : null,
        bodyType: _bodyTypeController.text.trim().isNotEmpty
            ? _bodyTypeController.text.trim()
            : null,
        clothingStyle: _clothingStyleController.text.trim().isNotEmpty
            ? _clothingStyleController.text.trim()
            : null,
        appearanceFeatures: _appearanceController.text.trim().isNotEmpty
            ? _appearanceController.text.trim()
            : null,
        backgroundStory: _backgroundController.text.trim().isNotEmpty
            ? _backgroundController.text.trim()
            : null,
        facePrompts: _facePromptsController.text.trim().isNotEmpty
            ? _facePromptsController.text.trim()
            : null,
        bodyPrompts: _bodyPromptsController.text.trim().isNotEmpty
            ? _bodyPromptsController.text.trim()
            : null,
        aliases: _aliases.isEmpty ? null : List.from(_aliases),
      );

      if (success && mounted) {
        ToastUtils.showSuccess(
          widget.character == null ? '人物创建成功' : '人物更新成功',
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ToastUtils.showError('保存失败');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('保存失败: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateRoleCardImages() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        ToastUtils.showWarning('请先填写角色姓名');
      }
      return;
    }

    setState(() {
      _isGeneratingRoleCard = true;
    });

    try {
      final apiService = ref.read(apiServiceWrapperProvider);

      // 构建角色数据 - 包含完整的角色信息
      final roles = <String, dynamic>{};

      // 基本信息
      roles['name'] = _nameController.text.trim();

      if (_ageController.text.isNotEmpty) {
        roles['age'] = _ageController.text.trim();
      }

      if (_selectedGender != null && _selectedGender!.isNotEmpty) {
        roles['gender'] = _selectedGender;
      }

      if (_occupationController.text.isNotEmpty) {
        roles['occupation'] = _occupationController.text.trim();
      }

      if (_personalityController.text.isNotEmpty) {
        roles['personality'] = _personalityController.text.trim();
      }

      if (_appearanceController.text.isNotEmpty) {
        roles['appearance_features'] = _appearanceController.text.trim();
      }

      if (_bodyTypeController.text.isNotEmpty) {
        roles['body_type'] = _bodyTypeController.text.trim();
      }

      if (_clothingStyleController.text.isNotEmpty) {
        roles['clothing_style'] = _clothingStyleController.text.trim();
      }

      // AI 提示词
      if (_facePromptsController.text.isNotEmpty) {
        roles['face_prompts'] = _facePromptsController.text.trim();
      }
      if (_bodyPromptsController.text.isNotEmpty) {
        roles['body_prompts'] = _bodyPromptsController.text.trim();
      }

      // 使用角色ID或临时ID
      final String roleId = widget.character?.id?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // 调用API服务包装器的方法，自动处理token认证
      final response = await apiService.generateRoleCardImages(
        roleId: roleId,
        roles: roles,
        modelName: _selectedModel, // 传递用户选择的模型
      );

      if (mounted) {
        ToastUtils.showSuccess('图片生成中，请耐心等待');
      }

      debugPrint('角色卡生成响应: $response');
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('生成失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingRoleCard = false;
        });
      }
    }
  }

  Future<void> _generateCharacterPrompts() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        ToastUtils.showWarning('请先填写角色姓名');
      }
      return;
    }

    setState(() {
      _isGeneratingPrompts = true;
    });

    try {
      // 组合角色描写信息
      final characterDescription = '''
角色姓名：${_nameController.text.trim()}
性别：${_selectedGender ?? '未知'}
年龄：${_ageController.text.isNotEmpty ? _ageController.text : '未知'}
职业：${_occupationController.text.isNotEmpty ? _occupationController.text : '未知'}
外貌特征：${_appearanceController.text.isNotEmpty ? _appearanceController.text : '待补充'}
身材体型：${_bodyTypeController.text.isNotEmpty ? _bodyTypeController.text : '待补充'}
性格特点：${_personalityController.text.isNotEmpty ? _personalityController.text : '待补充'}
背景经历：${_backgroundController.text.isNotEmpty ? _backgroundController.text : '待补充'}
      '''
          .trim();

      final difyService = ref.read(difyServiceProvider);
      final prompts = await difyService.generateCharacterPrompts(
        characterDescription: characterDescription,
      );

      if (mounted) {
        setState(() {
          _facePromptsController.text = prompts['face_prompts'] ?? '';
          _bodyPromptsController.text = prompts['body_prompts'] ?? '';
          _isGeneratingPrompts = false;
        });

        ToastUtils.showSuccess('提示词生成成功，即将自动保存...');

        // 延迟自动保存
        _autoSaveAfterPromptsGeneration();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingPrompts = false;
        });

        ToastUtils.showError('生成失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.character != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑人物' : '创建人物'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveCharacter,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('保存',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本信息区域
              _buildSectionTitle('基本信息'),
              const SizedBox(height: 12),
              _buildBasicInfoSection(),

              const SizedBox(height: 24),

              // 外貌特征区域
              _buildSectionTitle('外貌特征'),
              const SizedBox(height: 12),
              _buildAppearanceSection(),

              const SizedBox(height: 24),

              // 性格背景区域
              _buildSectionTitle('性格与背景'),
              const SizedBox(height: 12),
              _buildPersonalitySection(),

              const SizedBox(height: 32),

              // 查看关系按钮（仅在编辑模式显示）
              if (isEditing) _buildRelationshipButton(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: isEditing && widget.character != null
          ? FloatingActionButton(
              onPressed: _startChat,
              tooltip: '与TA聊天',
              child: const Icon(Icons.chat_outlined),
            )
          : null,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final isEditing = widget.character != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：头像（如果处于编辑模式）
            if (isEditing) _buildTopAvatarRow(),
            // 第二行：基本信息字段
            _buildBasicInfoFields(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAvatarRow() {
    return Row(
      children: [
        // 头像
        _buildCharacterAvatar(),
        const SizedBox(width: 16),
        // 角色名称（大号字体）
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameController.text.isNotEmpty ? _nameController.text : '新角色',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.87),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '点击头像管理图集',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 添加间距分隔头像和表单字段
        if (widget.character != null) const SizedBox(height: 20),
        // 姓名
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '姓名 *',
            hintText: '请输入人物姓名',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入人物姓名';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // 性别和年龄
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: '性别',
                  border: OutlineInputBorder(),
                ),
                items: _genderOptions.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: '年龄',
                  hintText: '如：25',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final age = int.tryParse(value);
                    if (age == null || age < 0 || age > 999) {
                      return '请输入有效年龄';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 职业
        TextFormField(
          controller: _occupationController,
          decoration: const InputDecoration(
            labelText: '职业',
            hintText: '如：学生、医生、教师等',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // 别名编辑
        _buildAliasesSection(),
      ],
    );
  }

  /// 构建别名编辑区域
  Widget _buildAliasesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '别名',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_aliases.length}/10',
              style: TextStyle(
                fontSize: 12,
                color: _aliases.length >= 10
                    ? Colors.red
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 别名标签列表
        if (_aliases.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _aliases.map((alias) {
              return Chip(
                label: Text(alias),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _aliases.remove(alias);
                  });
                },
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
              );
            }).toList(),
          ),
        if (_aliases.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '暂无别名，可添加常用称呼',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),

        const SizedBox(height: 12),

        // 添加别名输入框
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _aliasController,
                decoration: InputDecoration(
                  labelText: '新别名',
                  hintText: '输入别名后点击添加',
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: _aliases.length >= 10
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                enabled: _aliases.length < 10,
                onFieldSubmitted: (_) => _addAlias(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _aliases.length >= 10 ? null : _addAlias,
              style: ElevatedButton.styleFrom(
                backgroundColor: _aliases.length >= 10
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)
                    : Theme.of(context).primaryColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              child: const Text('添加'),
            ),
          ],
        ),
      ],
    );
  }

  /// 添加别名
  Future<void> _addAlias() async {
    final alias = _aliasController.text.trim();

    // 验证别名不为空
    if (alias.isEmpty) {
      if (mounted) {
        ToastUtils.showWarning('请输入别名');
      }
      return;
    }

    // 验证别名不重复
    if (_aliases.contains(alias)) {
      if (mounted) {
        ToastUtils.showWarning('该别名已存在');
      }
      return;
    }

    // 检查冲突
    final tempCharacter = Character(
      id: widget.character?.id,
      novelUrl: widget.novel.url,
      name: _nameController.text.trim(),
    );

    final databaseService = ref.read(databaseServiceProvider);
    final allCharacters = await databaseService.getCharacters(widget.novel.url);
    final conflict = CharacterMatcher.checkAliasConflict(
      alias,
      tempCharacter,
      allCharacters,
    );

    if (conflict != null) {
      // 显示冲突警告对话框
      final shouldAdd = await _showAliasConflictDialog(conflict);
      if (!shouldAdd) return;
    }

    // 添加别名
    setState(() {
      _aliases.add(alias);
      _aliasController.clear();
    });
  }

  /// 提示词生成后自动保存
  Future<void> _autoSaveAfterPromptsGeneration() async {
    final autoSaveStateNotifier = ref.read(autoSaveStateProvider.notifier);
    final isAutoSaving = ref.read(autoSaveStateProvider);

    if (isAutoSaving) return; // 防止重复保存

    autoSaveStateNotifier.setSaving(true);

    try {
      // 延迟1.5秒后保存
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      final controller = ref.read(characterEditControllerProvider(
        novel: widget.novel,
        character: widget.character,
      ).notifier);

      // 使用 Provider 的 autoSave 方法
      await controller.autoSave(
        name: _nameController.text.trim(),
        facePrompts: _facePromptsController.text.trim().isNotEmpty
            ? _facePromptsController.text.trim()
            : null,
        bodyPrompts: _bodyPromptsController.text.trim().isNotEmpty
            ? _bodyPromptsController.text.trim()
            : null,
      );

      if (mounted) {
        ToastUtils.showInfo(
          widget.character == null ? '角色创建并已自动保存' : '已自动保存',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showWarningWithAction('自动保存失败: $e', '手动保存', () {
          _saveCharacter();
        });
      }
    } finally {
      if (mounted) {
        autoSaveStateNotifier.setSaving(false);
      }
    }
  }

  /// 显示别名冲突对话框
  ///
  /// 返回 true 表示用户仍要添加，false 表示取消
  Future<bool> _showAliasConflictDialog(String conflictMessage) async {
    if (!mounted) return false;

    final result = await ConfirmDialog.show(
      context,
      title: '检测到别名冲突',
      message: '$conflictMessage，\n可能导致角色匹配混乱。\n\n是否仍要添加？',
      confirmText: '仍要添加',
      cancelText: '取消',
      icon: Icons.warning,
      confirmColor: Colors.orange,
    );

    return result ?? false;
  }

  /// 构建角色头像（编辑页面使用，80px）
  Widget _buildCharacterAvatar() {
    return GestureDetector(
      onTap: _openGallery,
      child: Consumer(
        builder: (context, ref, child) {
          final avatarService = ref.watch(characterAvatarServiceProvider);

          return FutureBuilder<String?>(
            future: widget.character?.id != null
                ? avatarService.getCharacterAvatarPath(widget.character!.id!)
                : Future.value(null),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingAvatar(80);
              }

              final avatarPath = snapshot.data;
              if (avatarPath != null && File(avatarPath).existsSync()) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.file(
                      File(avatarPath),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('❌ 头像加载失败: $error');
                        return _buildFallbackAvatar(80);
                      },
                    ),
                  ),
                );
              }

              return _buildFallbackAvatar(80);
            },
          );
        },
      ),
    );
  }

  /// 构建加载中头像
  Widget _buildLoadingAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.3,
          height: size * 0.3,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建备用头像（首字母）
  Widget _buildFallbackAvatar(double size) {
    final characterName = widget.character?.name ?? '';
    final initial =
        characterName.isNotEmpty ? characterName[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 身材
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _commonBodyTypes.where((option) {
                  return option.contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                _bodyTypeController.text = selection;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                // 初始化controller的值
                if (controller.text.isEmpty &&
                    _bodyTypeController.text.isNotEmpty) {
                  controller.text = _bodyTypeController.text;
                }
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: '身材',
                    hintText: '如：标准、瘦弱、健壮等',
                    border: OutlineInputBorder(),
                  ),
                  onEditingComplete: onEditingComplete,
                  onChanged: (value) {
                    _bodyTypeController.text = value;
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // 穿衣风格
            TextFormField(
              controller: _clothingStyleController,
              decoration: const InputDecoration(
                labelText: '穿衣风格',
                hintText: '如：休闲、正式、运动等',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 外貌特点
            TextFormField(
              controller: _appearanceController,
              decoration: const InputDecoration(
                labelText: '外貌特点',
                hintText: '描述人物的显著外貌特征',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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

            // 生成提示词和生图按钮
            Row(
              children: [
                // 生成提示词按钮
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final isAutoSaving = ref.watch(autoSaveStateProvider);

                      return ElevatedButton.icon(
                        onPressed: (_isGeneratingPrompts || isAutoSaving)
                            ? null
                            : _generateCharacterPrompts,
                        icon: _isGeneratingPrompts
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : isAutoSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome),
                        label: Text(_isGeneratingPrompts
                            ? '生成中...'
                            : isAutoSaving
                                ? '保存中...'
                                : '生成提示词'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // 生成人物卡按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_nameController.text.trim().isEmpty ||
                            _isGeneratingRoleCard)
                        ? null
                        : _generateRoleCardImages,
                    icon: _isGeneratingRoleCard
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image),
                    label: Text(_isGeneratingRoleCard ? '生成中...' : '生图'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _nameController.text.trim().isEmpty
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)
                          : Colors.green,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // AI生成的提示词字段
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI生成的提示词',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 面部提示词
                  TextFormField(
                    controller: _facePromptsController,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.surface),
                    decoration: InputDecoration(
                      labelText: '面部提示词',
                      hintText: '用于AI绘画的面部描述',
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.7)),
                      hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.38)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.24)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.54)),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // 身材提示词
                  TextFormField(
                    controller: _bodyPromptsController,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.surface),
                    decoration: InputDecoration(
                      labelText: '身材提示词',
                      hintText: '用于AI绘画的身材描述',
                      border: const OutlineInputBorder(),
                      labelStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.7)),
                      hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.38)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.24)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.54)),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 性格
            TextFormField(
              controller: _personalityController,
              decoration: const InputDecoration(
                labelText: '性格特点',
                hintText: '描述人物的性格特征',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // 经历简述
            TextFormField(
              controller: _backgroundController,
              decoration: const InputDecoration(
                labelText: '经历简述',
                hintText: '描述人物的背景故事和重要经历',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  /// 检查角色图集是否为空
  /// 返回true表示图集为空，false表示图集不为空
  Future<bool> _checkGalleryEmpty(String characterId) async {
    try {
      final apiService = ref.read(apiServiceWrapperProvider);

      // 通过ApiServiceWrapper调用，token自动处理
      final galleryData = await apiService.getRoleGallery(characterId);

      final rawImages = galleryData['images'];
      if (rawImages is List && rawImages.isNotEmpty) {
        debugPrint('角色图集检查: 找到 ${rawImages.length} 张图片');
        return false;
      } else {
        debugPrint('角色图集检查: 图集数据为空');
        return true;
      }
    } catch (e) {
      debugPrint('❌ 检查图集状态异常: $e');
      // 如果发生异常，假设图集为空，避免用户进入空页面
      return true;
    }
  }

  /// 显示图集为空的对话框
  Future<void> _showEmptyGalleryDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('角色图集为空，请先生成图集后再点击'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 打开图集管理页面
  Future<void> _openGallery() async {
    if (widget.character?.id == null) {
      if (mounted) {
        ToastUtils.showWarning('请先保存角色后再管理图集');
      }
      return;
    }

    // 检查图集是否为空
    final isEmpty = await _checkGalleryEmpty(widget.character!.id!.toString());
    if (isEmpty) {
      await _showEmptyGalleryDialog();
      return;
    }

    if (!mounted) return;

    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => GalleryViewScreen(
            roleId: widget.character!.id!.toString(),
            roleName: widget.character!.name,
          ),
        ),
      );

      // 如果图集页面返回true，说明头像已更新，需要重新加载数据
      if (result == true && mounted) {
        await _refreshCharacterData();
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('打开图集失败: $e');
      }
    }
  }

  /// 开始聊天
  Future<void> _startChat() async {
    if (widget.character == null) {
      if (mounted) {
        ToastUtils.showWarning('请先保存角色后再开始聊天');
      }
      return;
    }

    // 显示场景输入对话框
    final scene = await ChatSceneInputDialog.show(context);

    if (scene == null || scene.trim().isEmpty) return;

    if (!mounted) return;

    // 导航到聊天屏幕
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterChatScreen(
          character: widget.character!,
          initialScene: scene,
        ),
      ),
    );
  }

  /// 导航到关系页面
  Future<void> _navigateToRelationships() async {
    if (widget.character == null) return;

    // 先保存当前更改
    await _saveCharacter();

    if (!mounted) return;

    // 导航到关系页面
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterRelationshipScreen(
          character: widget.character!,
        ),
      ),
    );
  }

  /// 构建查看关系按钮
  Widget _buildRelationshipButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _navigateToRelationships,
        icon: const Icon(Icons.link),
        label: const Text('查看关系'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
