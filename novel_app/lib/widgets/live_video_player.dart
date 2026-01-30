import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'common/common_widgets.dart';

/// Live图效果的循环视频播放器
/// 5秒循环播放，无控制条，类似Live Photo效果
class LiveVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final VoidCallback? onVideoEnd;
  final bool autoPlay;
  final bool mute;

  const LiveVideoPlayer({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.onVideoEnd,
    this.autoPlay = true,
    this.mute = true,
  });

  @override
  State<LiveVideoPlayer> createState() => _LiveVideoPlayerState();
}

class _LiveVideoPlayerState extends State<LiveVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(LiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });

      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      // 添加监听器
      _controller!.addListener(_videoListener);

      // 初始化视频控制器
      await _controller!.initialize();

      if (widget.autoPlay) {
        await _controller!.play();
      }

      if (widget.mute) {
        await _controller!.setVolume(0.0);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
      debugPrint('视频初始化失败: $e');
    }
  }

  void _videoListener() {
    if (_controller == null) return;

    // 检查视频是否结束，自动循环播放
    if (_controller!.value.position >= _controller!.value.duration) {
      _restartVideo();
    }

    // 处理错误
    if (_controller!.value.hasError) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller!.value.errorDescription ?? '视频播放错误';
        });
      }
    }
  }

  Future<void> _restartVideo() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.seekTo(Duration.zero);
        if (widget.autoPlay) {
          await _controller!.play();
        }
        widget.onVideoEnd?.call();
      }
    } catch (e) {
      debugPrint('重启视频播放失败: $e');
    }
  }

  void _disposeController() {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildPlaceholder();
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return _buildPlaceholder();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 视频播放器
            FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),

            // Live图标识（可选）
            if (_controller!.value.isPlaying)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 12,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 加载指示器（缓冲时显示）
            if (_controller!.value.isBuffering)
              Container(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.surface,
                    ),
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const LoadingStateWidget(
          message: '加载视频中...',
          centered: true,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.2),
          ),
        ),
        child: ErrorStateWidget(
          message: _errorMessage ?? '视频加载失败',
          icon: Icons.error_outline,
          onRetry: () {
            _disposeController();
            _initializeVideo();
          },
          retryText: '重试',
          centered: true,
        ),
      ),
    );
  }
}

/// 带封面图片的Live视频播放器
/// 视频未加载时显示封面图片，加载完成后自动播放视频
class LiveVideoPlayerWithThumbnail extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onVideoEnd;

  const LiveVideoPlayerWithThumbnail({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.onVideoEnd,
  });

  @override
  State<LiveVideoPlayerWithThumbnail> createState() =>
      _LiveVideoPlayerWithThumbnailState();
}

class _LiveVideoPlayerWithThumbnailState
    extends State<LiveVideoPlayerWithThumbnail> {
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    // 延迟显示视频，确保封面图片先显示
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showVideo = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showVideo) {
      // 显示封面图片
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.thumbnailUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            );
          },
        ),
      );
    }

    // 显示视频播放器
    return LiveVideoPlayer(
      videoUrl: widget.videoUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: Image.network(
        widget.thumbnailUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      ),
      onVideoEnd: widget.onVideoEnd,
    );
  }
}
