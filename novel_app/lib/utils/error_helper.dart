import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import 'toast_utils.dart';

/// 错误处理辅助类
///
/// 提供统一的错误处理和日志记录接口，确保所有用户可见的错误提示都被正确记录。
class ErrorHelper {
  /// 显示错误提示并记录日志
  ///
  /// [context] - BuildContext 上下文
  /// [userMessage] - 显示给用户的错误消息
  /// [error] - 错误对象（可选）
  /// [stackTrace] - 堆栈跟踪（可选）
  /// [category] - 日志分类（默认为 general）
  /// [tags] - 日志标签（可选）
  static void showErrorWithLog(
    BuildContext context,
    String userMessage, {
    Object? error,
    StackTrace? stackTrace,
    LogCategory category = LogCategory.general,
    List<String> tags = const [],
  }) {
    // 记录错误日志
    LoggerService.instance.e(
      userMessage,
      stackTrace: stackTrace?.toString(),
      category: category,
      tags: [...tags, 'user-visible'],
    );

    // 显示用户提示
    if (context.mounted) {
      ToastUtils.showError(error != null ? '$userMessage: $error' : userMessage, context: context);
    }
  }

  /// 显示警告提示并记录日志
  ///
  /// [context] - BuildContext 上下文
  /// [userMessage] - 显示给用户的警告消息
  /// [error] - 错误对象（可选）
  /// [category] - 日志分类（默认为 general）
  /// [tags] - 日志标签（可选）
  static void showWarningWithLog(
    BuildContext context,
    String userMessage, {
    Object? error,
    LogCategory category = LogCategory.general,
    List<String> tags = const [],
  }) {
    // 记录警告日志
    LoggerService.instance.w(
      userMessage,
      category: category,
      tags: [...tags, 'user-visible'],
    );

    // 显示用户提示
    if (context.mounted) {
      ToastUtils.showWarning(error != null ? '$userMessage: $error' : userMessage, context: context);
    }
  }

  /// 显示成功提示并记录日志
  ///
  /// [context] - BuildContext 上下文
  /// [userMessage] - 显示给用户的成功消息
  /// [category] - 日志分类（默认为 general）
  /// [tags] - 日志标签（可选）
  static void showSuccessWithLog(
    BuildContext context,
    String userMessage, {
    LogCategory category = LogCategory.general,
    List<String> tags = const [],
  }) {
    // 记录信息日志
    LoggerService.instance.i(
      userMessage,
      category: category,
      tags: [...tags, 'user-visible'],
    );

    // 显示用户提示
    if (context.mounted) {
      ToastUtils.showSuccess(userMessage, context: context);
    }
  }

  /// 仅记录错误日志（不显示用户提示）
  ///
  /// [message] - 错误消息
  /// [error] - 错误对象（可选）
  /// [stackTrace] - 堆栈跟踪（可选）
  /// [category] - 日志分类（默认为 general）
  /// [tags] - 日志标签（可选）
  static void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    LogCategory category = LogCategory.general,
    List<String> tags = const [],
  }) {
    LoggerService.instance.e(
      message,
      stackTrace: stackTrace?.toString(),
      category: category,
      tags: tags,
    );
  }

  /// 仅记录警告日志（不显示用户提示）
  ///
  /// [message] - 警告消息
  /// [error] - 错误对象（可选）
  /// [category] - 日志分类（默认为 general）
  /// [tags] - 日志标签（可选）
  static void logWarning(
    String message, {
    Object? error,
    LogCategory category = LogCategory.general,
    List<String> tags = const [],
  }) {
    LoggerService.instance.w(
      message,
      category: category,
      tags: tags,
    );
  }

  /// 获取错误信息的友好提示
  ///
  /// 将异常转换为用户友好的错误消息
  ///
  /// [error] - 错误对象
  /// 返回用户友好的错误消息
  static String getErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('SocketException')) {
      return '网络连接失败，请检查网络设置';
    } else if (errorStr.contains('TimeoutException')) {
      return '请求超时，请稍后重试';
    } else if (errorStr.contains('请求过于频繁')) {
      return '请求过于频繁，请稍后再试';
    } else if (errorStr.contains('404')) {
      return '章节不存在';
    } else if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503')) {
      return '服务器暂时不可用，请稍后重试';
    } else {
      return '加载失败: $errorStr';
    }
  }
}
