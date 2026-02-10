import 'package:flutter/material.dart';
import '../../models/novel.dart';
import '../../models/chapter.dart';

/// ReaderAppBar - 阅读器顶部应用栏
///
/// 职责：
/// - 显示章节标题和编辑模式状态
/// - 提供编辑模式切换
/// - 沉浸体验入口
/// - 更多功能菜单
///
/// 依赖：
/// - Novel (novel 模型)
/// - Chapter (chapter 模型)
class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Novel novel;
  final Chapter currentChapter;
  final List<Chapter> chapters;
  final bool isEditMode;
  final bool isUpdatingRoleCards;
  final VoidCallback onToggleEditMode;
  final VoidCallback onSaveAndExitEditMode;
  final VoidCallback onShowImmersiveSetup;
  final Function(String) onMenuAction;

  const ReaderAppBar({
    super.key,
    required this.novel,
    required this.currentChapter,
    required this.chapters,
    required this.isEditMode,
    required this.isUpdatingRoleCards,
    required this.onToggleEditMode,
    required this.onSaveAndExitEditMode,
    required this.onShowImmersiveSetup,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Expanded(
            child: Text(
              currentChapter.title,
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // 编辑模式状态指示器
          if (isEditMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '编辑模式',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        // 编辑模式切换按钮
        if (!isEditMode)
          IconButton(
            onPressed: onToggleEditMode,
            tooltip: '进入编辑模式',
            icon: const Icon(Icons.edit_outlined),
          ),
        // 编辑完成按钮
        if (isEditMode)
          IconButton(
            onPressed: onSaveAndExitEditMode,
            tooltip: '完成编辑并保存',
            icon: const Icon(Icons.check),
          ),
        // 沉浸体验按钮
        if (!isEditMode)
          IconButton(
            onPressed: onShowImmersiveSetup,
            tooltip: '沉浸体验',
            icon: const Icon(Icons.theater_comedy_outlined),
          ),
        // 更多功能菜单
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多功能',
          onSelected: onMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 18),
                  SizedBox(width: 12),
                  Text('刷新章节'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'scroll_speed',
              child: Row(
                children: [
                  Icon(Icons.speed, size: 18),
                  SizedBox(width: 12),
                  Text('滚动速度'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'font_size',
              child: Row(
                children: [
                  Icon(Icons.text_fields, size: 18),
                  SizedBox(width: 12),
                  Text('字体大小'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'summarize',
              child: Row(
                children: [
                  Icon(Icons.summarize, size: 18),
                  SizedBox(width: 12),
                  Text('总结'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'tts_read',
              child: Row(
                children: [
                  Icon(Icons.headphones, size: 18),
                  SizedBox(width: 12),
                  Text('朗读'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'full_rewrite',
              child: Row(
                children: [
                  Icon(Icons.auto_stories, size: 18),
                  SizedBox(width: 12),
                  Text('全文重写'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'update_character_cards',
              enabled: !isUpdatingRoleCards,
              child: Row(
                children: [
                  isUpdatingRoleCards
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.tertiary),
                          ),
                        )
                      : const Icon(Icons.person_search, size: 18),
                  const SizedBox(width: 12),
                  Text(isUpdatingRoleCards ? '更新中...' : '更新角色卡'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'ai_companion',
              child: Row(
                children: [
                  Icon(Icons.auto_stories, size: 18),
                  SizedBox(width: 12),
                  Text('AI伴读'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
