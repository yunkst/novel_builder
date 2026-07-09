import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/database_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/novel.dart';
import '../models/outline.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import '../utils/toast_utils.dart';
import '../widgets/common/common_widgets.dart';

/// 大纲展示 / 编辑页
///
/// 一本书对应一份大纲（[Outline]）。参照 [BackgroundSettingScreen]：
/// 编辑 / 预览双 Tab、Markdown 渲染、防抖 2 秒自动保存、放弃修改二次确认。
///
/// 与背景设定的区别：
/// - 数据来自 `OutlineRepository.getOutlineByNovelUrl`，可能返回 null（尚无大纲）；
/// - 大纲含 [Outline.title] 与 [Outline.content] 两个字段；
/// - 保存用 `saveOutline`（upsert，存在则更新，不存在则新建）。
class OutlineScreen extends ConsumerStatefulWidget {
  final Novel novel;

  const OutlineScreen({required this.novel, super.key});

  @override
  ConsumerState<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends ConsumerState<OutlineScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _originalTitle = '';
  String _originalContent = '';
  bool _isSaving = false;
  bool _isModified = false;
  bool _isLoading = true;
  Timer? _autoSaveTimer;
  int _currentTabIndex = 0; // 0=编辑, 1=预览

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
    _loadOutline();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ─── 数据加载 ───────────────────────────────────────────────

  Future<void> _loadOutline() async {
    try {
      final repo = ref.read(outlineRepositoryProvider);
      final outline = await repo.getOutlineByNovelUrl(widget.novel.url);
      if (!mounted) return;
      setState(() {
        _titleController.text = outline?.title ?? '';
        _contentController.text = outline?.content ?? '';
        _originalTitle = _titleController.text;
        _originalContent = _contentController.text;
        _isModified = false;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '加载大纲失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['outline', 'load', 'failed'],
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── 文本变化 & 自动保存 ────────────────────────────────────

  void _onTextChanged() {
    final wasModified = _isModified;
    _isModified = _titleController.text != _originalTitle ||
        _contentController.text != _originalContent;
    if (wasModified != _isModified) {
      setState(() {});
    }
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_isModified && mounted) {
        _save(auto: true);
      }
    });
  }

  Future<void> _save({bool auto = false}) async {
    if (_isSaving) return;
    _autoSaveTimer?.cancel();
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim().isEmpty
          ? widget.novel.title // 未填标题时以书名为默认
          : _titleController.text.trim();
      final content = _contentController.text;

      final repo = ref.read(outlineRepositoryProvider);
      await repo.saveOutline(Outline(
        novelUrl: widget.novel.url,
        title: title,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      if (!mounted) return;
      setState(() {
        _originalTitle = _titleController.text;
        _originalContent = _contentController.text;
        _isModified = false;
      });
      if (auto) {
        ToastUtils.showInfo('已自动保存');
      } else {
        ToastUtils.showSuccess('大纲已保存');
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      if (auto) {
        LoggerService.instance.w(
          '大纲自动保存失败',
          stackTrace: stackTrace.toString(),
          category: LogCategory.database,
          tags: ['outline', 'auto-save', 'failed'],
        );
      } else {
        ErrorHelper.showErrorWithLog(
          context,
          '保存失败',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.database,
          tags: ['outline', 'save', 'failed'],
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_isModified) return true;
    final result = await ConfirmDialog.show(
      context,
      title: '放弃修改？',
      message: '您有未保存的修改，确定要放弃吗？',
      confirmText: '放弃修改',
      cancelText: '继续编辑',
      confirmColor: context.appColors.error,
    );
    return result ?? false;
  }

  Future<void> _onTabChanged(int index) async {
    // 从编辑切到预览时，若有改动先自动保存
    if (_currentTabIndex == 0 && index == 1 && _isModified) {
      await _save(auto: true);
    }
    setState(() => _currentTabIndex = index);
  }

  // ─── 构建 ───────────────────────────────────────────────────

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
                Text(
                  '大纲',
                  style: AppTypography.chapterTitle.copyWith(fontSize: 18),
                ),
                Text(
                  widget.novel.title,
                  style: AppTypography.metaItalic.copyWith(
                    fontSize: 12,
                    color: context.appColors.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
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
                onPressed: (_isSaving || !_isModified) ? null : () => _save(),
                tooltip: '保存',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(text: '编辑', icon: Icon(Icons.edit)),
                          Tab(text: '预览', icon: Icon(Icons.preview)),
                        ],
                        labelColor: Theme.of(context).colorScheme.primary,
                        onTap: _onTabChanged,
                      ),
                      const SizedBox(height: 8),
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

  Widget _buildEditMode() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '大纲标题',
            hintText: '可选，留空则使用书名',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _contentController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '在此输入大纲内容（支持 Markdown 格式）...',
              contentPadding: const EdgeInsets.all(16),
              counterText: '${_contentController.text.length} 字符',
            ),
            style: AppTypography.bodyProse.copyWith(
              fontSize: 16,
              height: 1.5,
              color: context.appColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: context.appColors.inkSoft,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _isModified ? '内容已修改，2 秒后自动保存或点击右上角保存' : '点击右上角保存按钮保存修改',
                style: AppTypography.metaItalic.copyWith(
                  color: _isModified
                      ? context.appColors.warning
                      : context.appColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewMode() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      final hasTitle = _titleController.text.trim().isNotEmpty;
      return Center(
        child: Text(
          hasTitle ? '暂无大纲内容' : '暂无大纲，可在「编辑」页创建',
          style: AppTypography.bodyProse.copyWith(
            fontSize: 16,
            color: context.appColors.inkSoft,
          ),
        ),
      );
    }

    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        p: AppTypography.bodyProse.copyWith(
          fontSize: 15,
          color: context.appColors.ink,
        ),
        h1: AppTypography.chapterTitle.copyWith(
          fontSize: 22,
          color: context.appColors.ink,
        ),
        h2: AppTypography.chapterTitle.copyWith(
          fontSize: 19,
          color: context.appColors.ink,
        ),
        h3: AppTypography.novelTitle.copyWith(
          fontSize: 17,
          color: context.appColors.ink,
        ),
        h4: AppTypography.novelTitle.copyWith(
          fontSize: 15,
          color: context.appColors.ink,
        ),
        strong: AppTypography.bodyProse.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: context.appColors.ink,
        ),
        em: AppTypography.bodyProse.copyWith(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: context.appColors.ink,
        ),
        listBullet: AppTypography.bodyProse.copyWith(
          fontSize: 15,
          color: context.appColors.inkSoft,
        ),
        code: AppTypography.bodyProse.copyWith(
          fontSize: 13,
          fontFamily: 'monospace',
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: AppTypography.bodyProse.copyWith(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: context.appColors.inkSoft,
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
              color: context.appColors.divider,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
