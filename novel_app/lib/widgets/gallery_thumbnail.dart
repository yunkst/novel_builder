import 'package:flutter/material.dart';
import '../models/role_gallery.dart';
import 'api_image_widget.dart';
import '../services/role_gallery_cache_service.dart';
import '../core/di/api_service_provider.dart';

/// 图集缩略图组件
class GalleryThumbnail extends StatefulWidget {
  final String roleId;
  final VoidCallback? onTap;
  final double? size;
  final bool showBadge;
  final bool enableAnimation;
  final RoleGalleryCacheService? cacheService; // 可选的缓存服务实例

  const GalleryThumbnail({
    super.key,
    required this.roleId,
    this.onTap,
    this.size = 60,
    this.showBadge = true,
    this.enableAnimation = true,
    this.cacheService,
  });

  @override
  State<GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends State<GalleryThumbnail>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = true;
  RoleGallery? _gallery;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 加载图集数据
    _loadGallery();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    try {
      final apiService = ApiServiceProvider.instance;
      final galleryData = await apiService.getRoleGallery(widget.roleId);

      setState(() {
        _gallery = RoleGallery.fromJson(galleryData);
        _isLoading = false;
      });

      debugPrint('✓ 图集加载成功: ${_gallery?.imageCount ?? 0} 张图片');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('❌ 图集加载失败: $e');
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enableAnimation) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enableAnimation) {
      _animationController.reverse();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 60;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () {
        if (widget.enableAnimation) {
          _animationController.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  // 主要图片
                  _buildMainImage(size),
                  // 徽标
                  if (widget.showBadge) _buildBadge(size),
                  // 加载状态
                  if (_isLoading) _buildLoadingOverlay(size),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainImage(double size) {
    final firstImage = _gallery?.firstImage;

    if (firstImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ApiImageWidget(
          imageUrl: firstImage.filename,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: _buildErrorPlaceholder(size),
          cacheService: widget.cacheService, // 传递缓存服务
        ),
      );
    } else {
      return _buildEmptyPlaceholder(size);
    }
  }

  Widget _buildEmptyPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: Icon(
        Icons.photo_library_outlined,
        size: size * 0.4,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildErrorPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red[300]!,
          width: 1,
        ),
      ),
      child: Icon(
        Icons.broken_image_outlined,
        size: size * 0.4,
        color: Colors.red[400],
      ),
    );
  }

  Widget _buildBadge(double size) {
    final imageCount = _gallery?.imageCount ?? 0;

    if (imageCount == 0) return const SizedBox.shrink();

    return Positioned(
      right: -2,
      bottom: -2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        child: Text(
          imageCount > 99 ? '99+' : '$imageCount',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 图集预览卡片组件
class GalleryPreviewCard extends StatelessWidget {
  final String roleId;
  final String? title;
  final VoidCallback? onTap;
  final bool enableAnimation;

  const GalleryPreviewCard({
    super.key,
    required this.roleId,
    this.title,
    this.onTap,
    this.enableAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 缩略图
              GalleryThumbnail(
                roleId: roleId,
                size: 50,
                enableAnimation: enableAnimation,
              ),
              const SizedBox(width: 12),
              // 标题和描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? '角色图集',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点击查看完整图集',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // 箭头图标
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[500],
              ),
            ],
          ),
        ),
      ),
    );
  }
}