import 'package:flutter/foundation.dart';

/// 视频生成状态管理器
/// 用于全局管理图片的视频生成状态
class VideoGenerationStateManager {
  static final Set<String> _generatingImages = <String>{};
  static final List<VoidCallback> _listeners = [];

  /// 检查图片是否正在生成视频
  static bool isImageGenerating(String imageUrl) {
    return _generatingImages.contains(imageUrl);
  }

  /// 设置图片生成状态
  static void setImageGenerating(String imageUrl, bool isGenerating) {
    if (isGenerating) {
      _generatingImages.add(imageUrl);
    } else {
      _generatingImages.remove(imageUrl);
    }
    _notifyListeners();
  }

  /// 添加状态变化监听器
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// 移除状态变化监听器
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// 通知所有监听器
  static void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('视频生成状态监听器错误: $e');
      }
    }
  }

  /// 清理所有状态
  static void clearAll() {
    _generatingImages.clear();
    _notifyListeners();
  }
}