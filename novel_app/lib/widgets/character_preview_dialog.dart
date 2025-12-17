import 'package:flutter/material.dart';
import '../models/character.dart';

class CharacterPreviewDialog extends StatefulWidget {
  final List<Character> characters;
  final Function(List<Character>) onConfirmed; // 确认保存的角色列表

  const CharacterPreviewDialog({
    super.key,
    required this.characters,
    required this.onConfirmed,
  });

  /// 显示角色预览对话框
  static Future<void> show(
    BuildContext context, {
    required List<Character> characters,
    required Function(List<Character>) onConfirmed,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => CharacterPreviewDialog(
        characters: characters,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<CharacterPreviewDialog> createState() => _CharacterPreviewDialogState();
}

class _CharacterPreviewDialogState extends State<CharacterPreviewDialog> {
  late List<bool> _selectedCharacters;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _selectedCharacters = List<bool>.filled(widget.characters.length, false);
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      _selectedCharacters = List<bool>.filled(widget.characters.length, _selectAll);
    });
  }

  void _toggleCharacter(int index) {
    setState(() {
      _selectedCharacters[index] = !_selectedCharacters[index];
      _selectAll = _selectedCharacters.every((selected) => selected);
    });
  }

  List<Character> _getSelectedCharacters() {
    final selected = <Character>[];
    for (int i = 0; i < widget.characters.length; i++) {
      if (_selectedCharacters[i]) {
        selected.add(widget.characters[i]);
      }
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedCharacters.where((selected) => selected).length;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI生成的角色预览',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 全选操作栏
            Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: (value) => _toggleSelectAll(),
                ),
                Text('全选 (${widget.characters.length}个角色)'),
                const Spacer(),
                Text(
                  '已选择: $selectedCount个',
                  style: TextStyle(
                    color: selectedCount > 0 ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 角色列表
            Expanded(
              child: widget.characters.isEmpty
                  ? const Center(
                      child: Text(
                        'AI未生成任何角色',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.characters.length,
                      itemBuilder: (context, index) {
                        final character = widget.characters[index];
                        final isSelected = _selectedCharacters[index];

                        return CharacterPreviewCard(
                          character: character,
                          isSelected: isSelected,
                          onToggle: () => _toggleCharacter(index),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const Spacer(),
                if (selectedCount > 0)
                  ElevatedButton(
                    onPressed: () {
                      final selectedCharacters = _getSelectedCharacters();
                      widget.onConfirmed(selectedCharacters);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('保存选中的$selectedCount个角色'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CharacterPreviewCard extends StatelessWidget {
  final Character character;
  final bool isSelected;
  final VoidCallback onToggle;

  const CharacterPreviewCard({
    super.key,
    required this.character,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 选择框
              Checkbox(
                value: isSelected,
                onChanged: (value) => onToggle(),
              ),
              const SizedBox(width: 12),

              // 角色信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 角色名称
                    Row(
                      children: [
                        Text(
                          character.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.blue : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (character.gender != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              character.gender!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        if (character.age != null)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${character.age}岁',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 职业
                    if (character.occupation != null)
                      Text(
                        character.occupation!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // 详细信息
                    _buildInfoSection('外貌特征', [
                      if (character.bodyType != null) character.bodyType!,
                      if (character.appearanceFeatures != null) character.appearanceFeatures!,
                      if (character.clothingStyle != null) character.clothingStyle!,
                    ].where((text) => text.isNotEmpty).toList()),

                    const SizedBox(height: 4),

                    _buildInfoSection('性格特点', [
                      if (character.personality != null) character.personality!,
                    ].where((text) => text.isNotEmpty).toList()),

                    const SizedBox(height: 4),

                    _buildInfoSection('背景故事', [
                      if (character.backgroundStory != null) character.backgroundStory!,
                    ].where((text) => text.isNotEmpty).toList()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            item,
            style: const TextStyle(fontSize: 13),
          ),
        )),
      ],
    );
  }
}