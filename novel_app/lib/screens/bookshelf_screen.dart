import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/toast_utils.dart';
import '../models/novel.dart';
import '../models/bookshelf.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import '../widgets/bookshelf_selector.dart';
import '../widgets/common/common_widgets.dart';
import '../widgets/empty_states/empty_bookshelf.dart';
import '../widgets/novel/novel_cover.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../screens/chapter_list_screen_riverpod.dart';
import '../screens/reader_screen.dart';
import '../core/providers/bookshelf_providers.dart';
import '../core/providers/database_providers.dart';
import '../core/providers/service_providers.dart';
import '../dialogs/novel_edit_dialog.dart';

class BookshelfScreen extends ConsumerStatefulWidget {
  const BookshelfScreen({super.key});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  /// 书架切换回调
  void _onBookshelfChanged(int bookshelfId) {
    ref.read(currentBookshelfIdProvider.notifier).setBookshelfId(bookshelfId);
  }

  Future<void> _removeFromBookshelf(Novel novel) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '确认删除',
      message: '确定要从书架移除《${novel.title}》吗？',
      confirmText: '删除',
    );

    if (confirmed == true) {
      try {
        // 从数据库中删除小说（这会删除bookshelf表中的记录）
        final novelRepository = ref.read(novelRepositoryProvider);
        await novelRepository.removeFromBookshelf(novel.url);
        if (mounted) {
          ToastUtils.showSuccess('已从书架移除', context: context);
        }
        // 刷新书架列表
        ref.invalidate(bookshelfNovelsProvider);
      } catch (e, stackTrace) {
        if (!mounted) return;
        ErrorHelper.showErrorWithLog(
          context,
          '从书架移除失败',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.database,
          tags: ['bookshelf', 'remove', 'failed'],
        );
      }
    }
  }

  /// 编辑小说书名
  Future<void> _editNovelTitle(Novel novel) async {
    await NovelEditDialog.show(
      context: context,
      originalTitle: novel.title,
      onConfirm: (newTitle) async {
        try {
          final novelRepository = ref.read(novelRepositoryProvider);
          await novelRepository.updateTitle(novel.url, newTitle);
          if (mounted) {
            ToastUtils.showSuccess('书名修改成功', context: context);
          }
          // 刷新书架列表
          ref.invalidate(bookshelfNovelsProvider);
        } catch (e, stackTrace) {
          if (!mounted) return;
          ErrorHelper.showErrorWithLog(
            context,
            '修改书名失败',
            error: e,
            stackTrace: stackTrace,
            category: LogCategory.database,
            tags: ['bookshelf', 'edit_title', 'failed'],
          );
        }
      },
    );
  }

  /// 清除小说 AI 封面（恢复默认程序化占位图）
  ///
  /// 仅当存在 AI 封面（coverMediaId 非空）时入口可见。
  /// 清空 coverMediaId 写 NULL，NovelCover 自动回退到程序化封面。
  Future<void> _clearNovelCover(Novel novel) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '清除封面',
      message: '确定要清除《${novel.title}》的封面吗？\n清除后将恢复为默认占位封面。',
      confirmText: '清除',
    );

    if (confirmed == true) {
      try {
        final novelRepository = ref.read(novelRepositoryProvider);
        await novelRepository.updateCoverMediaIdByUrl(novel.url, null);
        if (mounted) {
          ToastUtils.showSuccess('封面已清除', context: context);
        }
        // 刷新书架列表，让 NovelCover 立即回退到程序化封面
        ref.invalidate(bookshelfNovelsProvider);
      } catch (e, stackTrace) {
        if (!mounted) return;
        ErrorHelper.showErrorWithLog(
          context,
          '清除封面失败',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.database,
          tags: ['bookshelf', 'clear_cover', 'failed'],
        );
      }
    }
  }

  /// 继续阅读 - 直接打开上次阅读的章节
  ///
  /// [novel] 要阅读的小说
  Future<void> _continueReading(Novel novel) async {
    try {
      // 1. 从数据库重新查询最新的阅读进度(修复缓存问题)
      // 不使用缓存的novel.lastReadChapterIndex,而是从数据库实时查询
      final novelRepository = ref.read(novelRepositoryProvider);
      final lastChapterIndex =
          await novelRepository.getLastReadChapter(novel.url);

      if (lastChapterIndex < 0) {
        if (mounted) {
          ToastUtils.showWarning('暂无阅读记录', context: context);
        }
        return;
      }

      // 2. 使用 ChapterLoader 加载章节列表
      final chapterLoader = ref.read(chapterLoaderProvider);
      final chapters = await chapterLoader.loadChapters(novel.url);

      // 3. 检查章节列表
      if (chapters.isEmpty) {
        if (mounted) {
          ToastUtils.showWarning('章节列表为空', context: context);
        }
        return;
      }

      // 4. 验证索引是否越界
      if (lastChapterIndex >= chapters.length) {
        if (mounted) {
          ToastUtils.showWarning(
            '上次阅读的章节不存在，已跳转到第一章',
            context: context,
          );
        }
        // 跳转到第一章
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(
                novel: novel,
                chapter: chapters.first,
                chapters: chapters,
              ),
            ),
          );
        }
        return;
      }

      // 5. 直接打开阅读器
      final targetChapter = chapters[lastChapterIndex];
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(
              novel: novel,
              chapter: targetChapter,
              chapters: chapters,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '打开章节失败',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.ui,
        tags: ['bookshelf', 'continue_reading', 'failed'],
      );
    }
  }

  /// 显示书架选择对话框
  ///
  /// [novel] 要操作的小说
  /// [mode] 操作模式：'move' 或 'copy'
  Future<void> _showBookshelfSelectionDialog(
    Novel novel,
    String mode,
  ) async {
    // 使用Repository获取书架列表
    final bookshelfRepository = ref.read(bookshelfRepositoryProvider);
    final bookshelves = await bookshelfRepository.getBookshelves();

    // 获取当前书架ID
    final currentBookshelfId = ref.read(currentBookshelfIdProvider);

    // 过滤掉当前书架和"全部小说"书架
    final availableBookshelves = bookshelves
        .where((b) => b.id != currentBookshelfId && b.id != 1)
        .toList();

    if (availableBookshelves.isEmpty) {
      if (mounted) {
        ToastUtils.showWarning('没有可用的目标书架', context: context);
      }
      return;
    }

    if (!mounted) return;

    final selectedBookshelf = await showDialog<Bookshelf>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              mode == 'move' ? Icons.drive_file_move_outline : Icons.copy,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(mode == 'move' ? '移动到书架' : '复制到书架'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableBookshelves.length,
            itemBuilder: (context, index) {
              final bookshelf = availableBookshelves[index];
              return ListTile(
                leading: Icon(
                  bookshelf.isSystem ? Icons.folder_shared : Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(bookshelf.name),
                subtitle: Text(bookshelf.isSystem ? '系统书架' : '自定义书架'),
                onTap: () => Navigator.pop(context, bookshelf),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedBookshelf != null && mounted) {
      if (mode == 'move') {
        await _moveNovelToBookshelf(novel, selectedBookshelf.id);
      } else {
        await _copyNovelToBookshelf(novel, selectedBookshelf.id);
      }
    }
  }

  /// 移动小说到指定书架
  Future<void> _moveNovelToBookshelf(Novel novel, int toBookshelfId) async {
    try {
      // 获取当前书架ID和Repository
      final currentBookshelfId = ref.read(currentBookshelfIdProvider);
      final bookshelfRepository = ref.read(bookshelfRepositoryProvider);

      // 使用Repository移动小说
      await bookshelfRepository.moveNovelToBookshelf(
        novel.url,
        currentBookshelfId,
        toBookshelfId,
      );

      if (mounted) {
        ToastUtils.showSuccess('已移动到目标书架', context: context);
        // 刷新当前书架
        ref.invalidate(bookshelfNovelsProvider);
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '移动失败',
        stackTrace: stackTrace,
        category: LogCategory.database,
        tags: ['bookshelf', 'move', 'failed'],
      );
    }
  }

  /// 复制小说到指定书架
  Future<void> _copyNovelToBookshelf(Novel novel, int toBookshelfId) async {
    try {
      // 使用Repository复制小说
      final bookshelfRepository = ref.read(bookshelfRepositoryProvider);
      await bookshelfRepository.addNovelToBookshelf(novel.url, toBookshelfId);

      if (mounted) {
        ToastUtils.showSuccess('已复制到目标书架', context: context);
        // 不刷新当前书架，因为小说还在原书架
      }
    } catch (e, stackTrace) {
      if (!mounted) return;
      ErrorHelper.showErrorWithLog(
        context,
        '复制失败',
        stackTrace: stackTrace,
        category: LogCategory.database,
        tags: ['bookshelf', 'copy', 'failed'],
      );
    }
  }

  /// 显示小说操作菜单（编辑/移动/复制/移除）
  void _showNovelMenu(Novel novel) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final colors = sheetCtx.appColors;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '《${novel.title}》',
                    style: AppTypography.novelTitle.copyWith(
                      fontSize: 16,
                      color: colors.chatPrimaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: colors.info),
                title: const Text('编辑书名'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _editNovelTitle(novel);
                },
              ),
              if (novel.coverMediaId != null && novel.coverMediaId!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.image_not_supported_outlined,
                      color: colors.warning),
                  title: const Text('清除封面'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _clearNovelCover(novel);
                  },
                ),
              ListTile(
                leading:
                    Icon(Icons.drive_file_move_outline, color: colors.warning),
                title: const Text('移动到书架'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showBookshelfSelectionDialog(novel, 'move');
                },
              ),
              ListTile(
                leading: Icon(Icons.copy_all_outlined, color: colors.success),
                title: const Text('复制到书架'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showBookshelfSelectionDialog(novel, 'copy');
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colors.error),
                title: const Text('从书架移除'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _removeFromBookshelf(novel);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBookshelfId = ref.watch(currentBookshelfIdProvider);
    final bookshelfAsync = ref.watch(bookshelfNovelsProvider);
    final cacheStats = ref.watch(bookshelfCacheStatsProvider).valueOrNull;
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '我的书架',
                    style: AppTypography.shelfTitle.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Midnight Library',
                    style: AppTypography.metaItalic.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () {
              // 搜索入口暂沿用浏览器；后续可接入书架内搜索
              ToastUtils.showInfo('在浏览器中搜索并加入书架', context: context);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 书架选择器（沿用现有组件，已自带样式）
          BookshelfSelector(
            currentBookshelfId: currentBookshelfId,
            onBookshelfChanged: _onBookshelfChanged,
          ),
          // 书架内容
          Expanded(
            child: bookshelfAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colors.error,
                    ),
                    const SizedBox(height: 16),
                    Text('加载失败: $error'),
                  ],
                ),
              ),
              data: (bookshelf) {
                if (bookshelf.isEmpty) {
                  return const EmptyBookshelfView();
                }

                final totalCached = cacheStats?.values.fold<int>(
                      0,
                      (s, v) => s + v.cached,
                    ) ??
                    0;
                final totalChapters = cacheStats?.values.fold<int>(
                      0,
                      (s, v) => s + v.total,
                    ) ??
                    0;

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(bookshelfNovelsProvider);
                    ref.invalidate(bookshelfCacheStatsProvider);
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ShelfMetaBar(
                          count: bookshelf.length,
                          cached: totalCached,
                          total: totalChapters,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.58,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final novel = bookshelf[index];
                              final stats = cacheStats?[novel.url];
                              final total = stats?.total ?? 0;
                              final cached = stats?.cached ?? 0;
                              return _NovelCard(
                                novel: novel,
                                totalChapters: total,
                                cachedChapters: cached,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChapterListScreenRiverpod(
                                        novel: novel,
                                      ),
                                    ),
                                  );
                                },
                                onContinue: () => _continueReading(novel),
                                onMenu: () => _showNovelMenu(novel),
                              );
                            },
                            childCount: bookshelf.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 书架元信息条 · 馆藏数 / 缓存进度
