import 'package:flutter/material.dart';
import '../models/tag_group.dart';

/// 已选标签展示组件（按分组展示）
class SelectedTagsView extends StatelessWidget {
  final List<TagGroup> groups;
  final ValueChanged<TagGroup> onRemove;

  const SelectedTagsView({
    super.key,
    required this.groups,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: groups.map((g) {
            return Chip(
              label: Text(
                g.count > 1 ? '${g.name} ×${g.count}' : g.name,
                style: const TextStyle(fontSize: 12),
              ),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => onRemove(g),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ),
    );
  }
}
