import 'package:flutter/material.dart';
import '../failures/database_failure.dart';
import '../failures/network_failure.dart';
import '../failures/cache_failure.dart';
import '../errors/failure.dart';

/// 统一错误处理器
class ErrorHandler {
  /// 获取用户友好的错误消息
  static String getErrorMessage(Failure failure) {
    if (failure is DatabaseFailure) {
      return _getDatabaseErrorMessage(failure);
    } else if (failure is NetworkFailure) {
      return _getNetworkErrorMessage(failure);
    } else if (failure is CacheFailure) {
      return _getCacheErrorMessage(failure);
    } else {
      return failure.message;
    }
  }

  /// 获取数据库错误消息
  static String _getDatabaseErrorMessage(DatabaseFailure failure) {
    switch (failure.code) {
      case 'connection_failed':
        return '数据库连接失败，请重启应用';
      case 'query_failed':
        return '数据查询失败，请重试';
      case 'insert_failed':
        return '保存数据失败，请重试';
      case 'update_failed':
        return '更新数据失败，请重试';
      case 'delete_failed':
        return '删除数据失败，请重试';
      case 'migration_failed':
        return '数据库升级失败，请重装应用';
      default:
        return '数据库操作失败：${failure.message}';
    }
  }

  /// 获取网络错误消息
  static String _getNetworkErrorMessage(NetworkFailure failure) {
    switch (failure.statusCode) {
      case 400:
        return '请求参数错误，请重试';
      case 401:
        return '认证失败，请检查API配置';
      case 403:
        return '访问被拒绝，请检查权限';
      case 404:
        return '请求的资源不存在';
      case 429:
        return '请求过于频繁，请稍后重试';
      case 500:
        return '服务器内部错误，请稍后重试';
      case 502:
        return '服务器网关错误，请稍后重试';
      case 503:
        return '服务暂时不可用，请稍后重试';
      default:
        if (failure.statusCode != null && failure.statusCode! >= 500) {
          return '服务器错误 (${failure.statusCode})，请稍后重试';
        } else if (failure.statusCode != null && failure.statusCode! >= 400) {
          return '请求错误 (${failure.statusCode})，请检查输入';
        } else {
          return '网络连接失败：${failure.message}';
        }
    }
  }

  /// 获取缓存错误消息
  static String _getCacheErrorMessage(CacheFailure failure) {
    switch (failure.code) {
      case 'cache_full':
        return '缓存空间不足，请清理缓存';
      case 'cache_corrupted':
        return '缓存数据损坏，已自动清理';
      case 'cache_expired':
        return '缓存已过期';
      case 'cache_miss':
        return '缓存未找到，将重新获取';
      default:
        return '缓存操作失败：${failure.message}';
    }
  }

  /// 显示错误消息（带用户友好的消息）
  static void showError(BuildContext context, Failure failure) {
    final message = getErrorMessage(failure);
    _showErrorSnackBar(context, message);
  }

  /// 显示原始错误消息
  static void showRawError(BuildContext context, String message) {
    _showErrorSnackBar(context, message);
  }

  /// 显示成功的消息
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green);
  }

  /// 显示信息消息
  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.blue);
  }

  /// 显示警告消息
  static void showWarning(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.orange);
  }

  /// 内部方法：显示SnackBar
  static void _showSnackBar(BuildContext context, String message, Color backgroundColor) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '确定',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 内部方法：显示错误SnackBar
  static void _showErrorSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red);
  }

  /// 记录错误日志
  static void logError(Failure failure, [String? context]) {
    final contextStr = context != null ? '[$context] ' : '';
    debugPrint('${contextStr}Error: ${failure.runtimeType} - ${failure.message}');
    if (failure.code != null) {
      debugPrint('${contextStr}Error Code: ${failure.code}');
    }
  }

  /// 记录调试信息
  static void logDebug(String message, [String? context]) {
    final contextStr = context != null ? '[$context] ' : '';
    debugPrint('${contextStr}Debug: $message');
  }

  /// 记录信息
  static void logInfo(String message, [String? context]) {
    final contextStr = context != null ? '[$context] ' : '';
    debugPrint('${contextStr}Info: $message');
  }
}