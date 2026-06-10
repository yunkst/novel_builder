import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_force_directed_graph/flutter_force_directed_graph.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../core/interfaces/repositories/i_character_repository.dart';
import '../core/interfaces/repositories/i_character_relation_repository.dart';
import '../core/providers/database_providers.dart';
import '../core/theme/app_colors.dart';
import '../utils/toast_utils.dart';
import '../services/logger_service.dart';

/// 统一的角色关系图可视化页面 - Riverpod版本
///
/// 这是原始 UnifiedRelationshipGraphScreen 的 Riverpod 包装器
class UnifiedRelationshipGraphScreenRiverpod extends ConsumerStatefulWidget {
  final String novelUrl;
  final Character? focusCharacter; // null = 全局模式

  const UnifiedRelationshipGraphScreenRiverpod({
    super.key,
    required this.novelUrl,
    this.focusCharacter,
  });

  @override
  ConsumerState<UnifiedRelationshipGraphScreenRiverpod> createState() =>
      _UnifiedRelationshipGraphScreenRiverpodState();
}

class _UnifiedRelationshipGraphScreenRiverpodState
    extends ConsumerState<UnifiedRelationshipGraphScreenRiverpod> {
  // 使用Repository接口而非DatabaseService
  late final ICharacterRepository _characterRepository;
  late final ICharacterRelationRepository _characterRelationRepository;

  // 控制器
  late final ForceDirectedGraphController<int> _controller;

  // 角色映射表: id -> Character
  final Map<int, Character> _characterMap = {};

  // 关系列表映射表: (sourceId, targetId) -> CharacterRelationship
  final Map<String, CharacterRelationship> _relationshipMap = {};

  // 头像缓存
  final Map<int, ImageProvider> _avatarProviders = {};

  // 关系列表(用于计算节点度数)
  List<CharacterRelationship> _relationships = [];

  bool _isLoading = true;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();

    // 使用 Provider 注入 Repository 接口
    _characterRepository = ref.read(characterRepositoryProvider);
    _characterRelationRepository =
        ref.read(characterRelationRepositoryProvider);

    // 修复缩放问题: 设置初始缩放为0.6,允许用户缩小和放大
    _controller = ForceDirectedGraphController<int>(
      minScale: 0.1, // 允许缩小到10%
      maxScale: 5.0, // 允许放大到5倍
    )..setOnScaleChange((scale) {
        if (mounted) {
          setState(() {
            _currentScale = scale;
          });
        }
      });
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 加载关系数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.focusCharacter != null) {
        // 单角色模式:只加载相关节点
        await _loadSingleCharacterData();
      } else {
        // 全局模式:加载所有节点
        await _loadGlobalData();
      }

      setState(() {
        _isLoading = false;
      });

      final mode = widget.focusCharacter != null ? '单角色' : '全局';
      LoggerService.instance.i(
        '关系图加载完成($mode): ${_characterMap.length} 个节点, ${_relationships.length} 条边',
        category: LogCategory.character,
        tags: ['relationship'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '加载关系图数据失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['relationship'],
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ToastUtils.showError('加载数据失败: $e');
      }
    }
  }

  /// 加载单角色数据
  Future<void> _loadSingleCharacterData() async {
    final character = widget.focusCharacter!;
    final allCharacters =
        await _characterRepository.getCharacters(character.novelUrl);

    // 加载当前角色的所有关系
    final relationships =
        await _characterRelationRepository.getRelationships(character.id!);

    // 收集相关角色ID
    final relatedCharacterIds = <int>{};
    for (final rel in relationships) {
      relatedCharacterIds.add(rel.sourceCharacterId);
      relatedCharacterIds.add(rel.targetCharacterId);
    }

    // 过滤出相关角色
    final relatedCharacters = allCharacters
        .where((c) => c.id != null && relatedCharacterIds.contains(c.id))
        .toList();

    // 构建映射表
    for (final character in relatedCharacters) {
      if (character.id != null) {
        _characterMap[character.id!] = character;
      }
    }

    for (final rel in relationships) {
      final key = '${rel.sourceCharacterId}-${rel.targetCharacterId}';
      _relationshipMap[key] = rel;
    }

    // 预加载头像
    await _preloadAvatars(relatedCharacters);

    // 构建图数据
    _buildGraph(relatedCharacters, relationships);

    _relationships = relationships;
  }

  /// 加载全局数据
  Future<void> _loadGlobalData() async {
    // 加载所有角色
    final allCharacters =
        await _characterRepository.getCharacters(widget.novelUrl);

    if (allCharacters.isEmpty) {
      return;
    }

    // 加载所有角色的关系
    final Set<CharacterRelationship> allRelationships = {};
    for (final character in allCharacters) {
      if (character.id != null) {
        final rels =
            await _characterRelationRepository.getRelationships(character.id!);
        allRelationships.addAll(rels);
      }
    }

    // 构建映射表
    for (final character in allCharacters) {
      if (character.id != null) {
        _characterMap[character.id!] = character;
      }
    }

    // 去重关系(因为关系是双向的)
    final uniqueRelationships = <CharacterRelationship>[];
    final seenKeys = <String>{};

    for (final rel in allRelationships) {
      final key = '${rel.sourceCharacterId}-${rel.targetCharacterId}';
      final reverseKey = '${rel.targetCharacterId}-${rel.sourceCharacterId}';

      if (!seenKeys.contains(key) && !seenKeys.contains(reverseKey)) {
        seenKeys.add(key);
        uniqueRelationships.add(rel);
      }

      // 建立关系映射
      _relationshipMap[key] = rel;
    }

    // 预加载头像
    await _preloadAvatars(allCharacters);

    // 构建图数据
    _buildGraph(allCharacters, uniqueRelationships);

    _relationships = uniqueRelationships;
  }

  /// 预加载头像
  Future<void> _preloadAvatars(List<Character> characters) async {
    for (final character in characters) {
      if (character.id == null) continue;

      if (character.cachedImageUrl != null &&
          character.cachedImageUrl!.isNotEmpty) {
        try {
          final imageFile = File(character.cachedImageUrl!);
          if (await imageFile.exists()) {
            _avatarProviders[character.id!] = FileImage(imageFile);
          }
        } catch (e) {
          LoggerService.instance.w(
            '加载头像失败: ${character.name}, $e',
            category: LogCategory.character,
            tags: ['relationship'],
          );
        }
      }
    }
  }

  /// 构建图数据
  void _buildGraph(
    List<Character> characters,
    List<CharacterRelationship> relationships,
  ) {
    // 添加所有节点
    for (final character in characters) {
      if (character.id != null) {
        _controller.addNode(character.id!);
      }
    }

    // 添加所有边
    for (final rel in relationships) {
      _controller.addEdgeByData(
        rel.sourceCharacterId,
        rel.targetCharacterId,
      );
    }

    // 首次加载后居中
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.center();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSingleMode = widget.focusCharacter != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isSingleMode ? '${widget.focusCharacter!.name} - 关系图' : '全人物关系图'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          // 显示缩放比例
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${(_currentScale * 100).toInt()}%',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // 显示节点和边数量
          if (!isSingleMode)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '节点: ${_characterMap.length} | 边: ${_relationships.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          // 重新居中
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: '适应屏幕',
            onPressed: () {
              _controller.center();
              ToastUtils.showSuccess('已重新居中');
            },
          ),
          // 定位到中心角色(仅单角色模式)
          if (isSingleMode && widget.focusCharacter!.id != null)
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: '定位到主角',
              onPressed: () {
                _controller.locateTo(widget.focusCharacter!.id!);
                ToastUtils.showSuccess('已定位到${widget.focusCharacter!.name}');
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _characterMap.isEmpty
              ? _buildEmptyState()
              : _buildForceDirectedGraph(),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.focusCharacter != null
                ? Icons.link_off
                : Icons.people_outline,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            widget.focusCharacter != null ? '还没有任何关系' : '暂无角色数据',
            style: TextStyle(
                fontSize: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  /// 构建关系图
  Widget _buildForceDirectedGraph() {
    return ForceDirectedGraphWidget<int>(
      controller: _controller,
      onDraggingStart: (characterId) {
        final character = _characterMap[characterId];
        LoggerService.instance.d(
          '开始拖拽: ${character?.name}',
          category: LogCategory.character,
          tags: ['relationship'],
        );
      },
      onDraggingEnd: (characterId) {
        final character = _characterMap[characterId];
        LoggerService.instance.d(
          '结束拖拽: ${character?.name}',
          category: LogCategory.character,
          tags: ['relationship'],
        );
      },
      onDraggingUpdate: (characterId) {
        // 拖拽中,可以添加实时更新逻辑
      },
      nodesBuilder: (context, nodeId) {
        return _buildNodeWidget(nodeId);
      },
      edgesBuilder: (context, sourceId, targetId, distance) {
        return _buildEdgeWidget(sourceId, targetId, distance);
      },
    );
  }

  /// 构建节点Widget
  Widget _buildNodeWidget(int characterId) {
    final character = _characterMap[characterId];

    if (character == null) {
      return const SizedBox.shrink();
    }

    // 计算节点的度数(关系数量)
    final degree = _relationships
        .where((r) =>
            r.sourceCharacterId == characterId ||
            r.targetCharacterId == characterId)
        .length;

    // 是否是中心节点(仅单角色模式)
    final isCenter = widget.focusCharacter != null &&
        character.id == widget.focusCharacter!.id;

    // 根据度数和是否是中心节点计算大小
    // 优化：减小基础大小，增加度数权重的影响，使节点大小差异更明显
    final baseSize = isCenter ? 60.0 : 40.0; // 减小基础大小
    final size = baseSize + degree * 3.0; // 增加度数权重
    final maxSize = 85.0; // 减小最大尺寸
    final minSize = 35.0; // 设置最小尺寸，防止节点过小
    final finalSize = size.clamp(minSize, maxSize); // 使用clamp限制大小范围

    return GestureDetector(
      onTap: () {
        _showNodeDetails(character, degree);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 节点圆形
          Container(
            width: finalSize,
            height: finalSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCenter
                    ? [
                        context.appColors.graphCenterStart,
                        context.appColors.graphCenterEnd,
                      ]
                    : [
                        _getGenderColor(context, character.gender)
                            .withValues(alpha: 0.9),
                        _getGenderColor(context, character.gender),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isCenter
                      ? context.appColors.graphCenterGlow
                      : _getGenderColor(context, character.gender)
                          .withValues(alpha: 0.4),
                  blurRadius: isCenter ? 16 : 12,
                  spreadRadius: isCenter ? 3 : 2,
                ),
              ],
              border: Border.all(
                color: isCenter
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.7),
                width: isCenter ? 4 : 3,
              ),
            ),
            child: ClipOval(
              child: _avatarProviders.containsKey(character.id)
                  ? Image(
                      image: _avatarProviders[character.id]!,
                      width: finalSize,
                      height: finalSize,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        character.name.isNotEmpty ? character.name[0] : '?',
                        style: TextStyle(
                          fontSize: finalSize * 0.4,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.surface,
                          shadows: [
                            Shadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // 角色名称标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCenter
                  ? context.appColors.graphCenterBorder
                  : Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCenter
                    ? context.appColors.graphCenterEnd
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              character.name,
              style: TextStyle(
                fontSize: isCenter ? 14 : 12,
                fontWeight: isCenter ? FontWeight.bold : FontWeight.w600,
                color: isCenter
                    ? context.appColors.graphCenterOnDark
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.87),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建边Widget
  Widget _buildEdgeWidget(int sourceId, int targetId, double distance) {
    // 查找这两个节点之间的关系
    final key = '$sourceId-$targetId';
    final reverseKey = '$targetId-$sourceId';

    final relationship = _relationshipMap[key] ?? _relationshipMap[reverseKey];

    if (relationship == null) {
      // 默认灰色线
      return Container(
        height: 2,
        width: distance,
        color: Theme.of(context).colorScheme.outlineVariant,
      );
    }

    // 根据关系类型返回不同颜色和粗细
    final color = _getRelationshipColor(context, relationship.relationshipType);
    final thickness = _getRelationshipThickness(relationship.relationshipType);

    return Container(
      height: thickness,
      width: distance,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.6),
            color,
            color.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  /// 显示节点详情
  void _showNodeDetails(Character character, int degree) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.person,
              color: _getGenderColor(context, character.gender),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                character.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_avatarProviders.containsKey(character.id))
                Center(
                  child: ClipOval(
                    child: Image(
                      image: _avatarProviders[character.id]!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildDetailRow('关系数量', '$degree 个'),
              if (character.gender != null && character.gender!.isNotEmpty)
                _buildDetailRow('性别', character.gender!),
              if (character.age != null)
                _buildDetailRow('年龄', '${character.age} 岁'),
              if (character.appearanceFeatures != null &&
                  character.appearanceFeatures!.isNotEmpty)
                _buildDetailRow('外貌特征', character.appearanceFeatures!),
              if (character.personality != null &&
                  character.personality!.isNotEmpty)
                _buildDetailRow('性格', character.personality!),
              if (character.backgroundStory != null &&
                  character.backgroundStory!.isNotEmpty)
                _buildDetailRow('背景故事', character.backgroundStory!,
                    maxLines: 3),
            ],
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

  /// 构建详情行
  Widget _buildDetailRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.87),
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 获取性别颜色
  Color _getGenderColor(BuildContext context, String? gender) {
    switch (gender?.toLowerCase()) {
      case '男':
        return context.appColors.graphGenderMale;
      case '女':
        return context.appColors.graphGenderFemale;
      default:
        return context.appColors.graphGenderUnknown;
    }
  }

  /// 获取关系类型颜色
  Color _getRelationshipColor(BuildContext context, String relationshipType) {
    switch (relationshipType) {
      case '亲密关系':
        return context.appColors.graphRelationIntimate;
      case '家庭':
        return context.appColors.graphRelationFamily;
      case '恋人':
        return context.appColors.graphRelationLover;
      case '朋友':
        return context.appColors.graphRelationFriend;
      case '敌对':
        return context.appColors.graphRelationHostile;
      case '竞争对手':
        return context.appColors.graphRelationRival;
      case '同事':
        return context.appColors.graphRelationColleague;
      case '师徒':
        return context.appColors.graphRelationMaster;
      case '盟友':
        return context.appColors.graphRelationAlly;
      default:
        return context.appColors.graphRelationDefault;
    }
  }

  /// 获取关系类型线条粗细
  double _getRelationshipThickness(String relationshipType) {
    switch (relationshipType) {
      case '亲密关系':
        return 4.0;
      case '恋人':
        return 3.5;
      case '家庭':
        return 3.0;
      case '师徒':
        return 2.5;
      default:
        return 2.0;
    }
  }
}
