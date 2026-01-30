import 'package:flutter/material.dart';
import '../../models/outline.dart';
import '../../models/novel.dart';
import '../../services/outline_service.dart';
import '../../services/database_service.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/common/common_widgets.dart';
import 'create_outline_screen.dart';

/// 大纲管理页面
/// 显示小说的大纲，支持创建、查看、编辑、删除大纲
class OutlineManagementScreen extends StatefulWidget {
  final String novelUrl;
  final String novelTitle;

  const OutlineManagementScreen({
    super.key,
    required this.novelUrl,
    required this.novelTitle,
  });

  @override
  State<OutlineManagementScreen> createState() =>
      _OutlineManagementScreenState();
}

class _OutlineManagementScreenState extends State<OutlineManagementScreen> {
  final OutlineService _outlineService = OutlineService();
  final DatabaseService _databaseService = DatabaseService();
  Outline? _outline;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOutline();
  }

  /// 加载大纲
  Future<void> _loadOutline() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final outline = await _outlineService.getOutline(widget.novelUrl);
      setState(() {
        _outline = outline;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 导航到创建大纲页面
  Future<void> _navigateToCreateOutline() async {
    // 获取小说背景设定
    String? backgroundSetting;
    try {
      final bookshelf = await _databaseService.getBookshelf();
      final novel = bookshelf.firstWhere(
        (n) => n.url == widget.novelUrl,
        orElse: () => Novel(
          title: widget.novelTitle,
          author: '',
          url: widget.novelUrl,
        ),
      );
      backgroundSetting = novel.backgroundSetting;
    } catch (e) {
      debugPrint('获取小说背景设定失败: $e');
    }

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOutlineScreen(
          novelUrl: widget.novelUrl,
          novelTitle: widget.novelTitle,
          backgroundSetting: backgroundSetting,
        ),
      ),
    );

    // 如果创建了大纲，重新加载
    if (result == true) {
      _loadOutline();
    }
  }

  /// 导航到编辑大纲页面
  Future<void> _navigateToEditOutline() async {
    if (_outline == null) return;

    // 获取小说背景设定
    String? backgroundSetting;
    try {
      final bookshelf = await _databaseService.getBookshelf();
      final novel = bookshelf.firstWhere(
        (n) => n.url == widget.novelUrl,
        orElse: () => Novel(
          title: widget.novelTitle,
          author: '',
          url: widget.novelUrl,
        ),
      );
      backgroundSetting = novel.backgroundSetting;
    } catch (e) {
      debugPrint('获取小说背景设定失败: $e');
    }

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOutlineScreen(
          novelUrl: widget.novelUrl,
          novelTitle: widget.novelTitle,
          backgroundSetting: backgroundSetting,
          existingOutline: _outline,
        ),
      ),
    );

    // 如果编辑了大纲，重新加载
    if (result == true) {
      _loadOutline();
    }
  }

  /// 确认删除大纲
  Future<void> _confirmDeleteOutline() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '确认删除',
      message: '确定要删除这个大纲吗？此操作不可撤销。',
      confirmText: '删除',
      icon: Icons.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed == true && mounted) {
      try {
        await _outlineService.deleteOutline(widget.novelUrl);
        setState(() {
          _outline = null;
        });
        if (mounted) {
          ToastUtils.showSuccess('大纲已删除');
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showError('删除失败: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大纲管理'),
        actions: [
          if (_outline != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '编辑大纲',
              onPressed: _navigateToEditOutline,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除大纲',
              onPressed: _confirmDeleteOutline,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFB00020),
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOutline,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_outline == null) {
      return _buildNoOutlineView();
    }

    return _buildOutlineView();
  }

  /// 无大纲时的视图
  Widget _buildNoOutlineView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 100,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无大纲',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '创建大纲后，您可以：\n'
              '• 按照大纲快速生成章节\n'
              '• 保持故事连贯性和结构完整\n'
              '• 更好地规划故事发展',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('创建大纲'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              onPressed: _navigateToCreateOutline,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示大纲的视图
  Widget _buildOutlineView() {
    return Column(
      children: [
        // 大纲内容
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 大纲标题
                Text(
                  _outline!.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                // 更新时间
                Text(
                  '最后更新: ${_formatDate(_outline!.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                // 大纲内容（简单显示，不支持Markdown）
                Text(
                  _outline!.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
