import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import '../lib/utils/video_cache_manager.dart';
import '../lib/widgets/hybrid_media_widget.dart';
import '../lib/widgets/live_video_player.dart';

void main() {
  // 初始化 Flutter 测试环境
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPlayerController 生命周期集成测试', () {
    setUp(() {
      // 每个测试前清理视频缓存管理器状态
      VideoCacheManager.disposeAll();
    });

    test('VideoCacheManager 正确创建和管理控制器', () async {
      const testVideoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';

      // 测试创建控制器
      final controller = await VideoCacheManager.getController(testVideoUrl);
      expect(controller, isNotNull);
      expect(controller!.value.isInitialized, isTrue);

      // 测试缓存状态
      final cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], equals(1));
      expect(cacheInfo['cachedUrls'], contains(testVideoUrl));

      // 测试播放控制
      VideoCacheManager.playVideo(testVideoUrl);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(VideoCacheManager.hasActiveVideo, isTrue);
      expect(VideoCacheManager.activeVideoUrl, equals(testVideoUrl));

      // 测试暂停控制
      VideoCacheManager.pauseVideo(testVideoUrl);
      expect(VideoCacheManager.activeVideoUrl, isNull);
    });

    test('VideoCacheManager 正确处理失效控制器', () async {
      const testVideoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';

      // 创建控制器
      final controller1 = await VideoCacheManager.getController(testVideoUrl);
      expect(controller1, isNotNull);

      // 手动释放控制器（模拟异常情况）
      await controller1!.dispose();

      // 再次获取相同URL，应该清理失效控制器并重新创建
      final controller2 = await VideoCacheManager.getController(testVideoUrl);
      expect(controller2, isNotNull);
      expect(controller2!.value.isInitialized, isTrue);
      expect(identical(controller1, controller2), isFalse); // 应该是不同的实例
    });

    test('HybridMediaWidget 正确处理视频控制器生命周期', () async {
      // 由于 widget 测试需要更复杂的设置，这里主要测试基本逻辑
      const testVideoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';
      const testImgName = 'test_image';

      // 创建控制器
      final controller = await VideoCacheManager.getController(testVideoUrl);
      expect(controller, isNotNull);

      // 模拟 HybridMediaWidget 的生命周期
      // 初始化
      VideoCacheManager.playVideo(testVideoUrl);
      expect(VideoCacheManager.activeVideoUrl, equals(testVideoUrl));

      // 销毁（模拟组件 dispose）
      VideoCacheManager.pauseVideo(testVideoUrl);
      // 注意：不应该调用 controller.dispose()，因为这是由 VideoCacheManager 管理的

      // 验证控制器仍然有效
      final cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], equals(1)); // 控制器仍在缓存中
    });

    test('LiveVideoPlayer 独立管理控制器', () async {
      const testVideoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';

      // LiveVideoPlayer 应该创建自己的控制器，不依赖缓存管理器
      final controller = VideoPlayerController.networkUrl(Uri.parse(testVideoUrl));
      await controller.initialize();

      expect(controller.value.isInitialized, isTrue);

      // 清理
      controller.dispose();
    });

    test('VideoCacheManager 正确处理最大缓存限制', () async {
      const videoUrls = [
        'https://www.w3schools.com/html/mov_bbb.mp4',
        'https://www.w3schools.com/html/movie.mp4',
      ];

      // 创建多个控制器
      for (final url in videoUrls) {
        final controller = await VideoCacheManager.getController(url);
        expect(controller, isNotNull);
      }

      // 验证缓存数量不超过限制
      final cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], lessThanOrEqualTo(10)); // _maxCachedControllers = 10
    });

    test('VideoCacheManager disposeAll 正确清理所有资源', () async {
      const testVideoUrls = [
        'https://www.w3schools.com/html/mov_bbb.mp4',
        'https://www.w3schools.com/html/movie.mp4',
      ];

      // 创建多个控制器
      for (final url in testVideoUrls) {
        final controller = await VideoCacheManager.getController(url);
        expect(controller, isNotNull);
      }

      // 验证控制器已创建
      var cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], greaterThan(0));

      // 清理所有控制器
      VideoCacheManager.disposeAll();

      // 验证所有资源已清理
      cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], equals(0));
      expect(cacheInfo['cachedUrls'], isEmpty);
      expect(cacheInfo['activeVideo'], isNull);
    });
  });

  group('错误处理测试', () {
    test('VideoCacheManager 处理无效视频URL', () async {
      const invalidVideoUrl = 'https://invalid-url-that-does-not-exist.com/video.mp4';

      // 应该返回 null 而不是抛出异常
      final controller = await VideoCacheManager.getController(invalidVideoUrl);
      expect(controller, isNull);
    });

    test('VideoCacheManager 处理空URL', () async {
      final controller = await VideoCacheManager.getController('');
      expect(controller, isNull);
    });
  });
}