/// Agent 文生图结果画廊组件
///
/// 当 `create_images` 工具成功完成时，在 AgentToolCallCard 末尾渲染此卡片。
/// 工具结果 JSON（call.result，fullResult 完整版）含 images 数组，每项有
/// imageId（前端生成，作缓存文件名）和 taskId（后端 ComfyUI 任务 id）。
///
/// 渲染策略：
/// - 单图：直接 _GalleryImage
/// - 多图：PageView 左右切换 + 底部页码 1/N
///
/// 每张图独立状态机：先查本地缓存命中则显示，否则 GET /api/text2img/image/{taskId}
/// 拉取（200 存缓存显示 / 202 pending / 404 失败）。组件可见 + app 前台时
/// 每 10s 轮询一次直到 loaded。点击图片进入 _FullScreenImageGallery（PhotoView 缩放）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/providers/services/network_service_providers.dart';
import '../../services/agent_image_cache_service.dart';
import '../../services/logger_service.dart';

// ============================================================================
// 数据模型 + 解析
// ============================================================================

/// 单张图片项（来自工具结果 images 数组）
class ImageGalleryItem {
  final String imageId;
  final String taskId;
  final String prompt;
  final String? modelName;

  const ImageGalleryItem({
    required this.imageId,
    required this.taskId,
    required this.prompt,
    this.modelName,
  });
}

/// 画廊数据（整条 create_images 工具结果）
class ImageGalleryData {
  final List<ImageGalleryItem> images;
  const ImageGalleryData({required this.images});
}

/// 解析工具结果 JSON。成功且 images 非空时返回 ImageGalleryData，否则 null。
ImageGalleryData? parseImageGallery(String? toolResultJson) {
  if (toolResultJson == null) return null;
  try {
    final json = jsonDecode(toolResultJson) as Map<String, dynamic>;
    if (json['success'] != true) return null;
    final rawImages = json['images'];
    if (rawImages is! List || rawImages.isEmpty) return null;
    final items = <ImageGalleryItem>[];
    for (final m in rawImages) {
      if (m is! Map) continue;
      final imageId = m['imageId'] as String?;
      final taskId = m['taskId'] as String?;
      if (imageId == null || taskId == null) continue;
      items.add(ImageGalleryItem(
        imageId: imageId,
        taskId: taskId,
        prompt: (m['prompt'] as String?) ?? '',
        modelName: m['modelName'] as String?,
      ));
    }
    if (items.isEmpty) return null;
    return ImageGalleryData(images: items);
  } catch (_) {
    return null;
  }
}

// ============================================================================
// 画廊卡片（对外入口）
// ============================================================================

/// 画廊卡片。单图直接渲染，多图 PageView + 页码。
class ImageGalleryCard extends StatelessWidget {
  final ImageGalleryData data;
  const ImageGalleryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final images = data.images;
    if (images.length == 1) {
      return _GalleryImage(
        item: images.first,
        onTap: () => _openFullScreen(context, images, 0),
      );
    }
    return _MultiImageGallery(images: images);
  }
}

class _MultiImageGallery extends StatefulWidget {
  final List<ImageGalleryItem> images;
  const _MultiImageGallery({required this.images});

  @override
  State<_MultiImageGallery> createState() => _MultiImageGalleryState();
}

class _MultiImageGalleryState extends State<_MultiImageGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.images.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 320,
            child: PageView.builder(
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _GalleryImage(
                item: widget.images[i],
                onTap: () => _openFullScreen(context, widget.images, i),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_index + 1} / $total',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

void _openFullScreen(
  BuildContext context,
  List<ImageGalleryItem> all,
  int initial,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _FullScreenImageGallery(images: all, initialIndex: initial),
    ),
  );
}

// ============================================================================
// 单张图片（核心状态机）
// ============================================================================

/// 单张图片渲染 + 加载 + 轮询。
///
/// 状态：`_file == null` → loading（含失败，附刷新按钮）；`_file != null` → loaded。
/// 轮询条件（非 fullscreen）：组件可见（visibleFraction > 0）且 app 前台（resumed）。
/// fullscreen 模式忽略可见性（恒可见），仅 lifecycle 控制；loaded 后用 PhotoView
/// 渲染以支持双指缩放。
class _GalleryImage extends ConsumerStatefulWidget {
  final ImageGalleryItem item;
  final VoidCallback? onTap;
  final bool fullscreen;
  const _GalleryImage({
    required this.item,
    this.onTap,
    this.fullscreen = false,
  });

