/// WebView「添加小说」悬浮按钮
///
/// 右下角 FloatingActionButton，仅在当前域名存在 `chapter_list_js` 脚本时显示。
///
/// ## 交互流程
///
///   1. 点击 → 执行 `chapter_list_js` → 提取 JSON {title, chapters}
///   2. 弹出 [AddNovelPreviewSheet] 预览
///   3. 确认后：
///     - 小说不在书架 → 插入 bookshelf 表
///     - 小说已在书架 → **静默更新章节**（不额外提示）
///     - 章节写入 novel_chapters 表
///     - 跳转到 [ChapterListScreenRiverpod]
///
/// ## 复用
///
///   - JS 执行 → [WebViewJsExecutor]（校验 + IIFE 提取 + callAsyncJavaScript）
///   - 数据库 → `novelRepositoryProvider` / `chapterRepositoryProvider`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/webview_add_novel_providers.dart';
import '../core/providers/webview_providers.dart';
import '../core/providers/database_providers.dart';
import '../models/novel.dart';
import '../models/chapter.dart';
import '../services/novel_agent/scenarios/webview_js_executor.dart';
import '../screens/chapter_list_screen_riverpod.dart';
import '../utils/toast_utils.dart';
import 'add_novel_preview_sheet.dart';

class WebViewAddNovelFab extends ConsumerStatefulWidget {
  const WebViewAddNovelFab({super.key});

  @override
  ConsumerState<WebViewAddNovelFab> createState() =>
      _WebViewAddNovelFabState();
}

class _WebViewAddNovelFabState extends ConsumerState<WebViewAddNovelFab> {
  bool _isExtracting = false;