class _ShelfMetaBar extends StatelessWidget {
  const _ShelfMetaBar({
    required this.count,
    required this.cached,
    required this.total,
  });

  final int count;
  final int cached;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          _MetaChip(
            icon: Icons.menu_book_outlined,
            label: '馆藏',
            value: '$count',
            color: colors.agentAccent,
          ),
          const SizedBox(width: 14),
          _MetaChip(
            icon: Icons.cloud_download_outlined,
            label: '已缓存',
            value: total > 0 ? '$cached / $total' : '—',
            color: colors.success,
          ),
          const Spacer(),
          Text(
            '长按管理',
            style: AppTypography.metaItalic.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// 小说卡片 · 封面网格单元
class _NovelCard extends StatelessWidget {
  const _NovelCard({
    required this.novel,
    required this.totalChapters,
    required this.cachedChapters,
    required this.onTap,
    required this.onContinue,
    required this.onMenu,
  });

  final Novel novel;
  final int totalChapters;
  final int cachedChapters;
  final VoidCallback onTap;
  final VoidCallback onContinue;
  final VoidCallback onMenu;

  bool get _hasReadingRecord =>
      novel.lastReadChapterIndex != null && novel.lastReadChapterIndex! > 0;

  double get _readPercent {
    if (!_hasReadingRecord || totalChapters <= 0) return 0.0;
    final v = novel.lastReadChapterIndex! / totalChapters;
    if (v < 0) return 0.0;
    if (v > 1) return 1.0;
    return v;
  }

  double get _cachePercent {
    if (totalChapters <= 0) return 0.0;
    final v = cachedChapters / totalChapters;
    if (v < 0) return 0.0;
    if (v > 1) return 1.0;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isOriginal = novel.url.startsWith('custom://');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面 · 外层 InkWell 已处理 onLongPress，此处不重复绑定
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: NovelCover(
                        novel: novel,
                        isReading: _hasReadingRecord,
                        isOriginal: isOriginal,
                      ),
                    ),
                    // 右上 · 更多操作（封面内浮层固定黑白：封面恒为深色渐变，不随主题变）
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onMenu,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_horiz,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 标题
              Text(
                novel.title,
                style: AppTypography.novelTitle.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // 作者
              Text(
                novel.author,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // 双进度：阅读 + 缓存
              if (totalChapters > 0)
                _DualProgress(
                  readPercent: _readPercent,
                  cachePercent: _cachePercent,
                )
              else
                Text(
                  '未获取章节',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.chatHintText,
                    fontSize: 11,
                  ),
                ),
              // 继续阅读按钮
              if (_hasReadingRecord) ...[
                const SizedBox(height: 8),
                _ContinueButton(onPressed: onContinue),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 双进度条 · 阅读进度（琥珀）+ 缓存进度（苔绿）
class _DualProgress extends StatelessWidget {
  const _DualProgress({
    required this.readPercent,
    required this.cachePercent,
  });

  final double readPercent;
  final double cachePercent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final trackColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 阅读进度
        Row(
          children: [
            Text(
              '读',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: colors.agentAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: readPercent,
                  minHeight: 3,
                  backgroundColor: trackColor,
                  valueColor: AlwaysStoppedAnimation(colors.agentAccent),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(readPercent * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 缓存进度
        Row(
          children: [
            Text(
              '缓',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: colors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: cachePercent,
                  minHeight: 3,
                  backgroundColor: trackColor,
                  valueColor: AlwaysStoppedAnimation(colors.success),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(cachePercent * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 继续阅读按钮
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.menu_book, size: 14, color: colors.agentAccent),
        label: Text(
          '继续阅读',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.agentAccent,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          side: BorderSide(color: colors.agentAccent.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
