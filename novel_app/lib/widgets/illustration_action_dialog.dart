import 'package:flutter/material.dart';

/// 插图功能选择对话框
/// 让用户选择【再来几张】或【生成视频】
class IllustrationActionDialog extends StatelessWidget {
  const IllustrationActionDialog({super.key});

  /// 显示对话框并返回用户选择的操作类型
  /// 返回值：
  /// - 'regenerate': 再来几张
  /// - 'video': 生成视频
  /// - null: 用户取消
  static Future<String?> show(BuildContext context) async {
    return await showDialog<String?>(
      context: context,
      barrierDismissible: true, // 允许点击空白区域关闭
      builder: (context) => const IllustrationActionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 24,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                const Text(
                  '请选择操作',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 功能选项
            Column(
              children: [
                // 再来几张
                _ActionCard(
                  icon: Icons.add_photo_alternate,
                  title: '再来几张',
                  description: '基于当前内容生成更多图片',
                  color: Colors.blue,
                  onTap: () => Navigator.of(context).pop('regenerate'),
                ),

                const SizedBox(height: 12),

                // 生成视频
                _ActionCard(
                  icon: Icons.videocam,
                  title: '生成视频',
                  description: '将图片转换为动态视频',
                  color: Colors.purple,
                  onTap: () => Navigator.of(context).pop('video'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 取消按钮
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  '取消',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 功能选项卡片
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // 文字说明
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 箭头图标
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
