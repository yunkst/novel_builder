import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/scene_illustration_cache_service.dart';

/// 场景插图专用图片加载组件
/// 参考ApiImageWidget的实现模式
class SceneIllustrationImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableRetry;
  final Function()? onRetry;
  final Duration? timeout;
  final SceneIllustrationCacheService? cacheService;
  /// 图片实际宽度（用于计算宽高比）
  final int? imageWidth;
  /// 图片实际高度（用于计算宽高比）
  final int? imageHeight;

  const SceneIllustrationImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableRetry = true,
    this.onRetry,
    this.timeout = const Duration(seconds: 30),
    this.cacheService,
    this.imageWidth,
    this.imageHeight,
  });

  @override
  State<SceneIllustrationImageWidget> createState() => _SceneIllustrationImageWidgetState();
}

class _SceneIllustrationImageWidgetState extends State<SceneIllustrationImageWidget> {
  bool _isLoading = false;
  bool _hasError = false;
  Uint8List? _imageBytes;
  String? _errorMessage;

  late final SceneIllustrationCacheService _cacheService;

  @override
  void initState() {
    super.initState();
    // 使用传入的缓存服务实例，如果没有则创建新实例并初始化
    _cacheService = widget.cacheService ?? SceneIllustrationCacheService();

    // 确保缓存服务已初始化
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await _cacheService.init();
      _loadImage();
    } catch (e) {
      debugPrint('场景插图缓存服务初始化失败: $e');
      _loadImage(); // 仍然尝试加载图片
    }
  }

  @override
  void didUpdateWidget(SceneIllustrationImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '图片URL为空';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }

    try {
      final imageBytes = await _cacheService.getImageBytes(widget.imageUrl)
          .timeout(widget.timeout ?? const Duration(seconds: 30));

      if (imageBytes != null) {
        if (mounted) {
          setState(() {
            _imageBytes = imageBytes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = '无法获取图片数据';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
      debugPrint('场景插图加载失败: ${widget.imageUrl}, 错误: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算显示高度
    final displayHeight = _calculateHeight();

    return SizedBox(
      width: widget.width,
      height: displayHeight,
      child: Stack(
        children: [
          // 主要图片组件
          if (_imageBytes != null && !_hasError)
            Image.memory(
              _imageBytes!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorWidget(error.toString());
              },
            )
          else if (_hasError)
            _buildErrorWidget(_errorMessage)
          else
            _buildPlaceholder(),

          // 重试加载状态覆盖层
          if (_isLoading && widget.enableRetry)
            Container(
              width: widget.width,
              height: displayHeight,
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '加载插图中...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 计算显示高度
  double? _calculateHeight() {
    // 优先使用显式设置的高度
    if (widget.height != null) {
      return widget.height;
    }

    // 如果有宽度且有图片尺寸信息，根据宽高比计算高度
    if (widget.width != null &&
        widget.imageWidth != null &&
        widget.imageHeight != null &&
        widget.imageWidth! > 0 &&
        widget.imageHeight! > 0) {
      final aspectRatio = widget.imageWidth! / widget.imageHeight!;
      return widget.width! / aspectRatio;
    }

    // 没有足够信息，返回null让组件自适应
    return null;
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 32,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              '加载插图中...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String? error) {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: Colors.red[400],
          ),
          const SizedBox(height: 8),
          Text(
            '插图加载失败',
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.enableRetry) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(60, 28),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _retry() async {
    if (!widget.enableRetry) return;

    // 清除缓存
    await _cacheService.deleteCachedImage(widget.imageUrl);

    // 调用外部重试回调（如果有）
    if (widget.onRetry != null) {
      await widget.onRetry!();
    }

    // 重新加载图片
    _loadImage();
  }

  /// 手动触发重试
  Future<void> retry() async {
    await _retry();
  }

  /// 清除图片缓存
  Future<void> clearCache() async {
    await _cacheService.deleteCachedImage(widget.imageUrl);
    if (mounted) {
      setState(() {
        _imageBytes = null;
        _hasError = false;
      });
    }
  }

  /// 获取当前图片的字节数据
  Uint8List? get imageBytes => _imageBytes;
}