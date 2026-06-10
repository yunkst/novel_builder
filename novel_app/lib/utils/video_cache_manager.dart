import 'package:video_player/video_player.dart';
import '../services/logger_service.dart';

/// 视频缓存管理器
/// 用于管理视频播放器的创建、缓存和生命周期
class VideoCacheManager {
  static final Map<String, VideoPlayerController> _controllers = {};
  static final Map<String, bool> _disposedFlags = {};
  static final Map<String, bool> _creatingFlags = {}; // 创建锁，防止竞态条件
  static final Map<String, int> _refCounts = {}; // 引用计数，跟踪控制器使用情况
  static String? _activeVideoUrl;
  static const int _maxCachedControllers = 10;

  /// 检查控制器是否有效
  static bool _isControllerValid(VideoPlayerController controller) {
    try {
      return controller.value.isInitialized &&
          (_disposedFlags[controller.dataSource] ?? false) == false;
    } catch (e) {
      // 如果访问控制器属性时抛出异常，说明控制器已被释放
      LoggerService.instance.w(
        '控制器状态检查失败，可能已被释放: $e',
        category: LogCategory.cache,
        tags: ['video', 'controller', 'invalid'],
      );
      return false;
    }
  }

  /// 获取视频控制器
  static Future<VideoPlayerController?> getController(String videoUrl) async {
    // 检查是否正在创建中（竞态条件防护）
    if (_creatingFlags[videoUrl] == true) {
      LoggerService.instance.d(
        '等待其他实例创建控制器: $videoUrl',
        category: LogCategory.cache,
        tags: ['video', 'controller', 'waiting'],
      );
      // 等待创建完成
      while (_creatingFlags[videoUrl] == true) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // 创建完成后，从缓存中获取
      final controller = _controllers[videoUrl];
      if (controller != null && _isControllerValid(controller)) {
        // 增加引用计数
        _refCounts[videoUrl] = (_refCounts[videoUrl] ?? 0) + 1;
        LoggerService.instance.d(
          '获取到已创建的控制器: $videoUrl, 引用计数: ${_refCounts[videoUrl]}',
          category: LogCategory.cache,
          tags: ['video', 'controller', 'reuse'],
        );
        return controller;
      }
      return null;
    }

    // 标记为正在创建
    _creatingFlags[videoUrl] = true;

    try {
      // 检查缓存
      if (_controllers.containsKey(videoUrl)) {
        final controller = _controllers[videoUrl];
        // 验证控制器是否仍然有效
        if (controller != null && _isControllerValid(controller)) {
          // 增加引用计数
          _refCounts[videoUrl] = (_refCounts[videoUrl] ?? 0) + 1;
          LoggerService.instance.d(
            '获取缓存的控制器: $videoUrl, 引用计数: ${_refCounts[videoUrl]}',
            category: LogCategory.cache,
            tags: ['video', 'controller', 'hit'],
          );
          return controller;
        } else {
          // 控制器已失效，清理缓存
          _removeController(videoUrl);
          LoggerService.instance.w(
            '清理失效的视频控制器缓存: $videoUrl',
            category: LogCategory.cache,
            tags: ['video', 'controller', 'stale'],
          );
        }
      }

      // 缓存数量限制
      if (_controllers.length >= _maxCachedControllers) {
        _disposeOldestController();
      }

      // 创建新的控制器
      LoggerService.instance.i(
        '创建新的视频控制器: $videoUrl',
        category: LogCategory.cache,
        tags: ['video', 'controller', 'create'],
      );
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      // 初始化并设置为循环播放
      await controller.initialize();
      controller.setLooping(true);

      // 缓存控制器并初始化引用计数
      _controllers[videoUrl] = controller;
      _disposedFlags[videoUrl] = false;
      _refCounts[videoUrl] = 1; // 初始引用计数为1

      LoggerService.instance.i(
        '视频控制器已创建和缓存: $videoUrl, 引用计数: 1',
        category: LogCategory.cache,
        tags: ['video', 'controller', 'created'],
      );
      return controller;
    } catch (e) {
      LoggerService.instance.e(
        '创建视频控制器失败: $videoUrl, 错误: $e',
        category: LogCategory.cache,
        tags: ['video', 'controller', 'error'],
      );
      return null;
    } finally {
      // 释放创建锁
      _creatingFlags[videoUrl] = false;
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
        LoggerService.instance.d(
          '视频控制器已释放: $videoUrl',
          category: LogCategory.cache,
          tags: ['video', 'controller', 'dispose'],
        );
      } catch (e) {
        LoggerService.instance.e(
          '释放视频控制器时出错: $videoUrl, 错误: $e',
          category: LogCategory.cache,
          tags: ['video', 'controller', 'dispose', 'error'],
        );
      }
    }
    _disposedFlags[videoUrl] = true;
    _refCounts.remove(videoUrl);
    if (_activeVideoUrl == videoUrl) {
      _activeVideoUrl = null;
    }
  }

  /// 减少引用计数，如果计数为0则释放控制器
  static void releaseController(String videoUrl) {
    if (_refCounts.containsKey(videoUrl)) {
      _refCounts[videoUrl] = _refCounts[videoUrl]! - 1;
      LoggerService.instance.d(
        '减少引用计数: $videoUrl, 剩余引用: ${_refCounts[videoUrl]}',
        category: LogCategory.cache,
        tags: ['video', 'refcount'],
      );

      if (_refCounts[videoUrl]! <= 0) {
        LoggerService.instance.i(
          '引用计数为0，释放控制器: $videoUrl',
          category: LogCategory.cache,
          tags: ['video', 'refcount', 'release'],
        );
        disposeController(videoUrl);
      }
    } else {
      LoggerService.instance.w(
        '尝试释放不存在的控制器引用: $videoUrl',
        category: LogCategory.cache,
        tags: ['video', 'refcount', 'missing'],
      );
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
    LoggerService.instance.d(
      '已释放最旧的视频控制器以腾出空间',
      category: LogCategory.cache,
      tags: ['video', 'controller', 'evict'],
    );
  }

  /// 释放所有控制器
  static void disposeAll() {
    for (final controller in _controllers.values) {
      try {
        controller.dispose();
      } catch (e) {
        LoggerService.instance.e(
          '释放控制器时出错: $e',
          category: LogCategory.cache,
          tags: ['video', 'controller', 'dispose', 'error'],
        );
      }
    }
    _controllers.clear();
    _disposedFlags.clear();
    _creatingFlags.clear();
    _refCounts.clear();
    _activeVideoUrl = null;
    LoggerService.instance.i(
      '所有视频控制器已释放',
      category: LogCategory.cache,
      tags: ['video', 'controller', 'disposeAll'],
    );
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
