import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// 视频缓存管理器
/// 用于管理视频播放器的创建、缓存和生命周期
class VideoCacheManager {
  static final Map<String, VideoPlayerController> _controllers = {};
  static final Map<String, bool> _disposedFlags = {};
  static String? _activeVideoUrl;
  static const int _maxCachedControllers = 10;

  /// 检查控制器是否有效
  static bool _isControllerValid(VideoPlayerController controller) {
    try {
      return controller.value.isInitialized &&
             (_disposedFlags[controller.dataSource] ?? false) == false;
    } catch (e) {
      // 如果访问控制器属性时抛出异常，说明控制器已被释放
      debugPrint('控制器状态检查失败，可能已被释放: $e');
      return false;
    }
  }

  /// 获取视频控制器
  static Future<VideoPlayerController?> getController(String videoUrl) async {
    // 检查缓存
    if (_controllers.containsKey(videoUrl)) {
      final controller = _controllers[videoUrl];
      // 验证控制器是否仍然有效
      if (controller != null && _isControllerValid(controller)) {
        return controller;
      } else {
        // 控制器已失效，清理缓存
        _removeController(videoUrl);
        debugPrint('清理失效的视频控制器缓存: $videoUrl');
      }
    }

    // 缓存数量限制
    if (_controllers.length >= _maxCachedControllers) {
      _disposeOldestController();
    }

    try {
      // 创建新的控制器
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      // 初始化并设置为循环播放
      await controller.initialize();
      controller.setLooping(true);

      // 缓存控制器并标记为未释放状态
      _controllers[videoUrl] = controller;
      _disposedFlags[videoUrl] = false;

      debugPrint('视频控制器已创建和缓存: $videoUrl');
      return controller;
    } catch (e) {
      debugPrint('创建视频控制器失败: $videoUrl, 错误: $e');
      return null;
    }
  }

  /// 设置当前活跃的视频URL
  static void setActiveVideo(String? videoUrl) {
    if (_activeVideoUrl == videoUrl) return;

    // 暂停之前的活跃视频
    if (_activeVideoUrl != null && _controllers.containsKey(_activeVideoUrl)) {
      final oldController = _controllers[_activeVideoUrl]!;
      if (oldController.value.isPlaying) {
        oldController.pause();
      }
    }

    // 播放新的活跃视频
    _activeVideoUrl = videoUrl;
    if (videoUrl != null && _controllers.containsKey(videoUrl)) {
      final newController = _controllers[videoUrl]!;
      if (!newController.value.isPlaying) {
        newController.play();
      }
    }
  }

  /// 暂停除指定视频外的所有视频
  static void pauseAllExcept(String? activeUrl) {
    setActiveVideo(activeUrl);
  }

  /// 播放指定视频
  static void playVideo(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null && controller.value.isInitialized) {
      controller.play();
      setActiveVideo(videoUrl);
    }
  }

  /// 暂停指定视频
  static void pauseVideo(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
    }
    if (_activeVideoUrl == videoUrl) {
      _activeVideoUrl = null;
    }
  }

  /// 释放指定控制器
  static void disposeController(String videoUrl) {
    final controller = _controllers.remove(videoUrl);
    if (controller != null) {
      try {
        controller.dispose();
        debugPrint('视频控制器已释放: $videoUrl');
      } catch (e) {
        debugPrint('释放视频控制器时出错: $videoUrl, 错误: $e');
      }
    }
    _disposedFlags[videoUrl] = true;
    if (_activeVideoUrl == videoUrl) {
      _activeVideoUrl = null;
    }
  }

  /// 移除控制器缓存（不释放，仅从缓存中清除）
  static void _removeController(String videoUrl) {
    _controllers.remove(videoUrl);
    _disposedFlags.remove(videoUrl);
    if (_activeVideoUrl == videoUrl) {
      _activeVideoUrl = null;
    }
  }

  /// 释放最旧的控制器
  static void _disposeOldestController() {
    if (_controllers.isEmpty) return;

    final firstKey = _controllers.keys.first;
    disposeController(firstKey);
    debugPrint('已释放最旧的视频控制器以腾出空间');
  }

  /// 释放所有控制器
  static void disposeAll() {
    for (final controller in _controllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('释放控制器时出错: $e');
      }
    }
    _controllers.clear();
    _disposedFlags.clear();
    _activeVideoUrl = null;
    debugPrint('所有视频控制器已释放');
  }

  /// 获取缓存状态信息
  static Map<String, dynamic> getCacheInfo() {
    return {
      'cachedCount': _controllers.length,
      'maxCacheSize': _maxCachedControllers,
      'activeVideo': _activeVideoUrl,
      'cachedUrls': _controllers.keys.toList(),
      'disposedFlags': _disposedFlags,
    };
  }

  /// 检查是否有活跃视频在播放
  static bool get hasActiveVideo => _activeVideoUrl != null;

  /// 获取当前活跃视频URL
  static String? get activeVideoUrl => _activeVideoUrl;
}