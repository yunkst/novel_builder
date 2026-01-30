import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/role_gallery_cache_service.dart';
import 'common/common_widgets.dart';

/// 使用API客户端的图片加载组件
class ApiImageWidget extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableRetry;
  final Function()? onRetry;
  final Duration? timeout;
  final RoleGalleryCacheService? cacheService; // 可选的缓存服务实例

  const ApiImageWidget({
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
    this.cacheService, // 新增参数
  });

  @override
  State<ApiImageWidget> createState() => _ApiImageWidgetState();
}

class _ApiImageWidgetState extends State<ApiImageWidget> {
  bool _isLoading = false;
  bool _hasError = false;
  Uint8List? _imageBytes;
  String? _errorMessage;

  late final RoleGalleryCacheService _cacheService;

  @override
  void initState() {
    super.initState();
    // 使用传入的缓存服务实例，如果没有则创建新实例并初始化
    _cacheService = widget.cacheService ?? RoleGalleryCacheService();
    _loadImage();
  }

  @override
  void didUpdateWidget(ApiImageWidget oldWidget) {
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
      final imageBytes = await _cacheService
          .getImageBytes(widget.imageUrl)
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
      debugPrint('图片加载失败: ${widget.imageUrl}, 错误: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
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
              height: widget.height,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              child: const LoadingStateWidget(
                message: '加载中...',
                centered: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
        child: const LoadingStateWidget(
          message: '加载中...',
          centered: true,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String? error) {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        child: ErrorStateWidget(
          message: '图片加载失败',
          icon: Icons.broken_image_outlined,
          onRetry: widget.enableRetry ? _retry : null,
          centered: true,
        ),
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
