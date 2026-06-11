/// 站点脚本管理面板
///
/// 以 BottomSheet 形式展示所有已保存的提取脚本，
/// 支持查看详情、验证和删除操作。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../core/providers/webview_providers.dart';
import '../models/site_script.dart';

/// 脚本管理面板（通过 showModalBottomSheet 弹出）
class SiteScriptPanel extends ConsumerWidget {
  const SiteScriptPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scriptsAsync = ref.watch(siteScriptListProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽把手
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.code, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '脚本管理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${scriptsAsync.valueOrNull?.length ?? 0} 个站点',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // 列表区域
          Flexible(
            child: scriptsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('加载失败: $error'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(siteScriptListProvider.notifier).refresh(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (scripts) {
                if (scripts.isEmpty) {
                  return _buildEmptyState(context);
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: scripts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _ScriptCard(script: scripts[index]);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code_off,
              size: 48,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无提取脚本',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI 生成脚本后会自动出现在这里',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个脚本卡片
class _ScriptCard extends ConsumerWidget {
  final SiteScript script;

  const _ScriptCard({required this.script});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 域名行
          Row(
            children: [
              Icon(Icons.language, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  script.domain,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (script.isVerified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '已验证',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 脚本状态标签
          Row(
            children: [
              _buildScriptChip(
                '目录脚本',
                script.hasChapterListJs,
              ),
              const SizedBox(width: 8),
              _buildScriptChip(
                '内容脚本',
                script.hasChapterContentJs,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 使用统计
          Text(
            '使用 ${script.useCount} 次 · ${_formatDate(script.createdAtDateTime)}',
            style: TextStyle(
              fontSize: 11,
              color: bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton(
                context,
                icon: Icons.visibility_outlined,
                label: '查看',
                onTap: () => _showViewDialog(context, script),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                context,
                icon: Icons.check_circle_outline,
                label: '验证',
                onTap: () => _showVerifyConfirm(context, ref, script),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                context,
                icon: Icons.delete_outline,
                label: '删除',
                color: Colors.red,
                onTap: () => _showDeleteConfirm(context, ref, script),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScriptChip(String label, bool hasScript) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: hasScript
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: hasScript
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasScript ? Icons.check : Icons.close,
            size: 12,
            color: hasScript ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: hasScript ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: effectiveColor),
            ),
          ],
        ),
      ),
    );
  }

  /// 查看脚本详情对话框
  void _showViewDialog(BuildContext context, SiteScript script) {
    showDialog(
      context: context,
      builder: (ctx) => _ScriptDetailDialog(script: script),
    );
  }

  /// 验证：弹出 URL 输入框
  void _showVerifyConfirm(
      BuildContext context, WidgetRef ref, SiteScript script) {
    final urlController = TextEditingController(text: script.sampleUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('验证脚本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '域名: ${script.domain}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text(
              '输入要验证的页面 URL（脚本中的 {{URL}} 将被替换为该 URL）:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'https://example.com/book/123',
                hintStyle: TextStyle(fontSize: 12),
              ),
              style: const TextStyle(fontSize: 13),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            const Text(
              '提示：目录脚本填章节列表页 URL；内容脚本填章节内容页 URL。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL 不能为空')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _runVerification(context, ref, script, url);
            },
            child: const Text('运行'),
          ),
        ],
      ),
    );
  }

  /// 执行验证：注入 URL → 在 WebView 中执行脚本 → 展示结果
  Future<void> _runVerification(
    BuildContext context,
    WidgetRef ref,
    SiteScript script,
    String testUrl,
  ) async {
    // 读取 WebView controller
    final controller = ref.read(webviewControllerProvider);

    // 弹出加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在执行脚本...'),
            ],
          ),
        ),
      ),
    );

    if (controller == null) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WebView 尚未初始化')),
        );
      }
      return;
    }

    // 让用户选择要验证哪种脚本
    final scriptType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择要验证的脚本'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'chapter_list_js'),
            child: const Text('目录提取脚本'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'chapter_content_js'),
            child: const Text('内容提取脚本'),
          ),
        ],
      ),
    );

    if (scriptType == null) {
      if (context.mounted) Navigator.pop(context);
      return;
    }

    final scriptCode = scriptType == 'chapter_list_js'
        ? script.chapterListJs
        : script.chapterContentJs;

    if (scriptCode.isEmpty) {
      if (context.mounted) Navigator.pop(context); // 关闭加载框
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该脚本为空')),
        );
      }
      return;
    }

    // 替换 {{URL}} 为测试 URL
    final resolvedScript = scriptCode.replaceAll('{{URL}}', testUrl);

    // 执行脚本
    String? resultStr;
    String? errorMsg;
    try {
      resultStr = await controller
          .evaluateJavascript(source: resolvedScript)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      errorMsg = '脚本执行超时（>30秒）';
    } catch (e) {
      errorMsg = e.toString();
    }

    if (context.mounted) Navigator.pop(context); // 关闭加载框

    if (!context.mounted) return;

    // 展示结果
    _showVerifyResultDialog(
      context,
      ref,
      script,
      scriptType,
      testUrl,
      resultStr,
      errorMsg,
    );
  }

  /// 展示验证结果
  void _showVerifyResultDialog(
    BuildContext context,
    WidgetRef ref,
    SiteScript script,
    String scriptType,
    String testUrl,
    String? resultStr,
    String? errorMsg,
  ) {
    final success = errorMsg == null && resultStr != null;

    if (success) {
      ref.read(siteScriptListProvider.notifier).verifyScript(script.id);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(success ? '执行成功' : '执行失败'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('脚本类型',
                  scriptType == 'chapter_list_js' ? '目录脚本' : '内容脚本'),
              _buildResultRow('测试 URL', testUrl),
              if (errorMsg != null)
                _buildResultRow('错误信息', errorMsg, color: Colors.red),
              if (resultStr != null) ...[
                const SizedBox(height: 4),
                const Text('返回结果:',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _formatResult(resultStr),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: resultStr ?? errorMsg ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制到剪贴板'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('复制结果'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 格式化结果：尝试解析为 JSON 后美化
  String _formatResult(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  /// 删除确认对话框
  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, SiteScript script) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除脚本'),
        content: Text(
          '确定要删除 ${script.domain} 的提取脚本吗？\n\n'
          '此操作不可撤销。',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(siteScriptListProvider.notifier)
                  .deleteScript(script.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 脚本详情查看对话框
class _ScriptDetailDialog extends StatefulWidget {
  final SiteScript script;

  const _ScriptDetailDialog({required this.script});

  @override
  State<_ScriptDetailDialog> createState() => _ScriptDetailDialogState();
}

class _ScriptDetailDialogState extends State<_ScriptDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final script = widget.script;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.code, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      script.domain,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Tab 切换
            TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: '目录脚本'),
                Tab(text: '内容脚本'),
              ],
            ),
            // 代码区域
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCodeView(script.chapterListJs, '目录脚本'),
                  _buildCodeView(script.chapterContentJs, '内容脚本'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeView(String code, String type) {
    if (code.isEmpty) {
      return Center(
        child: Text(
          '$type 为空',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
          ),
        ),
      );
    }
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: IconButton.filled(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制到剪贴板'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
            ),
          ),
        ),
      ],
    );
  }
}
