import 'package:flutter/material.dart';
import '../../services/auto_scroll_controller.dart';

/// 自动滚动功能 Mixin
///
/// 职责：
/// - 管理自动滚动状态（开始/暂停/停止/恢复）
/// - 处理用户手势检测（暂停/恢复自动滚动）
/// - 提供启动保护期（500ms 内忽略用户手势）
///
/// 使用方式：
/// ```dart
/// class _MyScreenState extends State<MyScreen> with AutoScrollMixin {
///   @override
///   void initState() {
///     super.initState();
///     initAutoScroll(scrollController: _scrollController);
///   }
/// }
/// ```
///
/// 需要子类提供的字段和方法：
/// - `ScrollController get scrollController` - 滚动控制器
/// - `double get scrollSpeed` - 滚动速度倍数（1.0-3.0）
/// - `void setState(VoidCallback fn)` - 状态更新方法
mixin AutoScrollMixin<T extends StatefulWidget> on State<T> {
  // ========== 字段 ==========

  late HighPerformanceAutoScrollController _autoScrollController;
  bool _isAutoScrolling = false;
  bool _shouldAutoScroll = false; // 意图标记，用于恢复判断
  bool _isUserScrolling = false; // 标记用户是否正在滚动
  DateTime? _autoScrollStartTime; // 自动滚动启动时间（用于保护期）

  // 常量配置
  static const Duration _startupProtectionDuration = Duration(milliseconds: 500); // 启动保护期：500ms
  static const double _baseScrollSpeed = 50.0; // 基础滚动速度（像素/秒）

  // ========== 抽象访问器（子类必须实现）==========

  /// 滚动控制器（子类提供）
  ScrollController get scrollController;

  /// 滚动速度倍数（子类提供，1.0为默认速度）
  double get scrollSpeed;

  // ========== 公开方法 ==========

  /// 初始化自动滚动控制器
  ///
  /// 必须在 initState 中调用
  void initAutoScroll({required ScrollController scrollController}) {
    _autoScrollController = HighPerformanceAutoScrollController(
      scrollController: scrollController,
    );
  }

  /// 开始自动滚动
  void startAutoScroll() {
    debugPrint('🚀 [AutoScrollMixin] startAutoScroll 被调用，_isAutoScrolling=$_isAutoScrolling, _shouldAutoScroll=$_shouldAutoScroll');

    if (_isAutoScrolling) {
      debugPrint('⚠️ [AutoScrollMixin] 已在滚动中，直接返回（保护逻辑触发）');
      return;
    }

    final pixelsPerSecond = _baseScrollSpeed * scrollSpeed;
    _autoScrollController.startAutoScroll(
      pixelsPerSecond,
      onScrollComplete: () {
        debugPrint('🏁 [AutoScrollMixin] 滚动到底部回调触发');
        setState(() {
          _isAutoScrolling = false;
          _shouldAutoScroll = false; // 到底部后清除意图
          _autoScrollStartTime = null; // 清除启动时间
        });
      },
    );

    setState(() {
      _isAutoScrolling = true;
      _shouldAutoScroll = true; // ← 设置意图标记
      _autoScrollStartTime = DateTime.now(); // ← 记录启动时间
    });

    debugPrint('✅ [AutoScrollMixin] 自动滚动已启动，_isAutoScrolling=true, _shouldAutoScroll=true, 保护期=${_startupProtectionDuration.inMilliseconds}ms');
  }

  /// 暂停自动滚动（临时暂停，保持意图，用于用户滑动场景）
  void pauseAutoScroll() {
    debugPrint('⏸️ [AutoScrollMixin] pauseAutoScroll 被调用，临时暂停自动滚动');
    _autoScrollController.stopAutoScroll();
    setState(() {
      _isAutoScrolling = false;
      // _shouldAutoScroll 保持 true，不清除意图！
      _autoScrollStartTime = null; // 清除启动时间
    });
    debugPrint('✅ [AutoScrollMixin] 已暂停，_isAutoScrolling=false, _shouldAutoScroll=$_shouldAutoScroll（保持不变）');
  }

  /// 停止自动滚动（完全停止，清除意图）
  void stopAutoScroll() {
    debugPrint('🛑 [AutoScrollMixin] stopAutoScroll 被调用，完全停止自动滚动');
    _autoScrollController.stopAutoScroll();
    setState(() {
      _isAutoScrolling = false;
      _shouldAutoScroll = false; // ← 清除意图标记
      _autoScrollStartTime = null; // ← 清除启动时间
    });
    debugPrint('✅ [AutoScrollMixin] 已停止，_isAutoScrolling=false, _shouldAutoScroll=false');
  }

  /// 切换自动滚动状态
  void toggleAutoScroll() {
    debugPrint('🔄 [AutoScrollMixin] toggleAutoScroll 切换自动滚动状态，当前 _isAutoScrolling=$_isAutoScrolling');

    if (_isAutoScrolling) {
      debugPrint('⬇️ [AutoScrollMixin] 停止自动滚动');
      stopAutoScroll();
    } else {
      debugPrint('⬆️ [AutoScrollMixin] 启动自动滚动');
      startAutoScroll();
    }
  }

  /// 处理滚动通知（用于 NotificationListener）
  ///
  /// 返回 false 表示不阻止通知继续传递
  bool handleScrollNotification(ScrollNotification notification) {
    // 只响应真正的用户滚动通知
    if (notification is UserScrollNotification) {
      // 用户开始主动滚动（检查 direction 是否不是 idle）
      if (notification.direction.toString() != 'ScrollDirection.idle' && !_isUserScrolling) {
        setState(() {
          _isUserScrolling = true;
        });

        if (_isAutoScrolling) {
          // 检查是否在保护期内
          if (_autoScrollStartTime != null) {
            final timeSinceStart = DateTime.now().difference(_autoScrollStartTime!);
            if (timeSinceStart < _startupProtectionDuration) {
              debugPrint('🛡️ [AutoScrollMixin] 在启动保护期内（${timeSinceStart.inMilliseconds}ms < ${_startupProtectionDuration.inMilliseconds}ms），忽略用户手势');
              return false; // 忽略这次手势
            }
          }

          pauseAutoScroll(); // ← 改为调用暂停方法，保持意图标记
          debugPrint('⏸️ [AutoScrollMixin] 检测到用户手势，暂停自动滚动');
        }
      }
    } else if (notification is ScrollEndNotification) {
      // 用户滚动结束 - 恢复自动滚动
      if (_isUserScrolling) {
        setState(() {
          _isUserScrolling = false;
        });

        // 修改：检查意图标记 _shouldAutoScroll
        if (_shouldAutoScroll) {
          debugPrint('🔄 [AutoScrollMixin] 恢复自动滚动（_shouldAutoScroll=true）');
          startAutoScroll();
        }
      }
    }

    return false; // 不阻止通知继续传递
  }

  // ========== Getter 方法 ==========

  /// 是否正在自动滚动
  bool get isAutoScrolling => _isAutoScrolling;

  /// 是否应该自动滚动（意图标记）
  bool get shouldAutoScroll => _shouldAutoScroll;

  /// 用户是否正在滚动
  bool get isUserScrolling => _isUserScrolling;

  // ========== 生命周期管理 ==========

  /// 清理资源（在子类的 dispose 中调用）
  void disposeAutoScroll() {
    debugPrint('🧹 [AutoScrollMixin] 清理自动滚动资源');
    _autoScrollController.dispose();
  }
}
