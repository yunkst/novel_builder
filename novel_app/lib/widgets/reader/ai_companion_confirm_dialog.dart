import 'package:flutter/material.dart';
import '../../models/ai_companion_response.dart';

/// AI伴读确认对话框
///
/// 展示AI伴读分析结果，包括：
/// - 本章总结
/// - 新增背景设定
/// - 角色更新预览（展开卡片展示详情）
/// - 关系更新预览
class AICompanionConfirmDialog extends StatefulWidget {
  /// AI伴读响应数据
  final AICompanionResponse response;

  /// 确认回调
  final VoidCallback onConfirm;

  /// 取消回调
  final VoidCallback onCancel;

  const AICompanionConfirmDialog({
    super.key,
    required this.response,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<AICompanionConfirmDialog> createState() =>
      _AICompanionConfirmDialogState();
}

class _AICompanionConfirmDialogState extends State<AICompanionConfirmDialog> {
  /// 各部分的展开状态
  bool _summeryExpanded = true;
  bool _backgroundExpanded = true;
  bool _rolesExpanded = true;
  bool _relationsExpanded = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_stories, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AI伴读分析结果',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 本章总结
              _buildSection(
                title: '📖 本章总结',
                icon: Icons.summarize,
                isExpanded: _summeryExpanded,
                onTap: () =>
                    setState(() => _summeryExpanded = !_summeryExpanded),
                child: _buildTextContent(widget.response.summery),
              ),

              const SizedBox(height: 12),

              // 新增背景设定
              if (widget.response.background.isNotEmpty)
                _buildSection(
                  title: '🌍 新增背景设定',
                  icon: Icons.landscape,
                  isExpanded: _backgroundExpanded,
                  onTap: () => setState(
                      () => _backgroundExpanded = !_backgroundExpanded),
                  child: _buildTextContent(widget.response.background),
                ),

              if (widget.response.background.isNotEmpty)
                const SizedBox(height: 12),

              // 角色更新
              if (widget.response.roles.isNotEmpty)
                _buildSection(
                  title: '👥 角色更新 (${widget.response.roles.length})',
                  icon: Icons.people,
                  isExpanded: _rolesExpanded,
                  onTap: () => setState(() => _rolesExpanded = !_rolesExpanded),
                  child: _buildRolesList(),
                ),

              if (widget.response.roles.isNotEmpty) const SizedBox(height: 12),

              // 关系更新
              if (widget.response.relations.isNotEmpty)
                _buildSection(
                  title: '🔗 关系更新 (${widget.response.relations.length})',
                  icon: Icons.link,
                  isExpanded: _relationsExpanded,
                  onTap: () =>
                      setState(() => _relationsExpanded = !_relationsExpanded),
                  child: _buildRelationsList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: widget.onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('全部保存'),
        ),
      ],
    );
  }

  /// 构建可折叠的区块
  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏（可点击折叠）
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 内容区域
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  /// 构建文本内容（自动换行）
  Widget _buildTextContent(String text) {
    if (text.isEmpty) {
      return const Text(
        '无内容',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    return SelectableText(
      text,
      style: const TextStyle(fontSize: 14, height: 1.5),
    );
  }

  /// 构建角色列表
  Widget _buildRolesList() {
    if (widget.response.roles.isEmpty) {
      return const Text(
        '无角色更新',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.response.roles.map((role) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            title: Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    role.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (role.gender != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role.gender!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (role.age != null)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${role.age}岁',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (role.occupation != null) ...[
                      _buildInfoRow('职业', role.occupation!),
                      const SizedBox(height: 8),
                    ],
                    if (role.personality != null &&
                        role.personality!.isNotEmpty) ...[
                      _buildInfoRow('性格', role.personality!),
                      const SizedBox(height: 8),
                    ],
                    if (role.bodyType != null && role.bodyType!.isNotEmpty) ...[
                      _buildInfoRow('身材', role.bodyType!),
                      const SizedBox(height: 8),
                    ],
                    if (role.clothingStyle != null &&
                        role.clothingStyle!.isNotEmpty) ...[
                      _buildInfoRow('穿衣风格', role.clothingStyle!),
                      const SizedBox(height: 8),
                    ],
                    if (role.appearanceFeatures != null &&
                        role.appearanceFeatures!.isNotEmpty) ...[
                      _buildInfoRow('外貌特点', role.appearanceFeatures!),
                      const SizedBox(height: 8),
                    ],
                    if (role.backgroundStory != null &&
                        role.backgroundStory!.isNotEmpty)
                      _buildInfoRow('背景经历', role.backgroundStory!),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  /// 构建关系列表
  Widget _buildRelationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.response.relations.map((relation) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Source角色
                Expanded(
                  child: Text(
                    relation.source,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // 箭头和关系类型
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        relation.type,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward,
                          size: 16, color: Colors.orange),
                    ],
                  ),
                ),

                // Target角色
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    relation.target,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 显示AI伴读确认对话框
///
/// [context] 上下文
/// [response] AI伴读响应数据
///
/// 返回用户是否确认更新
Future<bool> showAICompanionConfirmDialog(
  BuildContext context,
  AICompanionResponse response,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AICompanionConfirmDialog(
          response: response,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
      ) ??
      false;
}
