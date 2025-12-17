import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/video_cache_manager.dart';

/// 视频控制器生命周期测试
/// 用于验证修复后的 VideoPlayerController 生命周期管理是否正常工作
class VideoLifecycleTest {
  static Future<void> testVideoCacheManager() async {
    debugPrint('=== 开始视频缓存管理器测试 ===');

    // 测试 1: 获取缓存信息
    debugPrint('测试 1: 初始缓存状态');
    final initialInfo = VideoCacheManager.getCacheInfo();
    debugPrint('初始缓存信息: $initialInfo');

    // 测试 2: 创建和缓存控制器
    debugPrint('\n测试 2: 创建控制器');
    const testVideoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';

    try {
      final controller1 = await VideoCacheManager.getController(testVideoUrl);
      debugPrint('创建控制器1结果: ${controller1 != null ? "成功" : "失败"}');

      // 再次获取相同URL的控制器，应该返回缓存的实例
      final controller2 = await VideoCacheManager.getController(testVideoUrl);
      debugPrint('获取缓存控制器结果: ${controller2 != null ? "成功" : "失败"}');
      debugPrint('控制器是否为同一实例: ${controller1 == controller2}');

      // 测试 3: 播放和暂停
      debugPrint('\n测试 3: 播放和暂停控制');
      VideoCacheManager.playVideo(testVideoUrl);
      await Future.delayed(const Duration(milliseconds: 500));

      final playInfo = VideoCacheManager.getCacheInfo();
      debugPrint('播放中缓存信息: $playInfo');

      VideoCacheManager.pauseVideo(testVideoUrl);
      await Future.delayed(const Duration(milliseconds: 500));

      // 测试 4: 资源清理
      debugPrint('\n测试 4: 资源清理');
      VideoCacheManager.disposeController(testVideoUrl);

      final cleanupInfo = VideoCacheManager.getCacheInfo();
      debugPrint('清理后缓存信息: $cleanupInfo');

      // 测试 5: 清理后重新获取（应该重新创建）
      debugPrint('\n测试 5: 清理后重新创建');
      final controller3 = await VideoCacheManager.getController(testVideoUrl);
      debugPrint('重新创建控制器结果: ${controller3 != null ? "成功" : "失败"}');

      // 最终清理
      VideoCacheManager.disposeAll();
      final finalInfo = VideoCacheManager.getCacheInfo();
      debugPrint('最终缓存信息: $finalInfo');

    } catch (e) {
      debugPrint('测试过程中出现错误: $e');
    }

    debugPrint('=== 视频缓存管理器测试完成 ===');
  }

  /// 模拟页面切换场景测试
  static Future<void> simulatePageSwitch() async {
    debugPrint('\n=== 模拟页面切换测试 ===');

    const testVideoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';

    try {
      // 模拟用户第一次进入页面
      debugPrint('模拟用户第一次进入页面');
      final controller1 = await VideoCacheManager.getController(testVideoUrl);
      VideoCacheManager.playVideo(testVideoUrl);
      await Future.delayed(const Duration(seconds: 1));

      // 模拟用户离开页面（组件销毁）
      debugPrint('模拟用户离开页面');
      VideoCacheManager.pauseVideo(testVideoUrl);

      // 模拟用户再次进入页面
      debugPrint('模拟用户再次进入页面');
      final controller2 = await VideoCacheManager.getController(testVideoUrl);
      debugPrint('再次进入页面获取控制器: ${controller2 != null ? "成功" : "失败"}');

      if (controller2 != null) {
        debugPrint('控制器已初始化: ${controller2.value.isInitialized}');
        VideoCacheManager.playVideo(testVideoUrl);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 清理
      VideoCacheManager.disposeAll();

    } catch (e) {
      debugPrint('页面切换测试失败: $e');
    }

    debugPrint('=== 模拟页面切换测试完成 ===');
  }

  /// 测试应用生命周期场景
  static void testAppLifecycle(AppLifecycleState state) {
    debugPrint('\n=== 测试应用生命周期变化 ===');
    debugPrint('生命周期状态: $state');

    switch (state) {
      case AppLifecycleState.paused:
        VideoCacheManager.pauseAllExcept(null);
        debugPrint('应用暂停 - 所有视频已暂停');
        break;
      case AppLifecycleState.resumed:
        debugPrint('应用恢复 - 可见性检测器将控制播放');
        break;
      case AppLifecycleState.detached:
        VideoCacheManager.disposeAll();
        debugPrint('应用分离 - 所有视频资源已清理');
        break;
      case AppLifecycleState.inactive:
        VideoCacheManager.pauseAllExcept(null);
        debugPrint('应用不活跃 - 所有视频已暂停');
        break;
      case AppLifecycleState.hidden:
        VideoCacheManager.pauseAllExcept(null);
        debugPrint('应用隐藏 - 所有视频已暂停');
        break;
    }

    final info = VideoCacheManager.getCacheInfo();
    debugPrint('生命周期变化后状态: $info');
    debugPrint('=== 应用生命周期测试完成 ===');
  }
}