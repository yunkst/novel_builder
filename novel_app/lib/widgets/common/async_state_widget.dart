import 'package:flutter/material.dart';

/// 通用的异步状态处理Widget
///
/// 用于统一处理 FutureBuilder 或 StreamBuilder 的快照状态，
/// 减少重复的加载/错误/空数据判断代码。
///
/// 示例:
/// ```dart
/// FutureBuilder<Novel>(
///   future: _loadNovel(),
///   builder: (context, snapshot) {
///     return AsyncStateWidget<Novel>(
///       snapshot: snapshot,
///       builder: (novel) => NovelCard(novel: novel),
///     );
///   },
/// )
/// ```
///
/// 也支持自定义错误处理和加载组件:
/// ```dart
/// AsyncStateWidget<MyData>(
///   snapshot: snapshot,
///   builder: (data) => DataWidget(data: data),
///   errorBuilder: (error) => ErrorCard(error: error),
///   loadingWidget: LoadingWidget(message: '加载中...'),
/// )
/// ```
class AsyncStateWidget<T> extends StatelessWidget {
  /// 异步快照
  final AsyncSnapshot<T> snapshot;

  /// 数据构建器
  final Widget Function(T data) builder;

  /// 错误构建器（可选，默认使用内置错误显示）
  final Widget Function(Object error)? errorBuilder;

  /// 加载组件（可选，默认使用 CircularProgressIndicator）
  final Widget? loadingWidget;

  /// 空数据组件（可选，默认显示"暂无数据"）
  final Widget? emptyWidget;

  /// 是否显示连接状态为等待中的状态（默认为 true）
  final bool showWaiting;

  const AsyncStateWidget({
    super.key,
    required this.snapshot,
    required this.builder,
    this.errorBuilder,
    this.loadingWidget,
    this.emptyWidget,
    this.showWaiting = true,
  });

  @override
  Widget build(BuildContext context) {
    // 处理等待状态
    if (showWaiting && snapshot.connectionState == ConnectionState.waiting) {
      return loadingWidget ?? const _DefaultLoadingWidget();
    }

    // 处理错误状态
    if (snapshot.hasError) {
      return errorBuilder?.call(snapshot.error!) ?? _buildErrorWidget(context, snapshot.error!);
    }

    // 处理空数据状态
    if (!snapshot.hasData) {
      return emptyWidget ?? const _DefaultEmptyWidget();
    }

    // 处理数据为 null 的情况（针对 T 是可空类型）
    final data = snapshot.data;
    if (data == null) {
      return emptyWidget ?? const _DefaultEmptyWidget();
    }

    // 构建数据组件
    return builder(data);
  }

  /// 构建默认的错误显示组件
  Widget _buildErrorWidget(BuildContext context, Object error) {
    return _DefaultErrorWidget(error: error);
  }
}

/// 默认的加载组件
class _DefaultLoadingWidget extends StatelessWidget {
  const _DefaultLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

/// 默认的错误组件
class _DefaultErrorWidget extends StatelessWidget {
  final Object error;

  const _DefaultErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 默认的空数据组件
class _DefaultEmptyWidget extends StatelessWidget {
  const _DefaultEmptyWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// 扩展：基于异步状态的列表构建器
///
/// 专门用于处理列表数据的异步状态组件。
///
/// 示例:
/// ```dart
/// AsyncListBuilder<Chapter>(
///   snapshot: snapshot,
///   itemBuilder: (context, chapter) => ChapterTile(chapter: chapter),
///   emptyMessage: '暂无章节',
/// )
/// ```
class AsyncListBuilder<T> extends StatelessWidget {
  /// 异步快照
  final AsyncSnapshot<List<T>> snapshot;

  /// 列表项构建器
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// 空列表消息
  final String? emptyMessage;

  /// 空列表图标
  final IconData? emptyIcon;

  /// 错误构建器（可选）
  final Widget Function(Object error)? errorBuilder;

  /// 加载组件（可选）
  final Widget? loadingWidget;

  /// 列表内边距
  final EdgeInsets? padding;

  /// 是否显示分隔符（默认为 false）
  final bool showDivider;

  const AsyncListBuilder({
    super.key,
    required this.snapshot,
    required this.itemBuilder,
    this.emptyMessage,
    this.emptyIcon,
    this.errorBuilder,
    this.loadingWidget,
    this.padding,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncStateWidget<List<T>>(
      snapshot: snapshot,
      builder: (items) {
        if (items.isEmpty) {
          return _buildEmptyWidget(context);
        }

        return _buildList(context, items);
      },
      errorBuilder: errorBuilder,
      loadingWidget: loadingWidget,
      emptyWidget: null, // 由 builder 内部处理
    );
  }

  /// 构建空数据组件
  Widget _buildEmptyWidget(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            emptyIcon ?? Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage ?? '暂无数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建列表组件
  Widget _buildList(BuildContext context, List<T> items) {
    final listView = ListView.builder(
      padding: padding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          children: [
            itemBuilder(context, item),
            if (showDivider && index < items.length - 1)
              const Divider(height: 1),
          ],
        );
      },
    );

    return listView;
  }
}
