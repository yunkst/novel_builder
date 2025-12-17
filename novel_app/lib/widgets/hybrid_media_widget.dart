import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service_wrapper.dart';
import '../utils/video_cache_manager.dart';
import '../utils/video_generation_state_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _checkVideoStatus();
  }

  @override
  void dispose() {
    // 暂停当前组件的视频播放
    if (_videoUrl != null) {
      VideoCacheManager.pauseVideo(_videoUrl!);
    }
    // 清理引用但不释放控制器，因为它由 VideoCacheManager 统一管理
    _videoController = null;
    _videoUrl = null;
    super.dispose();
  }

  /// 检查视频状态
  Future<void> _checkVideoStatus() async {
    if (!mounted) return;

    try {
      final apiService = ApiServiceWrapper();
      final videoStatus = await apiService.checkVideoStatus(widget.imgName);

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
        color: Colors.grey.shade100,
        borderRadius: widget.borderRadius,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorWidget() {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: widget.borderRadius,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(height: 8),
            Text('媒体加载失败', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  /// 构建图片组件
  Widget _buildImageWidget() {
    // 这里使用现有的图片加载逻辑
    return FutureBuilder<Uint8List>(
      future: ApiServiceWrapper().getImageProxy(widget.imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorWidget();
        }

        final imageBytes = snapshot.data!;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Image.memory(
              imageBytes,
              fit: widget.fit,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        );
      },
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
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: widget.borderRadius,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '正在生成视频...',
                          style: TextStyle(
                            color: Colors.white,
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
          if (visibilityInfo.visibleFraction > 0.5) {
            // 可见时播放
            VideoCacheManager.playVideo(_videoUrl!);
          } else {
            // 不可见时暂停
            VideoCacheManager.pauseVideo(_videoUrl!);
          }
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