import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/toast_utils.dart';
import '../models/novel.dart';
import '../models/bookshelf.dart';
import '../services/logger_service.dart';
import '../utils/error_helper.dart';
import '../widgets/bookshelf_selector.dart';
import '../widgets/common/common_widgets.dart';
import '../screens/chapter_list_screen_riverpod.dart';
import '../screens/reader_screen.dart';
import '../core/providers/bookshelf_providers.dart';
import '../core/providers/database_providers.dart';
import '../core/providers/service_providers.dart';
import 'dart:async';

class BookshelfScreen extends ConsumerStatefulWidget {
  const BookshelfScreen({super.key});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  // 预加载监听
  StreamSubscription? _preloadSubscription;

  @override
  void initState() {
    super.initState();

    // 监听预加载进度
    final preloadService = ref.read(preloadServiceProvider);
    _preloadSubscription = preloadService.progressStream.listen((update) {
      if (mounted) {
        // 进度会通过 preloadProgressMapProvider 自动更新
        // 这里只需要确保监听器处于活动状态
      }
    });
  }

  @override
  void dispose() {
    _preloadSubscription?.cancel();
    super.dispose();
  }

  /// 判断小说是否正在预加载
  bool _isPreloading(String novelUrl) {
    final preloadService = ref.read(preloadServiceProvider);
    final stats = preloadService.getStatistics();
    return stats['is_processing'] == true &&
        stats['last_active_novel'] == novelUrl;
  }

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
        final databaseService = ref.read(databaseServiceProvider);
        await databaseService.removeFromBookshelf(novel.url);
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

  /// 继续阅读 - 直接打开上次阅读的章节
  ///
  /// [novel] 要阅读的小说
  Future<void> _continueReading(Novel novel) async {
    try {
      // 1. 验证阅读进度
      final lastChapterIndex = novel.lastReadChapterIndex;
      if (lastChapterIndex == null || lastChapterIndex < 0) {
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

  // 显示创建空小说对话框
  Future<void> _showCreateNovelDialog() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false, // 禁用空白区域点击关闭
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.create),
            SizedBox(width: 8),
            Text('创建新小说'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('创建一本属于你自己的小说，可以自由添加章节'),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '小说标题',
                hintText: '请输入小说标题',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: '作者',
                hintText: '请输入作者名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '简介 (可选)',
                hintText: '请输入小说简介',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final author = authorController.text.trim();

              if (title.isEmpty || author.isEmpty) {
                ToastUtils.showError('请填写小说标题和作者', context: context);
                return;
              }

              final Map<String, String> resultData = {
                'title': title,
                'author': author,
                'description': descriptionController.text.trim(),
              };

              // 使用微任务确保 Navigator 调用时机正确
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  Navigator.pop(context, resultData);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final databaseService = ref.read(databaseServiceProvider);
        await databaseService.createCustomNovel(
          result['title']!,
          result['author']!,
          description: result['description'],
        );
        if (mounted) {
          ToastUtils.showSuccess('小说创建成功！', context: context);
        }
        // 刷新书架列表
        ref.invalidate(bookshelfNovelsProvider);
      } catch (e) {
        if (mounted) {
          ToastUtils.showError('创建失败: $e', context: context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBookshelfId = ref.watch(currentBookshelfIdProvider);
    final bookshelfAsync = ref.watch(bookshelfNovelsProvider);
    final progress = ref.watch(preloadProgressMapProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 书架选择器
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
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('加载失败: $error'),
                  ],
                ),
              ),
              data: (bookshelf) {
                if (bookshelf.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_books,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '书架是空的',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('你可以去搜索添加小说，或点击右下角按钮创建自己的小说'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showCreateNovelDialog,
                          icon: const Icon(Icons.create),
                          label: const Text('创建新小说'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(bookshelfNovelsProvider);
                    await Future.delayed(const Duration(milliseconds: 100));
                  },
                  child: ListView.builder(
                    itemCount: bookshelf.length,
                    itemBuilder: (context, index) {
                      final novel = bookshelf[index];
                      final stats = progress[novel.url];
                      // 注意：不再批量统计缓存状态，避免性能问题
                      // 进度条UI将依赖预加载服务的实时更新（如果有）
                      final cached =
                          stats != null ? (stats['cachedChapters'] ?? 0) : 0;
                      final total =
                          stats != null ? (stats['totalChapters'] ?? 0) : 0;
                      final double percent =
                          (total > 0) ? (cached / total).clamp(0.0, 1.0) : 0.0;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Row(
                            children: [
                              if (_isPreloading(novel.url))
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context)
                                              .colorScheme
                                              .primary),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  novel.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '作者: ${novel.author}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (novel.url.startsWith('custom://')) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .tertiary
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '原创',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .tertiary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (total > 0) ...[
                                LinearProgressIndicator(value: percent),
                                const SizedBox(height: 4),
                                Text(
                                  '已缓存章节: $cached / $total',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 继续阅读按钮（仅在有阅读记录时显示）
                              if (novel.lastReadChapterIndex != null &&
                                  novel.lastReadChapterIndex! > 0)
                                IconButton(
                                  icon: const Icon(Icons.menu_book),
                                  tooltip: '继续阅读',
                                  onPressed: () => _continueReading(novel),
                                ),
                              // 原有的菜单按钮
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'move':
                                      _showBookshelfSelectionDialog(novel, 'move');
                                      break;
                                    case 'copy':
                                      _showBookshelfSelectionDialog(novel, 'copy');
                                      break;
                                    case 'delete':
                                      _removeFromBookshelf(novel);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'move',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.drive_file_move_outline,
                                        ),
                                        SizedBox(width: 8),
                                        Text('移动到书架'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'copy',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy),
                                        SizedBox(width: 8),
                                        Text('复制到书架'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete),
                                        SizedBox(width: 8),
                                        Text('从书架移除'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChapterListScreenRiverpod(novel: novel),
                              ),
                            ).then((_) {
                              // 书架列表会通过Riverpod自动刷新，无需手动刷新
                            });
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'bookshelf_fab',
        onPressed: _showCreateNovelDialog,
        tooltip: '创建新小说',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
    );
  }
}
