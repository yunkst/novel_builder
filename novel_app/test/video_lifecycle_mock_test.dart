import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/video_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoCacheManager 生命周期模拟测试', () {
    setUp(() {
      // 每个测试前清理视频缓存管理器状态
      VideoCacheManager.disposeAll();
    });

    test('初始状态检查', () {
      final cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], equals(0));
      expect(cacheInfo['cachedUrls'], isEmpty);
      expect(cacheInfo['activeVideo'], isNull);
      expect(VideoCacheManager.hasActiveVideo, isFalse);
    });

    test('缓存信息结构检查', () {
      final cacheInfo = VideoCacheManager.getCacheInfo();

      // 验证返回的数据结构包含所有必要字段
      expect(cacheInfo, isA<Map<String, dynamic>>());
      expect(cacheInfo.containsKey('cachedCount'), isTrue);
      expect(cacheInfo.containsKey('maxCacheSize'), isTrue);
      expect(cacheInfo.containsKey('activeVideo'), isTrue);
      expect(cacheInfo.containsKey('cachedUrls'), isTrue);
      expect(cacheInfo.containsKey('disposedFlags'), isTrue);

      // 验证数据类型
      expect(cacheInfo['cachedCount'], isA<int>());
      expect(cacheInfo['maxCacheSize'], isA<int>());
      expect(cacheInfo['activeVideo'], isA<String?>());
      expect(cacheInfo['cachedUrls'], isA<List>());
      expect(cacheInfo['disposedFlags'], isA<Map>());
    });

    test('playVideo 和 pauseVideo 状态管理', () {
      const testVideoUrl = 'test://video.mp4';

      // 初始状态
      expect(VideoCacheManager.hasActiveVideo, isFalse);
      expect(VideoCacheManager.activeVideoUrl, isNull);

      // 播放不存在的视频（由于没有控制器，不会设置活跃状态）
      VideoCacheManager.playVideo(testVideoUrl);
      expect(VideoCacheManager.activeVideoUrl, isNull); // 没有控制器，不会设置活跃状态

      // 暂停视频
      VideoCacheManager.pauseVideo(testVideoUrl);
      expect(VideoCacheManager.activeVideoUrl, isNull);
    });

    test('pauseAllExcept 功能', () {
      const videoUrls = [
        'test://video1.mp4',
        'test://video2.mp4',
        'test://video3.mp4',
      ];

      // 由于没有实际控制器，playVideo 不会设置活跃状态
      for (final url in videoUrls) {
        VideoCacheManager.playVideo(url);
      }
      expect(VideoCacheManager.activeVideoUrl, isNull);

      // pauseAllExcept 应该可以直接设置活跃状态
      VideoCacheManager.pauseAllExcept(videoUrls[1]);
      expect(VideoCacheManager.activeVideoUrl, equals(videoUrls[1]));

      // 暂停所有视频
      VideoCacheManager.pauseAllExcept(null);
      expect(VideoCacheManager.activeVideoUrl, isNull);
    });

    test('disposeAll 清理所有状态', () {
      const testVideoUrl = 'test://video.mp4';

      // 设置一些状态（通过 pauseAllExcept 直接设置活跃状态）
      VideoCacheManager.pauseAllExcept(testVideoUrl);
      expect(VideoCacheManager.hasActiveVideo, isTrue);

      // 清理所有资源
      VideoCacheManager.disposeAll();

      // 验证所有状态已重置
      final cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], equals(0));
      expect(cacheInfo['cachedUrls'], isEmpty);
      expect(cacheInfo['activeVideo'], isNull);
      expect(cacheInfo['disposedFlags'], isEmpty);
      expect(VideoCacheManager.hasActiveVideo, isFalse);
    });

    test('边界情况处理', () {
      // 暂停不存在的视频
      VideoCacheManager.pauseVideo('nonexistent://video.mp4');
      expect(VideoCacheManager.activeVideoUrl, isNull);

      // 播放空URL
      VideoCacheManager.playVideo('');
      expect(VideoCacheManager.activeVideoUrl, isNull);

      // 多次清理
      VideoCacheManager.disposeAll();
      VideoCacheManager.disposeAll();
      VideoCacheManager.disposeAll();

      final cacheInfo = VideoCacheManager.getCacheInfo();
      expect(cacheInfo['cachedCount'], equals(0));
    });
  });

  group('错误处理和边界测试', () {
    setUp(() {
      VideoCacheManager.disposeAll();
    });

    test('空字符串URL处理', () {
      VideoCacheManager.playVideo('');
      expect(VideoCacheManager.activeVideoUrl, isNull);

      VideoCacheManager.pauseVideo('');
      expect(VideoCacheManager.activeVideoUrl, isNull);
    });

    test('重复操作一致性', () {
      const testVideoUrl = 'test://video.mp4';

      // 重复播放相同视频（由于没有控制器，不会设置活跃状态）
      VideoCacheManager.playVideo(testVideoUrl);
      VideoCacheManager.playVideo(testVideoUrl);
      VideoCacheManager.playVideo(testVideoUrl);
      expect(VideoCacheManager.activeVideoUrl, isNull);

      // 通过 pauseAllExcept 设置活跃状态
      VideoCacheManager.pauseAllExcept(testVideoUrl);
      expect(VideoCacheManager.activeVideoUrl, equals(testVideoUrl));

      // 重复暂停相同视频
      VideoCacheManager.pauseVideo(testVideoUrl);
      VideoCacheManager.pauseVideo(testVideoUrl);
      expect(VideoCacheManager.activeVideoUrl, isNull);
    });

    test('状态一致性检查', () {
      const videoUrls = [
        'test://video1.mp4',
        'test://video2.mp4',
      ];

      // 通过 pauseAllExcept 设置活跃视频
      VideoCacheManager.pauseAllExcept(videoUrls[0]);
      expect(VideoCacheManager.hasActiveVideo, isTrue);
      expect(VideoCacheManager.activeVideoUrl, equals(videoUrls[0]));

      // 切换到第二个视频
      VideoCacheManager.pauseAllExcept(videoUrls[1]);
      expect(VideoCacheManager.hasActiveVideo, isTrue);
      expect(VideoCacheManager.activeVideoUrl, equals(videoUrls[1]));

      // 暂停当前视频
      VideoCacheManager.pauseVideo(videoUrls[1]);
      expect(VideoCacheManager.hasActiveVideo, isFalse);
      expect(VideoCacheManager.activeVideoUrl, isNull);
    });
  });
}
