import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character.dart';
import '../core/providers/database_providers.dart';

class CharacterSelector extends ConsumerStatefulWidget {
  final String novelUrl;
  final List<int> initialSelectedIds;
  final Function(List<int>) onSelectionChanged;

  const CharacterSelector({
    super.key,
    required this.novelUrl,
    this.initialSelectedIds = const [],
    required this.onSelectionChanged,
  });

  @override
  ConsumerState<CharacterSelector> createState() => _CharacterSelectorState();
}

class _CharacterSelectorState extends ConsumerState<CharacterSelector> {
  List<Character> _characters = [];
  Set<int> _selectedIds = {};
  List<Character> _filteredCharacters = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    _loadCharacters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCharacters() async {
    final databaseService = ref.read(databaseServiceProvider);
    try {
      final characters = await databaseService.getCharacters(widget.novelUrl);
      if (mounted) {
        setState(() {
          _characters = characters;
          _filteredCharacters = characters;
        });
      }
    } catch (e) {
      // 错误处理
    }
  }

  void _filterCharacters(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCharacters = _characters;
      } else {
        _filteredCharacters = _characters.where((character) {
          return character.name.toLowerCase().contains(query.toLowerCase()) ||
              (character.occupation
                      ?.toLowerCase()
                      .contains(query.toLowerCase()) ??
                  false) ||
              (character.personality
                      ?.toLowerCase()
                      .contains(query.toLowerCase()) ??
                  false);
        }).toList();
      }
    });
  }

  void _toggleSelection(int characterId) {
    setState(() {
      if (_selectedIds.contains(characterId)) {
        _selectedIds.remove(characterId);
      } else {
        _selectedIds.add(characterId);
      }
    });
    widget.onSelectionChanged(_selectedIds.toList());
  }

  String _getSelectedNames() {
    final selectedCharacters =
        _characters.where((c) => _selectedIds.contains(c.id ?? 0)).toList();

    if (selectedCharacters.isEmpty) return '点击选择出场人物';
    return '已选择${selectedCharacters.length}人: ${selectedCharacters.map((c) => _getSafeCharacterName(c.name)).join(', ')}';
  }

  /// 安全获取角色名称，防止空字符串或异常
  String _getSafeCharacterName(String name) {
    if (name.isEmpty) return '未命名角色';
    return name;
  }

  /// 安全获取头像文字，防止数组越界
  String _getAvatarText(String name) {
    if (name.isEmpty) return '?';
    return name[0];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 点击选择区域
        InkWell(
          onTap: _showCharacterSelectionDialog,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(Icons.people,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getSelectedNames(),
                    style: TextStyle(
                      color: _selectedIds.isEmpty
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCharacterSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择出场人物'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // 搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索人物姓名、职业或性格...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    _filterCharacters(value);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 16),

                // 人物列表
                Expanded(
                  child: _filteredCharacters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? '未找到匹配的人物'
                                    : '还没有创建人物',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredCharacters.length,
                          itemBuilder: (context, index) {
                            final character = _filteredCharacters[index];
                            final isSelected =
                                _selectedIds.contains(character.id ?? 0);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                if (value == true && character.id != null) {
                                  _toggleSelection(character.id!);
                                } else if (character.id != null) {
                                  _toggleSelection(character.id!);
                                }
                                setDialogState(() {});
                              },
                              title: Text(
                                character.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (character.occupation != null)
                                    Text(
                                      character.occupation!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      if (character.age != null)
                                        Text(
                                          '${character.age}岁',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                            fontSize: 11,
                                          ),
                                        ),
                                      if (character.age != null &&
                                          character.gender != null)
                                        const SizedBox(width: 8),
                                      if (character.gender != null)
                                        Text(
                                          character.gender!,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              secondary: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    _getGenderColor(character.gender),
                                child: Text(
                                  _getAvatarText(character.name),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGenderColor(String? gender) {
    switch (gender?.toLowerCase()) {
      case '男':
        return Theme.of(context).colorScheme.primary;
      case '女':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.tertiary;
    }
  }
}
