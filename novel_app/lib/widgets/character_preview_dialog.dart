import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/character_update.dart';

class CharacterPreviewDialog extends StatefulWidget {
  final List<CharacterUpdate> characterUpdates;
  final Function(List<Character>) onConfirmed; // 确认保存的角色列表

  const CharacterPreviewDialog({
    super.key,
    required this.characterUpdates,
    required this.onConfirmed,
  });

  /// 显示角色预览对话框
  static Future<void> show(
    BuildContext context, {
    required List<CharacterUpdate> characterUpdates,
    required Function(List<Character>) onConfirmed,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => CharacterPreviewDialog(
        characterUpdates: characterUpdates,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<CharacterPreviewDialog> createState() => _CharacterPreviewDialogState();
}

class _CharacterPreviewDialogState extends State<CharacterPreviewDialog> {
  late List<bool> _selectedUpdates;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _selectedUpdates = List<bool>.filled(widget.characterUpdates.length, false);
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      _selectedUpdates =
          List<bool>.filled(widget.characterUpdates.length, _selectAll);
    });
  }

  void _toggleUpdate(int index) {
    setState(() {
      _selectedUpdates[index] = !_selectedUpdates[index];
      _selectAll = _selectedUpdates.every((selected) => selected);
    });
  }

  List<Character> _getSelectedCharacters() {
    final selected = <Character>[];
    for (int i = 0; i < widget.characterUpdates.length; i++) {
      if (_selectedUpdates[i]) {
        selected.add(widget.characterUpdates[i].newCharacter);
      }
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount =
        _selectedUpdates.where((selected) => selected).length;
    final newCount =
        widget.characterUpdates.where((u) => u.isNew).length;
    final updateCount =
        widget.characterUpdates.where((u) => u.isUpdate).length;

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
                const Icon(Icons.person, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI生成的角色预览',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '新增 $newCount 个, 更新 $updateCount 个',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB0B0B0), // 暗灰-适合暗黑模式
                        ),
                      ),
                    ],
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
                Text('全选 (${widget.characterUpdates.length}个角色)'),
                const Spacer(),
                Text(
                  '已选择: $selectedCount个',
                  style: TextStyle(
                    color: selectedCount > 0 ? const Color(0xFF4CAF50) : const Color(0xFFB0B0B0), // 绿色/暗灰
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 角色列表
            Expanded(
              child: widget.characterUpdates.isEmpty
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
                      itemCount: widget.characterUpdates.length,
                      itemBuilder: (context, index) {
                        final update = widget.characterUpdates[index];
                        final isSelected = _selectedUpdates[index];

                        return CharacterPreviewCard(
                          update: update,
                          isSelected: isSelected,
                          onToggle: () => _toggleUpdate(index),
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
  final CharacterUpdate update;
  final bool isSelected;
  final VoidCallback onToggle;

  const CharacterPreviewCard({
    super.key,
    required this.update,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final character = update.newCharacter;
    final diffs = update.getDifferences();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 角色基本信息行
              Row(
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
                        // 角色名称 + 状态标签
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                character.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.blue : null,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(),
                            const SizedBox(width: 8),
                            if (character.gender != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF424242), // 深灰背景
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  character.gender!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE0E0E0), // 浅灰文字
                                  ),
                                ),
                              ),
                            if (character.age != null)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3E2723), // 深棕背景
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${character.age}岁',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFFFCC80), // 浅橙文字
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // 职业
                        if (character.occupation != null)
                          Text(
                            character.occupation!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFB0BEC5), // 浅蓝灰
                            ),
                          ),

                        const SizedBox(height: 8),

                        // 详细信息(仅显示新值)
                        _buildInfoSection(
                            '外貌特征',
                            [
                              if (character.bodyType != null) character.bodyType!,
                              if (character.appearanceFeatures != null)
                                character.appearanceFeatures!,
                              if (character.clothingStyle != null)
                                character.clothingStyle!,
                            ]
                                .where((text) => text.isNotEmpty)
                                .toList()),

                        const SizedBox(height: 4),

                        _buildInfoSection(
                            '性格特点',
                            [
                              if (character.personality != null)
                                character.personality!,
                            ].where((text) => text.isNotEmpty).toList()),

                        const SizedBox(height: 4),

                        _buildInfoSection(
                            '背景故事',
                            [
                              if (character.backgroundStory != null)
                                character.backgroundStory!,
                            ].where((text) => text.isNotEmpty).toList()),
                      ],
                    ),
                  ),
                ],
              ),

              // 差异对比区(仅更新角色且有差异时显示)
              if (update.isUpdate && diffs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF424242)), // 深灰分割线
                ExpansionTile(
                  title: Text(
                    '查看变更 (${diffs.length}项)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64B5F6), // 浅蓝
                    ),
                  ),
                  childrenPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: diffs.map((diff) => _buildDiffField(diff)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (update.isNew) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '新增',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '更新',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    }
  }

  Widget _buildDiffField(FieldDiff diff) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C), // 深灰背景-适合暗黑模式
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '${diff.label}:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE0E0E0), // 浅灰文字
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diff.oldValue != null) ...[
                  Row(
                    children: [
                      const Text(
                        '旧: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF9800), // 橙色
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          diff.oldValue!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF909090), // 中灰文字
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFFFF9800), // 橙色删除线
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (diff.newValue != null)
                  Row(
                    children: [
                      const Text(
                        '新: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF69F0AE), // 绿色
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          diff.newValue!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF69F0AE), // 绿色粗体
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Text(
                        '新: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF5350), // 红色
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '已删除',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFEF5350), // 红色粗体
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
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
            color: Color(0xFF9E9E9E), // 浅灰标题
          ),
        ),
        const SizedBox(height: 2),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFE0E0E0), // 浅灰文字
                ),
              ),
            )),
      ],
    );
  }
}
