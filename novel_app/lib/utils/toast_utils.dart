import 'package:flutter/material.dart';

/// Toast提示工具类
class ToastUtils {
  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context,
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  /// 显示错误提示
  static void showError(BuildContext context, String message) {
    _showToast(
      context,
      message,
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
  }

  /// 显示警告提示
  static void showWarning(BuildContext context, String message) {
    _showToast(
      context,
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning,
    );
  }

  /// 显示信息提示
  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message,
      backgroundColor: Colors.blue,
      icon: Icons.info,
    );
  }

  /// 显示加载提示
  static void showLoading(BuildContext context, String message) {
    _showToast(
      context,
      message,
      backgroundColor: Colors.grey[700]!,
      icon: Icons.hourglass_empty,
      duration: const Duration(seconds: 2),
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

  /// 私有方法：显示toast
  static void _showToast(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