  @override
  ConsumerState<_GalleryImage> createState() => _GalleryImageState();
}

class _GalleryImageState extends ConsumerState<_GalleryImage>
    with WidgetsBindingObserver {
  File? _file;
  bool _loading = false; // 防止并发重复请求
  bool _visible = false;
  bool _appActive = true;
  Timer? _timer;

  bool get _shouldPoll =>
      widget.item.taskId.isNotEmpty &&
      _file == null &&
      _appActive &&
      (widget.fullscreen || _visible);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _visible = widget.fullscreen; // 全屏页恒可见
    _load(); // 立即尝试一次
    _evaluateTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive != active) {
      _appActive = active;
      if (active && _file == null) _load(); // 回前台立即拉一次
      _evaluateTimer();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0;
    if (_visible != visible) {
      _visible = visible;
      if (visible && _file == null) _load(); // 变可见立即拉一次
      _evaluateTimer();
    }
  }

  /// 评估并启动/停止 10s 轮询定时器
  void _evaluateTimer() {
    if (_shouldPoll) {
      if (_timer == null || !_timer!.isActive) {
        _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    if (mounted) setState(() {}); // 触发 loading 态刷新
    try {
      // 1. 先查本地缓存
      final cached =
          await AgentImageCacheService.instance.getFile(widget.item.imageId);
      if (cached != null) {
        if (mounted) setState(() => _file = cached);
        _evaluateTimer();
        return;
      }
      // 2. miss → 从后端拉
      final api = ref.read(apiServiceWrapperProvider);
      final (bytes, code) = await api.fetchText2ImgImage(widget.item.taskId);
      if (code == 200 && bytes != null && bytes.isNotEmpty) {
        final saved = await AgentImageCacheService.instance
            .saveBytes(widget.item.imageId, bytes);
        if (mounted) setState(() => _file = saved);
        _evaluateTimer();
      }
      // 其他状态码（202 pending / 404 失败 / 网络错）：保持 loading，等下次轮询
    } catch (e) {
      LoggerService.instance.d(
        '画廊图片加载失败: imageId=${widget.item.imageId}, $e',
        category: LogCategory.ai,
        tags: ['agent', 'gallery', 'load_failed'],
      );
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = _file;

    // loaded：fullscreen 用 PhotoView（缩放），否则 Image.file + 点击全屏
    if (file != null) {
      if (widget.fullscreen) {
        return PhotoView(
          imageProvider: FileImage(file),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          loadingBuilder: (_, __) => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.contain),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.fullscreen,
                    size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    // loading 态（含失败）
    final loadingWidget = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: 8),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: '刷新',
          onPressed: _loading ? null : _load,
          style: IconButton.styleFrom(
            backgroundColor: widget.fullscreen
                ? Colors.white.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHigh,
            foregroundColor:
                widget.fullscreen ? Colors.white : theme.colorScheme.primary,
            minimumSize: const Size(32, 32),
          ),
        ),
      ],
    );

    if (widget.fullscreen) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: loadingWidget,
      );
    }

    // 非全屏：VisibilityDetector 包裹，浅灰底
    return VisibilityDetector(
      key: ValueKey('gallery_img_${widget.item.imageId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: loadingWidget,
      ),
    );
  }
}

// ============================================================================
// 全屏画廊（PageView，每页 _GalleryImage fullscreen 模式）
// ============================================================================

class _FullScreenImageGallery extends StatefulWidget {
  final List<ImageGalleryItem> images;
  final int initialIndex;
  const _FullScreenImageGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageGallery> createState() =>
      _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<_FullScreenImageGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        title: Text(
          total > 1 ? '${_index + 1} / $total' : '图片',
          style: const TextStyle(fontSize: 14),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => _GalleryImage(
          item: widget.images[i],
          fullscreen: true,
        ),
      ),
    );
  }
}
