/// Riverpod Providers for BookshelfScreen
///
/// 管理书架屏幕的所有状态和依赖
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/novel.dart';
import '../../core/providers/database_providers.dart';
import '../../core/providers/service_providers.dart';

part 'bookshelf_providers.g.dart';

/// 当前选中的书架ID
///
/// 默认值为 1（"全部小说"书架）
@riverpod
class CurrentBookshelfId extends _$CurrentBookshelfId {
  @override
  int build() => 1;

  /// 设置当前书架ID
  void setBookshelfId(int bookshelfId) {
    state = bookshelfId;
  }
}

/// 书架小说列表
///
/// 根据当前书架ID异步加载小说列表
@riverpod
Future<List<Novel>> bookshelfNovels(Ref ref) async {
  // 获取当前书架ID
  final bookshelfId = ref.watch(currentBookshelfIdProvider);

  // Web环境特殊处理
  if (kIsWeb) {
    // 在Web环境中，返回模拟测试数据
    return [
      Novel(
        title: '测试小说1',
        author: '测试作者1',
        url: 'https://example.com/novel1',
        coverUrl: '',
        description: '这是一个测试小说描述',
      ),
      Novel(
        title: '测试小说2',
        author: '测试作者2',
        url: 'https://example.com/novel2',
        coverUrl: '',
        description: '这是另一个测试小说描述',
      ),
    ];
  }

  // 获取 Repository
  final bookshelfRepository = ref.watch(bookshelfRepositoryProvider);

  // 从数据库加载小说列表
  final novels = await bookshelfRepository.getNovelsByBookshelf(bookshelfId);

  return novels;
}

/// 预加载进度流
///
/// 监听预加载服务的进度更新
@riverpod
Stream<Map<String, Map<String, int>>> preloadProgress(Ref ref) {
  // 获取 PreloadService
  final preloadService = ref.watch(preloadServiceProvider);

  // 返回进度流
  return preloadService.progressStream.map((update) {
    return {
      update.novelUrl: {
        'cachedChapters': update.cachedChapters,
        'totalChapters': update.totalChapters,
      },
    };
  });
}

/// 合并的预加载进度
///
/// 将所有进度更新合并到一个 Map 中
/// 使用 StateProvider 在 UI 中方便地访问
@riverpod
class PreloadProgressMap extends _$PreloadProgressMap {
  @override
  Map<String, Map<String, int>> build() {
    // 监听进度流并更新状态
    ref.listen(preloadProgressProvider, (previous, next) {
      next.when(
        data: (progressMap) {
          // 合并进度数据
          state = {...state, ...progressMap};
        },
        loading: () {},
        error: (error, stack) {},
      );
    });

    return {};
  }
}
