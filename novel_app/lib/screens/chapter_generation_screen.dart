import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../widgets/common/common_widgets.dart';

/// 章节生成全屏页面
///
/// 功能:
/// - 全屏展示AI生成的小说内容
/// - 实时流式显示生成内容
/// - 提供取消/重试/插入三个操作按钮
class ChapterGenerationScreen extends StatefulWidget {
  final String title;
  final ValueNotifier<String> generatedContentNotifier;
  final ValueNotifier<bool> isGeneratingNotifier;

  const ChapterGenerationScreen({
    super.key,
    required this.title,
    required this.generatedContentNotifier,
    required this.isGeneratingNotifier,
  });

  /// 显示生成页面并返回用户选择的操作结果
  /// 返回值：
  /// - null: 用户取消
  /// - false: 用户选择重试
  /// - true: 用户选择插入
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required ValueNotifier<String> generatedContentNotifier,
    required ValueNotifier<bool> isGeneratingNotifier,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterGenerationScreen(
          title: title,
          generatedContentNotifier: generatedContentNotifier,
          isGeneratingNotifier: isGeneratingNotifier,
        ),
      ),
    );
  }

  @override
  State<ChapterGenerationScreen> createState() => _ChapterGenerationScreenState();
}

class _ChapterGenerationScreenState extends State<ChapterGenerationScreen> {
  late final ScrollController _scrollController;
  bool _userScrolled = false; // 用户是否手动滚动过

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // 监听内容变化,自动滚动到底部
    widget.generatedContentNotifier.addListener(_onContentChanged);

    // 监听用户手动滚动
    _scrollController.addListener(_onUserScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.generatedContentNotifier.removeListener(_onContentChanged);
    _scrollController.removeListener(_onUserScroll);
    super.dispose();
  }

  /// 内容变化时的回调
  void _onContentChanged() {
    // 仅在生成中且用户未手动滚动时自动滚动
    if (widget.isGeneratingNotifier.value && !_userScrolled) {
      _autoScrollToBottom();
    }
  }

  /// 用户手动滚动的回调
  void _onUserScroll() {
    // 如果用户向上滚动,则暂停自动滚动
    if (_scrollController.position.userScrollDirection != ScrollDirection.forward) {
      setState(() {
        _userScrolled = true;
      });
    }
  }

  /// 自动滚动到底部
  void _autoScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 取消操作
  void _handleCancel() {
    Navigator.pop(context, null);
  }

  /// 重试操作
  void _handleRetry() {
    Navigator.pop(context, false);
  }

  /// 插入操作
  void _handleInsert() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isGeneratingNotifier.value,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && widget.isGeneratingNotifier.value) {
          final confirmed = await ConfirmDialog.show(
            context,
            title: '确认取消',
            message: '章节正在生成中,确定要取消吗?',
            confirmText: '确认取消',
            cancelText: '继续生成',
            confirmColor: Theme.of(context).colorScheme.error,
          );
          if (confirmed == true && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (widget.isGeneratingNotifier.value) {
                // 生成中,显示确认对话框
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: '确认取消',
                  message: '章节正在生成中,确定要取消吗?',
                  confirmText: '确认取消',
                  cancelText: '继续生成',
                  confirmColor: Theme.of(context).colorScheme.error,
                );
                if (confirmed == true && context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                // 非生成中,直接返回
                Navigator.pop(context);
              }
            },
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: Theme.of(context).colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _handleCancel,
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 内容显示区域
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: widget.generatedContentNotifier,
                builder: (context, content, child) {
                  if (content.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            '正在生成中...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // 生成中提示条
                      if (widget.isGeneratingNotifier.value)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '正在生成中...',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 内容显示区域
                      Expanded(
                        child: Container(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 章节标题
                                    Text(
                                      widget.title,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const Divider(
                                      height: 32,
                                      color: Color(0xFF616161),
                                    ),

                                    // 章节内容
                                    SelectableText(
                                      content,
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.8,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 自动滚动提示
                      if (_userScrolled && widget.isGeneratingNotifier.value)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.9),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '已暂停自动滚动,内容仍在生成中',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _userScrolled = false;
                                  });
                                  _autoScrollToBottom();
                                },
                                child: Text(
                                  '恢复滚动',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // 底部操作栏
            ValueListenableBuilder<bool>(
              valueListenable: widget.isGeneratingNotifier,
              builder: (context, isGenerating, child) {
                return ValueListenableBuilder<String>(
                  valueListenable: widget.generatedContentNotifier,
                  builder: (context, content, child) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            // 取消按钮
                            TextButton(
                              onPressed: _handleCancel,
                              child: Text(
                                '取消',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.74)),
                              ),
                            ),

                            const Spacer(),

                            // 重试按钮
                            TextButton.icon(
                              onPressed: isGenerating ? null : _handleRetry,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(
                                isGenerating ? '生成中' : '重试',
                                style: TextStyle(
                                  color: isGenerating
                                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.457)
                                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.71),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // 插入按钮
                            ElevatedButton.icon(
                              onPressed:
                                  (isGenerating || content.isEmpty) ? null : _handleInsert,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('插入'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
