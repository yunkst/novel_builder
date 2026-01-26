import 'package:flutter/material.dart';
import '../models/character.dart';

/// 角色详情对话框
///
/// 显示角色的基础信息：姓名、性别、简介
class CharacterDetailDialog extends StatelessWidget {
  final Character character;

  const CharacterDetailDialog({
    super.key,
    required this.character,
  });

  /// 显示角色详情对话框
  static Future<void> show(
    BuildContext context,
    Character character,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => CharacterDetailDialog(character: character),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          // 角色头像（首字母）
          CircleAvatar(
            backgroundColor: _getGenderColor(character.gender),
            child: Text(
              _getCharacterInitial(character),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 角色姓名
          Expanded(
            child: Text(
              character.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 性别
          _buildInfoRow('性别', character.gender ?? '未知'),
          const SizedBox(height: 8),
          // 职业（如果有）
          if (character.occupation != null && character.occupation!.isNotEmpty) ...[
            _buildInfoRow('职业', character.occupation!),
            const SizedBox(height: 8),
          ],
          // 背景故事（如果有）
          if (character.backgroundStory != null &&
              character.backgroundStory!.isNotEmpty) ...[
            _buildInfoRow('背景', character.backgroundStory!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  /// 获取角色名称的首字母
  String _getCharacterInitial(Character character) {
    if (character.name.isNotEmpty) {
      return character.name[0].toUpperCase();
    }
    return '?';
  }

  /// 根据性别获取颜色
  Color _getGenderColor(String? gender) {
    switch (gender?.toLowerCase()) {
      case '男':
        return Colors.blue[600]!;
      case '女':
        return Colors.pink[400]!;
      default:
        return Colors.purple;
    }
  }
}
