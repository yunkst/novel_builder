import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service_wrapper.dart';
import '../utils/video_cache_manager.dart';
import '../utils/video_generation_state_manager.dart';
import '../utils/image_cache_manager.dart';
import 'common/common_widgets.dart';

/// 媒体类型枚举
enum MediaType {
  image,
  video,
  loading,
  error,
}

/// 混合媒体组件
/// 智能显示图片或视频，支持Live Photo式循环播放
class HybridMediaWidget extends StatefulWidget {
  final String imageUrl;
  final String imgName;
  final double? height;
  final double? width;
  final Widget? overlay;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool showControls;

  const HybridMediaWidget({
    super.key,
    required this.imageUrl,
    required this.imgName,
    this.height,
    this.width,
    this.overlay,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.showControls = false,
  });

  @override
  State<HybridMediaWidget> createState() => _HybridMediaWidgetState();
}

class _HybridMediaWidgetState extends State<HybridMediaWidget> {
  MediaType _mediaType = MediaType.loading;
  VideoPlayerController? _videoController;
  String? _videoUrl;
  double _lastVisibleFraction = 0.0; // 用于 VisibilityDetector 去抖

  // 图片缓存相关状态
  Uint8List? _imageData;
  bool _imageLoadingError = false;

  @override
  void initState() {
    super.initState();
    debugPrint('✅ 创建 HybridMediaWidget: ${widget.imgName}');
    _checkVideoStatus();
    _loadImageWithCache();
  }

  @override
  void dispose() {
    debugPrint('❌ 销毁 HybridMediaWidget: ${widget.imgName}');
    // 使用引用计数机制释放视频控制器
    if (_videoUrl != null) {
      // 暂停当前组件的视频播放
      VideoCacheManager.pauseVideo(_videoUrl!);
      // 减少引用计数，如果计数为0则自动释放控制器
      VideoCacheManager.releaseController(_videoUrl!);
      debugPrint('❌ 释放视频控制器引用: ${widget.imgName}, url: $_videoUrl');
    }
    // 清理本地引用
    _videoController = null;
    _videoUrl = null;
    super.dispose();
  }

  /// 使用缓存加载图片
  Future<void> _loadImageWithCache() async {
    try {
      debugPrint('📥 使用缓存加载图片: ${widget.imgName}');
      final data = await ImageCacheManager.getImage(widget.imageUrl);
      if (mounted) {
        setState(() {
          _imageData = data;
          _imageLoadingError = false;
        });
        debugPrint('✅ 图片加载成功: ${widget.imgName}, 大小: ${data.length} bytes');
      }
    } catch (e) {
      debugPrint('❌ 图片加载失败: ${widget.imgName}, 错误: $e');
      if (mounted) {
        setState(() {
          _imageLoadingError = true;
        });
      }
    }
  }

  /// 检查视频状态
  Future<void> _checkVideoStatus() async {
    if (!mounted) return;

    debugPrint('🔍 检查视频状态: ${widget.imgName}');
    try {
      final apiService = ApiServiceWrapper();
      final videoStatus = await apiService.checkVideoStatus(widget.imgName);
      debugPrint(
          '📊 视频状态检查结果: ${widget.imgName}, hasVideo=${videoStatus.hasVideo}');

      if (videoStatus.hasVideo == true) {
        // 有视频，获取视频URL并准备播放
        final host = await apiService.getHost();
        if (host != null && mounted) {
          _videoUrl = ApiServiceWrapper.buildVideoUrl(host, widget.imgName);
          await _initializeVideo();
        } else {
          _setState(MediaType.image);
        }
      } else {
        // 没有视频，显示图片
        _setState(MediaType.image);
      }
    } catch (e) {
      debugPrint('检查视频状态失败: ${widget.imgName}, 错误: $e');
      _setState(MediaType.error);
    }
  }

  /// 初始化视频播放器
  Future<void> _initializeVideo() async {
    if (_videoUrl == null || !mounted) return;

    try {
      final controller = await VideoCacheManager.getController(_videoUrl!);
      if (controller != null && mounted) {
        setState(() {
          _videoController = controller;
          _mediaType = MediaType.video;
        });

        // 如果视频可见，开始播放
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _videoController != null) {
            _videoController!.play();
          }
        });
      } else {
        _setState(MediaType.image);
      }
    } catch (e) {
      debugPrint('初始化视频失败: $_videoUrl, 错误: $e');
      _setState(MediaType.error);
    }
  }

  /// 设置媒体类型状态
  void _setState(MediaType type) {
    if (mounted) {
      setState(() {
        _mediaType = type;
      });
    }
  }

  /// 构建加载状态
  Widget _buildLoadingWidget() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
      child: const LoadingStateWidget(
        centered: true,
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorWidget() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: const ErrorStateWidget(
        message: '媒体加载失败',
        icon: Icons.error_outline,
        centered: true,
      ),
    );
  }

  /// 构建图片组件
  Widget _buildImageWidget() {
    // 如果正在加载，显示加载状态
    if (_imageData == null && !_imageLoadingError) {
      return _buildLoadingWidget();
    }

    // 如果加载出错，显示错误状态
    if (_imageLoadingError || _imageData == null) {
      return _buildErrorWidget();
    }

    // 显示已加载的图片（从缓存中）
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Image.memory(
          _imageData!,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true, // 防止图片切换时闪烁
        ),
      ),
    );
  }

  /// 构建视频组件
  Widget _buildVideoWidget() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return _buildLoadingWidget();
    }

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          children: [
            // 视频播放器
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: widget.fit,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),

            // 生成状态覆盖层
            if (VideoGenerationStateManager.isImageGenerating(widget.imgName))
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: widget.borderRadius,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '正在生成视频...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    switch (_mediaType) {
      case MediaType.loading:
        content = _buildLoadingWidget();
        break;
      case MediaType.error:
        content = _buildErrorWidget();
        break;
      case MediaType.image:
        content = _buildImageWidget();
        break;
      case MediaType.video:
        content = _buildVideoWidget();
        break;
    }

    // 包装可见性检测器
    return VisibilityDetector(
      key: Key('media_${widget.imgName}'),
      onVisibilityChanged: (visibilityInfo) {
        if (_mediaType == MediaType.video && _videoUrl != null) {
          final wasVisible = _lastVisibleFraction > 0.5;
          final isVisible = visibilityInfo.visibleFraction > 0.5;

          // 只在可见性状态真正改变时触发（去抖）
          if (wasVisible != isVisible) {
            if (isVisible) {
              // 可见时播放
              VideoCacheManager.playVideo(_videoUrl!);
              debugPrint('视频开始播放: ${widget.imgName}');
            } else {
              // 不可见时暂停
              VideoCacheManager.pauseVideo(_videoUrl!);
              debugPrint('视频暂停播放: ${widget.imgName}');
            }
          }

          // 更新上次的可见性状态
          _lastVisibleFraction = visibilityInfo.visibleFraction;
        }
      },
      child: Stack(
        children: [
          content,
          if (widget.overlay != null) widget.overlay!,
        ],
      ),
    );
  }
}
