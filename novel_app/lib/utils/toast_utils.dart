import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Toast提示工具类
class ToastUtils {
  /// 显示成功提示
  static void showSuccess(
    String message, {
    BuildContext? context,
    Duration? duration,
  }) {
    _showToast(
      message,
      backgroundColor: Colors.green,
      duration: duration,
    );
  }

  /// 显示错误提示
  static void showError(
    String message, {
    BuildContext? context,
    Duration? duration,
  }) {
    _showToast(
      message,
      backgroundColor: Colors.red,
      duration: duration,
    );
  }

  /// 显示警告提示
  static void showWarning(
    String message, {
    BuildContext? context,
    Duration? duration,
  }) {
    _showToast(
      message,
      backgroundColor: Colors.orange,
      duration: duration,
    );
  }

  /// 显示信息提示
  static void showInfo(
    String message, {
    BuildContext? context,
    Duration? duration,
  }) {
    _showToast(
      message,
      backgroundColor: Colors.blue,
      duration: duration,
    );
  }

  /// 显示加载提示
  static void showLoading(
    String message, {
    BuildContext? context,
    Duration? duration,
  }) {
    _showToast(
      message,
      backgroundColor: Colors.blue,
      duration: duration,
    );
  }

  /// 显示普通提示（默认灰色）
  static void show(
    String message, {
    BuildContext? context,
    Color? backgroundColor,
    Duration? duration,
  }) {
    _showToast(
      message,
      backgroundColor: backgroundColor ?? const Color(0xFF616161),
      duration: duration,
    );
  }

  /// 关闭当前显示的Toast
  static void dismiss() {
    Fluttertoast.cancel();
  }

  /// 显示带操作的提示（用于简单场景，实际操作需要自定义对话框）
  static void showErrorWithAction(
    String message,
    String actionLabel,
    VoidCallback onAction, {
    BuildContext? context,
  }) {
    // 简化实现：先显示Toast
    showError(message, context: context);
    // 注意：实际操作需要在调用方处理对话框
  }

  /// 显示带操作的警告提示（用于简单场景）
  static void showWarningWithAction(
    String message,
    String actionLabel,
    VoidCallback onAction, {
    BuildContext? context,
  }) {
    // 简化实现：先显示Toast
    showWarning(message, context: context);
    // 注意：实际操作需要在调用方处理对话框
  }

  /// 显示带操作的信息提示（用于简单场景）
  static void showInfoWithAction(
    String message,
    String actionLabel,
    VoidCallback onAction, {
    BuildContext? context,
  }) {
    // 简化实现：先显示Toast
    showInfo(message, context: context);
    // 注意：实际操作需要在调用方处理对话框
  }

  /// 私有方法：显示toast（使用FlutterToast插件）
  static void _showToast(
    String message, {
    required Color backgroundColor,
    Duration? duration,
  }) {
    final toastLength = duration != null &&
            (duration.inSeconds >= 3 || duration.inMinutes >= 1)
        ? Toast.LENGTH_LONG
        : Toast.LENGTH_SHORT;

    Fluttertoast.showToast(
      msg: message,
      toastLength: toastLength,
      gravity: ToastGravity.TOP,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