  @override
  Widget build(BuildContext context) {
    final showButton = ref.watch(webviewHasAddNovelButtonProvider);
    if (!showButton) return const SizedBox.shrink();

    return FloatingActionButton.small(
      heroTag: 'add_novel_fab',
      onPressed: _isExtracting ? null : () => _handleAddNovel(context),
      tooltip: '添加小说',
      child: _isExtracting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.library_add),
    );
  }

  // ===================================================================
  // 核心流程
  // ===================================================================

  Future<void> _handleAddNovel(BuildContext context) async {
    // 1. 获取脚本
    final script = ref.read(webviewCurrentSiteScriptProvider).valueOrNull;
    if (script == null) {
      _toast('未找到该网站的提取脚本', isError: true);
      return;
    }

    // 2. 获取 WebView 控制器
    final controller = ref.read(webviewControllerProvider);
    if (controller == null) {
      _toast('浏览器未就绪', isError: true);
      return;
    }

    // 3. 获取当前 URL
    final currentUrl = ref.read(webviewCurrentUrlProvider);
    if (currentUrl.isEmpty) {
      _toast('无法获取当前页面链接', isError: true);
      return;
    }

    // 4. 执行提取
    setState(() => _isExtracting = true);

    try {
      // 校验脚本（确保含 {{URL}} 占位符）
      final validationError =
          WebViewJsExecutor.validateScript(script.chapterListJs);
      if (validationError != null) {
        _toast('脚本校验失败：$validationError', isError: true);
        return;
      }

      // 替换 {{URL}} → 当前 URL
      final resolvedScript =
          script.chapterListJs.replaceAll('{{URL}}', currentUrl);

      // 提取 IIFE 函数体（适配 callAsyncJavaScript）
      final functionBody =
          WebViewJsExecutor.extractAsyncFunctionBody(resolvedScript);

      // 执行脚本
      final jsResult = await controller
          .callAsyncJavaScript(functionBody: functionBody)
          .timeout(const Duration(seconds: 60));

      // 解析返回值
      if (jsResult == null) {
        _toast('提取失败：脚本返回空值', isError: true);
        return;
      }
      if (jsResult.error != null) {
        _toast('提取失败：${jsResult.error}', isError: true);
        return;
      }

      final resultStr = WebViewJsExecutor.stringifyJsResult(jsResult.value);
      final data = jsonDecode(resultStr) as Map<String, dynamic>;

      final extractedTitle =
          (data['title'] as String?)?.trim() ?? '';
      final chaptersRaw = data['chapters'] as List<dynamic>?;

      if (extractedTitle.isEmpty || chaptersRaw == null || chaptersRaw.isEmpty) {
        _toast('未提取到章节，请检查是否在章节目录页', isError: true);
        return;
      }

      // 转换为类型化数据
      final chapters = <Map<String, String>>[];
      for (final c in chaptersRaw) {
        if (c is! Map) continue;
        final title = c['title']?.toString().trim();
        final url = c['url']?.toString().trim();
        if (title != null && title.isNotEmpty && url != null && url.isNotEmpty) {
          chapters.add({'title': title, 'url': url});
        }
      }

      if (chapters.isEmpty) {
        _toast('解析章节数据失败', isError: true);
        return;
      }

      // 5. 检查是否已在书架
      final novelRepo = ref.read(novelRepositoryProvider);
      final alreadyInBookshelf = await novelRepo.isInBookshelf(currentUrl);

      if (alreadyInBookshelf) {
        // 已存在：静默更新章节后直接跳转
        await _saveChapters(currentUrl, chapters);
        _markScriptUsed(script.id);
        _toast('章节已更新');
        if (mounted) {
          // ignore: use_build_context_synchronously
          _navigateToChapterList(context, Novel(
            title: extractedTitle,
            author: '',
            url: currentUrl,
          ));
        }
        return;
      }

      // 6. 显示预览弹窗
      if (!mounted) return;
      final previewResult = await showModalBottomSheet<Map<String, dynamic>>(
        // ignore: use_build_context_synchronously
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => AddNovelPreviewSheet(
          title: extractedTitle,
          chapters: chapters,
          sourceUrl: currentUrl,
        ),
      );

      if (previewResult == null || previewResult['confirmed'] != true) return;

      final finalTitle = (previewResult['title'] as String?) ?? extractedTitle;

      // 7. 写入数据库
      await novelRepo.addToBookshelf(Novel(
        title: finalTitle,
        author: '',
        url: currentUrl,
      ));
      await _saveChapters(currentUrl, chapters);
      _markScriptUsed(script.id);

      _toast('已添加到书架');

      // 8. 导航到章节列表
      if (mounted) {
        // ignore: use_build_context_synchronously
        _navigateToChapterList(context, Novel(
          title: finalTitle,
          author: '',
          url: currentUrl,
        ));
      }
    } on TimeoutException {
      _toast('提取超时，请重试', isError: true);
    } catch (e) {
      _toast('提取失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  // ===================================================================
  // 辅助方法
  // ===================================================================

  /// 将章节列表持久化到 novel_chapters 表
  Future<void> _saveChapters(
    String novelUrl,
    List<Map<String, String>> chaptersData,
  ) async {
    final chapterRepo = ref.read(chapterRepositoryProvider);
    final chapters = chaptersData.asMap().entries.map((e) {
      return Chapter(
        title: e.value['title']!,
        url: e.value['url']!,
        chapterIndex: e.key,
      );
    }).toList();
    await chapterRepo.cacheNovelChapters(novelUrl, chapters);
  }

  /// 标记脚本已使用（use_count + 1）
  void _markScriptUsed(String scriptId) {
    ref.read(siteScriptRepositoryProvider).markUsed(scriptId);
  }

  /// 导航到章节列表页
  void _navigateToChapterList(BuildContext context, Novel novel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterListScreenRiverpod(novel: novel),
      ),
    );
  }

  /// 显示 Toast 提示
  void _toast(String message, {bool isError = false}) {
    if (isError) {
      ToastUtils.showError(message);
      return;
    }
    ToastUtils.showSuccess(message);
  }
}
