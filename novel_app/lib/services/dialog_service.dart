/// DialogService - 统一对话框和Toast管理服务
///
/// 职责：
/// - 统一管理所有对话框的显示逻辑
/// - 解耦UI层和业务逻辑
/// - 提供类型安全的对话框接口
/// - 统一Toast提示管理
///
/// 设计原则：
/// - UI层只负责触发事件
/// - Service层管理对话框显示
/// - 业务逻辑与UI完全分离
///
/// 使用示例：
/// ```dart
/// class MyScreen extends ConsumerStatefulWidget {
///   late final DialogService _dialogService;
///
///   @override
///   void initState() {
///     super.initState();
///     _dialogService = DialogService(ref);
///   }
///
///   Future<void> _handleAction() async {
///     final confirmed = await _dialogService.showConfirmDialog(
///       context,
///       title: '确认操作',
///       content: '确定要执行此操作吗？',
///     );
///
///     if (confirmed == true) {
///       // 执行业务逻辑
///     }
///   }
/// }
/// ```

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_companion_response.dart';
import '../widgets/reader/ai_companion_confirm_dialog.dart';
import '../core/providers/database_providers.dart';
import '../models/novel.dart';
import '../utils/toast_utils.dart';

/// 对话框服务类
class DialogService {
  final WidgetRef ref;

  DialogService(this.ref);

  // ============ 通用对话框 ============

  /// 显示确认对话框
  ///
  /// [context] 上下文
  /// [title] 标题
  /// [content] 内容
  /// [confirmText] 确认按钮文本
  /// [cancelText] 取消按钮文本
  /// [isDanger] 是否为危险操作
  ///
  /// 返回用户是否确认
  Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDanger = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDanger
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// 显示信息对话框
  ///
  /// [context] 上下文
  /// [title] 标题
  /// [content] 内容
  /// [confirmText] 确认按钮文本
  Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确定',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ============ AI伴读对话框 ============

  /// 显示AI伴读确认对话框
  ///
  /// [context] 上下文
  /// [response] AI伴读响应数据
  ///
  /// 返回用户是否确认更新
  Future<bool> showAICompanionConfirm(
    BuildContext context, {
    required AICompanionResponse response,
  }) async {
    return await showAICompanionConfirmDialog(context, response);
  }

  /// 执行AI伴读更新
  ///
  /// [context] 上下文
  /// [response] AI伴读响应数据
  /// [novel] 小说对象
  /// [isSilent] 是否为静默模式
  Future<void> performAICompanionUpdates(
    BuildContext context, {
    required AICompanionResponse response,
    required Novel novel,
    bool isSilent = false,
  }) async {
    final databaseService = ref.read(databaseServiceProvider);

    // 仅在非静默模式下显示更新进度
    if (!isSilent) {
      ToastUtils.showInfo(
        '正在更新数据...',
        context: context,
        duration: const Duration(minutes: 5),
      );
    }

    try {
      // 1. 追加背景设定
      if (response.background.isNotEmpty) {
        await databaseService.appendBackgroundSetting(
          novel.url,
          response.background,
        );
      }

      // 2. 批量更新或插入角色
      if (response.roles.isNotEmpty) {
        await databaseService.batchUpdateOrInsertCharacters(
          novel.url,
          response.roles,
        );
      }

      // 3. 批量插入关系
      if (response.relations.isNotEmpty) {
        await databaseService.batchUpdateOrInsertRelationships(
          novel.url,
          response.relations,
        );
      }

      // 4. 完成提示
      if (!isSilent && context.mounted) {
        ToastUtils.dismiss();
        ToastUtils.showSuccess('AI伴读数据已更新', context: context);
      }
    } catch (e) {
      if (!isSilent && context.mounted) {
        ToastUtils.dismiss();
        ToastUtils.showError('更新数据失败: $e', context: context);
      }
      rethrow;
    }
  }

  // ============ Toast提示管理 ============

  /// 显示成功提示
  void showSuccess(
    String message, {
    BuildContext? context,
  }) {
    ToastUtils.showSuccess(message, context: context);
  }

  /// 显示错误提示
  void showError(
    String message, {
    BuildContext? context,
  }) {
    ToastUtils.showError(message, context: context);
  }

  /// 显示警告提示
  void showWarning(
    String message, {
    BuildContext? context,
  }) {
    ToastUtils.showWarning(message, context: context);
  }

  /// 显示信息提示
  void showInfo(
    String message, {
    BuildContext? context,
    Duration? duration,
  }) {
    ToastUtils.showInfo(
      message,
      context: context,
      duration: duration,
    );
  }

  /// 关闭当前Toast
  void dismissToast() {
    ToastUtils.dismiss();
  }

  /// 显示Loading提示
  ///
  /// [message] 提示消息
  /// [context] 上下文
  /// [duration] 持续时间（默认5分钟）
  void showLoading(
    String message, {
    BuildContext? context,
    Duration? duration,
  }) {
    ToastUtils.showInfo(
      message,
      context: context,
      duration: duration ?? const Duration(minutes: 5),
    );
  }
}
