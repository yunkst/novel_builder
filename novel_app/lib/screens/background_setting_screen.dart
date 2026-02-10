import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/novel.dart';
import '../core/providers/database_providers.dart';
import '../widgets/reader/background_summary_dialog.dart';
import '../widgets/common/common_widgets.dart';
import '../utils/toast_utils.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';

/// 背景设定独立页面 - Riverpod版本
///
/// 用于查看和编辑小说的背景设定内容，支持Markdown预览
class BackgroundSettingScreen extends ConsumerStatefulWidget {
  final Novel novel;

  const BackgroundSettingScreen({
    super.key,
    required this.novel,
  });

  @override
  ConsumerState<BackgroundSettingScreen> createState() =>
      _BackgroundSettingScreenState();
}

class _BackgroundSettingScreenState
    extends ConsumerState<BackgroundSettingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  bool _isSaving = false;
  bool _isModified = false; // 跟踪内容是否被修改
  Timer? _autoSaveTimer; // 自动保存定时器
  int _currentTabIndex = 0; // 0=编辑, 1=预览

  @override
  void initState() {
    super.initState();

    // 初始化为空，然后从数据库加载最新数据
    _controller.text = '';

    // 监听文本变化，检测修改状态
    _controller.addListener(_onTextChanged);

    // 从数据库加载最新的背景设定
    _loadBackgroundSetting();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _autoSaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 文本变化时的处理
  void _onTextChanged() {
    final currentText = _controller.text;
    final originalText = widget.novel.backgroundSetting ?? '';

    // 检测内容是否被修改
    final wasModified = _isModified;
    _isModified = currentText != originalText;

    // 如果修改状态改变，更新UI
    if (wasModified != _isModified) {
      setState(() {});
    }

    // 重置自动保存定时器
    _scheduleAutoSave();
  }

  /// 调度自动保存（防抖2秒）
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_isModified && mounted) {
        _autoSave();
      }
    });
  }

  /// 自动保存
  Future<void> _autoSave() async {
    try {
      final repository = ref.read(novelRepositoryProvider);
      await repository.updateBackgroundSetting(
        widget.novel.url,
        _controller.text.isEmpty ? null : _controller.text,
      );

      if (mounted) {
        setState(() {
          _isModified = false;
        });

        // 显示轻量级提示
        ToastUtils.showInfo('已自动保存');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.w(
        '自动保存失败',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['background-setting', 'auto-save', 'failed'],
      );
    }
  }

  /// 保存背景设定
  Future<void> _saveBackgroundSetting() async {
    if (_isSaving) return;

    // 取消自动保存定时器，避免冲突
    _autoSaveTimer?.cancel();

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(novelRepositoryProvider);
      await repository.updateBackgroundSetting(
        widget.novel.url,
        _controller.text.isEmpty ? null : _controller.text,
      );

      if (mounted) {
        setState(() {
          _isModified = false; // 重置修改状态
        });

        // 显示保存成功提示
        ToastUtils.showSuccess('背景设定已保存');
        // 返回上一页
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showErrorWithLog(
          context,
          '保存失败',
          stackTrace: stackTrace,
          category: LogCategory.database,
          tags: ['background-setting', 'save', 'failed'],
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 确认是否放弃未保存的修改
  Future<bool> _confirmDiscardChanges() async {
    if (!_isModified) return true;

    final result = await ConfirmDialog.show(
      context,
      title: '放弃修改？',
      message: '您有未保存的修改，确定要放弃吗？',
      confirmText: '放弃修改',
      cancelText: '继续编辑',
      confirmColor: Colors.red,
    );

    return result ?? false;
  }

  /// 显示总结对话框
  Future<void> _showSummaryDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => BackgroundSummaryDialog(
        novel: widget.novel,
        backgroundText: _controller.text,
      ),
    );

    // 如果已更新,重新加载数据
    if (updated == true && mounted) {
      await _reloadBackgroundSetting();
    }
  }

  /// 从数据库加载背景设定
  Future<void> _loadBackgroundSetting() async {
    try {
      final repository = ref.read(novelRepositoryProvider);
      final backgroundSetting =
          await repository.getBackgroundSetting(widget.novel.url);
      if (mounted) {
        setState(() {
          _controller.text = backgroundSetting ?? '';
          _isModified = false;
        });
      }
    } catch (e) {
      debugPrint('加载背景设定失败: $e');
      if (mounted) {
        // 如果加载失败，使用widget.novel中的值作为后备
        setState(() {
          _controller.text = widget.novel.backgroundSetting ?? '';
          _isModified = false;
        });
      }
    }
  }

  /// 重新加载背景设定（用于AI总结后刷新）
  Future<void> _reloadBackgroundSetting() async {
    await _loadBackgroundSetting();
  }

  /// Tab切换时的处理
  Future<void> _onTabChanged(int index) async {
    // 从编辑切换到预览时，触发自动保存
    if (_currentTabIndex == 0 && index == 1 && _isModified) {
      await _autoSave();
    }

    setState(() {
      _currentTabIndex = index;
    });
  }

  /// 构建编辑模式
  Widget _buildEditMode() {
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '在此输入背景设定（支持Markdown格式）...',
              contentPadding: const EdgeInsets.all(16),
              counterText: '${_controller.text.length} 字符',
            ),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
        // 底部提示
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _isModified ? '内容已修改，2秒后自动保存或点击右上角保存' : '点击右上角保存按钮保存修改',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isModified
                          ? Colors.orange
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建预览模式
  Widget _buildPreviewMode() {
    final content = _controller.text.trim();

    if (content.isEmpty) {
      return Center(
        child: Text(
          '暂无内容',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      );
    }

    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        // 使用主题颜色，自动适配暗色模式
        p: Theme.of(context).textTheme.bodyMedium,
        h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        h2: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        h3: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        h4: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
        em: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
        listBullet: Theme.of(context).textTheme.bodyMedium,
        code: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: PopScope(
        canPop: !_isModified,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;

          final shouldPop = await _confirmDiscardChanges();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('背景设定'),
                Text(
                  widget.novel.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              // 总结按钮
              IconButton(
                icon: const Icon(Icons.summarize),
                tooltip: 'AI总结',
                onPressed: _showSummaryDialog,
              ),
              // 保存按钮
              IconButton(
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    : const Icon(Icons.save),
                onPressed:
                    (_isSaving || !_isModified) ? null : _saveBackgroundSetting,
                tooltip: '保存',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TabBar
                TabBar(
                  tabs: const [
                    Tab(text: '编辑', icon: Icon(Icons.edit)),
                    Tab(text: '预览', icon: Icon(Icons.preview)),
                  ],
                  labelColor: Theme.of(context).colorScheme.primary,
                  onTap: _onTabChanged,
                ),
                const SizedBox(height: 8),
                // TabBarView
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildEditMode(),
                      _buildPreviewMode(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
