import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/novel.dart';
import '../../services/database_service.dart';
import '../../mixins/dify_streaming_mixin.dart';

/// 背景设定总结对话框
///
/// 职责：
/// - 提供背景设定AI总结功能的完整 UI
/// - 使用 DifyStreamingMixin 进行流式生成
/// - 支持重新总结和复制功能
/// - 总结完成后自动更新数据库
class BackgroundSummaryDialog extends StatefulWidget {
  final Novel novel;
  final String backgroundText;

  const BackgroundSummaryDialog({
    super.key,
    required this.novel,
    required this.backgroundText,
  });

  @override
  State<BackgroundSummaryDialog> createState() => _BackgroundSummaryDialogState();
}

class _BackgroundSummaryDialogState extends State<BackgroundSummaryDialog>
    with TickerProviderStateMixin, DifyStreamingMixin {
  final DatabaseService _databaseService = DatabaseService();

  String _summaryResult = '';
  bool _showConfirmDialog = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 自动显示确认对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSummarizeConfirmDialog();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 显示总结确认对话框
  Future<void> _showSummarizeConfirmDialog() async {
    if (!_showConfirmDialog) {
      // 如果不需要确认，直接开始生成
      _generateSummarize();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.summarize, color: Colors.orange),
            SizedBox(width: 8),
            Text('背景设定总结'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将对当前背景设定进行AI总结',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            const Text('总结后将替换原有背景设定内容'),
            const SizedBox(height: 8),
            Text(
              '是否继续?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('开始总结'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _generateSummarize();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  /// 生成总结
  Future<void> _generateSummarize() async {
    try {
      await callDifyStreaming(
        inputs: {
          'cmd': '设定总结',
          'background_setting': widget.backgroundText,
        },
        onChunk: (chunk) {
          if (mounted) {
            setState(() {
              _summaryResult += chunk;
            });
          }
        },
        onComplete: (content) async {
          // 生成完成，等待用户确认后再保存
          if (mounted) {
            setState(() {
              _summaryResult = content;
            });
          }
        },
        startMessage: '正在总结背景设定...',
        completeMessage: null, // 不显示完成提示,由保存逻辑处理
        enableDebugLog: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('总结失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 保存总结结果
  Future<void> _saveSummary(String summary) async {
    try {
      await _databaseService.updateBackgroundSetting(
        widget.novel.url,
        summary.isEmpty ? null : summary,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('背景设定已更新为总结内容'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // 延迟关闭对话框,让用户看到提示
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context, true); // 返回true表示已更新
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 重新总结
  void _regenerateSummarize() {
    setState(() {
      _summaryResult = '';
      _showConfirmDialog = false; // 不再显示确认对话框
    });
    _generateSummarize();
  }

  /// 复制结果
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _summaryResult));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 显示流式生成进度
    if (isStreaming) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.summarize, color: Colors.orange),
            SizedBox(width: 8),
            Text('正在总结...'),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('AI正在生成总结,请稍候...'),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _summaryResult,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelStreaming();
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
        ],
      );
    }

    // 显示总结结果对比界面
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.summarize, color: Colors.orange),
          const SizedBox(width: 8),
          const Text('总结完成'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: '复制总结',
          ),
        ],
      ),
      content: SizedBox(
        width: 550,
        height: 450,
        child: Column(
          children: [
            // TabBar
            TabBar(
              controller: _tabController,
              labelColor: Colors.orange,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.orange,
              tabs: const [
                Tab(text: '原文'),
                Tab(text: '总结'),
              ],
            ),
            const SizedBox(height: 8),
            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 原文内容
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.backgroundText,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                  // 总结内容
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _summaryResult,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _regenerateSummarize,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('重新生成'),
        ),
        ElevatedButton(
          onPressed: () => _saveSummary(_summaryResult),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('确认替换'),
        ),
      ],
    );
  }
}
