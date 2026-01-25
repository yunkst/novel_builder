import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Toast提示工具类
class ToastUtils {
  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      message,
      backgroundColor: Colors.green,
    );
  }

  /// 显示错误提示
  static void showError(BuildContext context, String message) {
    _showToast(
      message,
      backgroundColor: Colors.red,
    );
  }

  /// 显示警告提示
  static void showWarning(BuildContext context, String message) {
    _showToast(
      message,
      backgroundColor: Colors.orange,
    );
  }

  /// 显示信息提示
  static void showInfo(BuildContext context, String message) {
    _showToast(
      message,
      backgroundColor: Colors.blue,
    );
  }

  /// 显示加载提示
  static void showLoading(BuildContext context, String message) {
    _showToast(
      message,
      backgroundColor: Colors.grey[700]!,
    );
  }

  /// 显示搜索状态提示
  static void showSearchStatus(BuildContext context, String message,
      {bool isError = false}) {
    if (isError) {
      showError(context, message);
    } else {
      showInfo(context, message);
    }
  }

  /// 显示网络错误提示
  static void showNetworkError(BuildContext context, {String? customMessage}) {
    showError(
      context,
      customMessage ?? '网络连接失败，请检查网络设置',
    );
  }

  /// 显示爬虫失败提示
  static void showCrawlerError(BuildContext context, String siteName,
      {String? reason}) {
    final message =
        reason != null ? '$siteName 搜索失败: $reason' : '$siteName 搜索失败，正在尝试其他站点';
    showWarning(context, message);
  }

  /// 显示搜索结果提示
  static void showSearchResult(
      BuildContext context, int totalResults, int failedSites) {
    if (totalResults == 0) {
      showWarning(context, '未找到相关小说，请尝试其他关键词');
    } else if (failedSites > 0) {
      showInfo(context, '找到 $totalResults 本小说，$failedSites 个站点搜索失败');
    } else {
      showSuccess(context, '找到 $totalResults 本小说');
    }
  }

  /// 私有方法：显示toast（使用FlutterToast插件）
  static void _showToast(
    String message, {
    required Color backgroundColor,
    Toast toastLength = Toast.LENGTH_SHORT,
  }) {
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
